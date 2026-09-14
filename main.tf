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
      memory_size = 256
      timeout     = 10
      env = {
        JWT_SECRET      = var.jwt_secret
        GOOGLE_CLIENT_ID = var.google_client_id
        DYNAMODB_TABLE_NAME = module.dynamodb.table_name
        AWS_REGION         = var.aws_region
      }
    }
    catalog = {
      binary      = "crates/catalog-lambda"
      memory_size = 256
      timeout     = 15
      env = {
        TMDB_API_KEY      = var.tmdb_api_key
        DYNAMODB_TABLE_NAME = module.dynamodb.table_name
        AWS_REGION         = var.aws_region
      }
    }
    library = {
      binary      = "crates/library-lambda"
      memory_size = 256
      timeout     = 10
      env = {
        DYNAMODB_TABLE_NAME = module.dynamodb.table_name
        JWT_SECRET          = var.jwt_secret
        AWS_REGION          = var.aws_region
      }
    }
    progress = {
      binary      = "crates/progress-lambda"
      memory_size = 256
      timeout     = 10
      env = {
        DYNAMODB_TABLE_NAME = module.dynamodb.table_name
        JWT_SECRET          = var.jwt_secret
        AWS_REGION          = var.aws_region
      }
    }
    dashboard = {
      binary      = "crates/dashboard-lambda"
      memory_size = 512
      timeout     = 15
      env = {
        DYNAMODB_TABLE_NAME = module.dynamodb.table_name
        JWT_SECRET          = var.jwt_secret
        AWS_REGION          = var.aws_region
      }
    }
    sync-job = {
      binary      = "crates/sync-job"
      memory_size = 512
      timeout     = 300
      env = {
        TMDB_API_KEY      = var.tmdb_api_key
        DYNAMODB_TABLE_NAME = module.dynamodb.table_name
        AWS_REGION         = var.aws_region
      }
    }
  }
}

module "lambda" {
  for_each = local.lambdas
  source   = "./modules/lambda"

  function_name = "episodic-${each.key}"
  binary_path   = "${path.module}/../episodic-app-backend/target/lambda/${each.key}.zip"
  memory_size   = each.value.memory_size
  timeout       = each.value.timeout
  env           = each.value.env
  tags          = var.tags
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
