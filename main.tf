terraform {
  required_version = ">= 1.5"

  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = "~> 5.0"
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

# ---------- Lambda Functions ----------

locals {
  lambdas = {
    auth = {
      binary      = "crates/auth-lambda"
      zip_name    = "auth-lambda"
      memory_size = 256
      timeout     = 10
      env = {
        JWT_SECRET      = var.jwt_secret
        GOOGLE_CLIENT_ID = var.google_client_id
        DYNAMODB_TABLE_NAME = module.dynamodb.table_name
        AWS_LAMBDA_HTTP_IGNORE_STAGE_IN_PATH = "1"
      }
    }
    catalog = {
      binary      = "crates/catalog-lambda"
      zip_name    = "catalog-lambda"
      memory_size = 256
      timeout     = 15
      env = {
        TMDB_API_KEY      = var.tmdb_api_key
        DYNAMODB_TABLE_NAME = module.dynamodb.table_name
        JWT_SECRET          = var.jwt_secret
        AWS_LAMBDA_HTTP_IGNORE_STAGE_IN_PATH = "1"
      }
    }
    library = {
      binary      = "crates/library-lambda"
      zip_name    = "library-lambda"
      memory_size = 256
      timeout     = 10
      env = {
        DYNAMODB_TABLE_NAME = module.dynamodb.table_name
        JWT_SECRET          = var.jwt_secret
        AWS_LAMBDA_HTTP_IGNORE_STAGE_IN_PATH = "1"
      }
    }
    progress = {
      binary      = "crates/progress-lambda"
      zip_name    = "progress-lambda"
      memory_size = 256
      timeout     = 10
      env = {
        DYNAMODB_TABLE_NAME = module.dynamodb.table_name
        JWT_SECRET          = var.jwt_secret
        AWS_LAMBDA_HTTP_IGNORE_STAGE_IN_PATH = "1"
      }
    }
    dashboard = {
      binary      = "crates/dashboard-lambda"
      zip_name    = "dashboard-lambda"
      memory_size = 512
      timeout     = 15
      env = {
        DYNAMODB_TABLE_NAME = module.dynamodb.table_name
        JWT_SECRET          = var.jwt_secret
        AWS_LAMBDA_HTTP_IGNORE_STAGE_IN_PATH = "1"
      }
    }
    sync-job = {
      binary      = "crates/sync-job"
      zip_name    = "sync-job"
      memory_size = 512
      timeout     = 300
      env = {
        TMDB_API_KEY      = var.tmdb_api_key
        DYNAMODB_TABLE_NAME = module.dynamodb.table_name
      }
    }
  }
}

module "lambda" {
  for_each = local.lambdas
  source   = "./modules/lambda"

  function_name     = "episodic-${each.key}"
  binary_path       = "${path.module}/../episodic-app-backend/target/lambda/${each.value.zip_name}.zip"
  memory_size       = each.value.memory_size
  timeout           = each.value.timeout
  env               = each.value.env
  dynamodb_table_arn = module.dynamodb.table_arn
  tags              = var.tags
}

# ---------- API Gateway ----------

module "api_gateway" {
  source = "./modules/api-gateway"

  api_name = "episodic-api"

  auth_lambda_invoke_arn      = module.lambda["auth"].invoke_arn
  catalog_lambda_invoke_arn   = module.lambda["catalog"].invoke_arn
  library_lambda_invoke_arn   = module.lambda["library"].invoke_arn
  progress_lambda_invoke_arn  = module.lambda["progress"].invoke_arn
  dashboard_lambda_invoke_arn = module.lambda["dashboard"].invoke_arn

  auth_lambda_function_name      = module.lambda["auth"].function_name
  catalog_lambda_function_name   = module.lambda["catalog"].function_name
  library_lambda_function_name   = module.lambda["library"].function_name
  progress_lambda_function_name  = module.lambda["progress"].function_name
  dashboard_lambda_function_name = module.lambda["dashboard"].function_name

  # Rate limit the whole API at 60 requests/minute (1 req/s) with a burst.
  throttle_rate_limit  = 1
  throttle_burst_limit = 20

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
