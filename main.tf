terraform {
  required_version = ">= 1.5"

  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = "~> 5.0"
    }
    random = {
      source  = "hashicorp/random"
      version = "~> 3.0"
    }
  }
}

provider "aws" {
  region = var.aws_region
}

# ---------- DynamoDB ----------

module "dynamodb" {
  source = "./modules/dynamodb"

  table_name = "EpisodicEpisodes"
  tags       = var.tags
}

# ---------- SQS (hydrate queue) ----------

module "sqs" {
  source = "./modules/sqs"

  queue_name                 = "episodic-hydrate"
  visibility_timeout_seconds = 360
  max_receive_count          = 3
  tags                       = var.tags
}

# ---------- Pagination cursor key ----------
# 32 random bytes (base64url, no padding) sealing history page tokens via
# Fernet-compatible crypto. Born at first apply; a taint/recreate rotates
# it — in-flight cursors then fail closed and clients restart from page 1.
# NOTE: random_id is not marked sensitive, so the key is readable in the
# (local, gitignored) tfstate, like the other secrets.
resource "random_id" "cursor_fernet_key" {
  byte_length = 32
}

# ---------- Lambda Functions ----------

locals {
  lambdas = {
    google-auth = {
      binary      = "crates/google-auth-lambda"
      zip_name    = "google-auth-lambda"
      memory_size = 256
      timeout     = 10
      env = {
        JWT_SECRET                           = var.jwt_secret
        GOOGLE_CLIENT_ID                     = var.google_client_id
        DYNAMODB_TABLE_NAME                  = module.dynamodb.table_name
        AWS_LAMBDA_HTTP_IGNORE_STAGE_IN_PATH = "1"
      }
    }
    authorizer = {
      binary      = "crates/authorizer-lambda"
      zip_name    = "authorizer-lambda"
      memory_size = 128
      timeout     = 5
      env = {
        JWT_SECRET = var.jwt_secret
      }
    }
    catalog = {
      binary      = "crates/catalog-lambda"
      zip_name    = "catalog-lambda"
      memory_size = 256
      timeout     = 15
      env = {
        TMDB_API_KEY                         = var.tmdb_api_key
        DYNAMODB_TABLE_NAME                  = module.dynamodb.table_name
        JWT_SECRET                           = var.jwt_secret
        AWS_LAMBDA_HTTP_IGNORE_STAGE_IN_PATH = "1"
      }
    }
    library = {
      binary              = "crates/library-lambda"
      zip_name            = "library-lambda"
      memory_size         = 256
      timeout             = 10
      sqs_send            = true
      sqs_send_queue_arns = [module.sqs.queue_arn]
      env = {
        DYNAMODB_TABLE_NAME                  = module.dynamodb.table_name
        JWT_SECRET                           = var.jwt_secret
        HYDRATE_QUEUE_URL                    = module.sqs.queue_url
        AWS_LAMBDA_HTTP_IGNORE_STAGE_IN_PATH = "1"
      }
    }
    progress = {
      binary      = "crates/progress-lambda"
      zip_name    = "progress-lambda"
      memory_size = 256
      timeout     = 10
      env = {
        DYNAMODB_TABLE_NAME                  = module.dynamodb.table_name
        JWT_SECRET                           = var.jwt_secret
        AWS_LAMBDA_HTTP_IGNORE_STAGE_IN_PATH = "1"
      }
    }
    dashboard = {
      binary      = "crates/dashboard-lambda"
      zip_name    = "dashboard-lambda"
      memory_size = 512
      timeout     = 15
      env = {
        DYNAMODB_TABLE_NAME                  = module.dynamodb.table_name
        JWT_SECRET                           = var.jwt_secret
        CURSOR_FERNET_KEY                    = random_id.cursor_fernet_key.b64_url
        AWS_LAMBDA_HTTP_IGNORE_STAGE_IN_PATH = "1"
      }
    }
    sync-job = {
      binary      = "crates/sync-job"
      zip_name    = "sync-job"
      memory_size = 512
      timeout     = 300
      env = {
        TMDB_API_KEY        = var.tmdb_api_key
        DYNAMODB_TABLE_NAME = module.dynamodb.table_name
      }
    }
    hydrate-worker = {
      binary      = "crates/hydrate-worker"
      zip_name    = "hydrate-worker"
      memory_size = 512
      timeout     = 300
      sqs_consume = true
      env = {
        TMDB_API_KEY        = var.tmdb_api_key
        TMDB_COUNTRY        = "US"
        DYNAMODB_TABLE_NAME = module.dynamodb.table_name
      }
    }
  }
}

module "lambda" {
  for_each = local.lambdas
  source   = "./modules/lambda"

  function_name       = "episodic-${each.key}"
  binary_path         = "${path.module}/../episodic-app-backend/target/lambda/${each.value.zip_name}.zip"
  memory_size         = each.value.memory_size
  timeout             = each.value.timeout
  env                 = each.value.env
  dynamodb_table_arn  = module.dynamodb.table_arn
  sqs_send            = try(each.value.sqs_send, false)
  sqs_send_queue_arns = try(each.value.sqs_send_queue_arns, [])
  sqs_consume         = try(each.value.sqs_consume, false)
  tags                = var.tags
}

resource "aws_lambda_event_source_mapping" "hydrate_worker" {
  event_source_arn        = module.sqs.queue_arn
  function_name           = module.lambda["hydrate-worker"].function_name
  batch_size              = 1
  function_response_types = ["ReportBatchItemFailures"]

  scaling_config {
    maximum_concurrency = 5
  }
}

# ---------- API Gateway ----------

module "api_gateway" {
  source = "./modules/api-gateway"

  api_name = "episodic-api"

  google_auth_lambda_invoke_arn = module.lambda["google-auth"].invoke_arn
  authorizer_lambda_invoke_arn  = module.lambda["authorizer"].invoke_arn
  catalog_lambda_invoke_arn     = module.lambda["catalog"].invoke_arn
  library_lambda_invoke_arn     = module.lambda["library"].invoke_arn
  progress_lambda_invoke_arn    = module.lambda["progress"].invoke_arn
  dashboard_lambda_invoke_arn   = module.lambda["dashboard"].invoke_arn

  google_auth_lambda_function_name = module.lambda["google-auth"].function_name
  authorizer_lambda_function_name  = module.lambda["authorizer"].function_name
  catalog_lambda_function_name     = module.lambda["catalog"].function_name
  library_lambda_function_name     = module.lambda["library"].function_name
  progress_lambda_function_name    = module.lambda["progress"].function_name
  dashboard_lambda_function_name   = module.lambda["dashboard"].function_name

  # Rate limit the whole API at 300 requests/minute (5 req/s) with a burst
  # for the app's parallel season/episode fetches and token renewals.
  throttle_rate_limit  = 5
  throttle_burst_limit = 50

  tags = var.tags
}

# ---------- EventBridge (daily sync) ----------

module "eventbridge" {
  source = "./modules/eventbridge"

  rule_name            = "episodic-sync-daily"
  schedule_expression  = "cron(0 3 * * ? *)"
  target_arn           = module.lambda["sync-job"].function_arn
  target_id            = "EpisodicSyncJob"
  lambda_function_name = module.lambda["sync-job"].function_name
  tags                 = var.tags
}
