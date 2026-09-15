variable "api_name" {
  type = string
}

variable "tags" {
  type    = map(string)
  default = {}
}

variable "throttle_rate_limit" {
  description = "Steady-state request rate for the whole API, in requests per second (60/min = 1)."
  type        = number
  default     = 1
}

variable "throttle_burst_limit" {
  description = "Maximum burst of requests allowed above the steady-state rate."
  type        = number
  default     = 20
}

variable "auth_lambda_invoke_arn" {
  type = string
}

variable "catalog_lambda_invoke_arn" {
  type = string
}

variable "library_lambda_invoke_arn" {
  type = string
}

variable "progress_lambda_invoke_arn" {
  type = string
}

variable "dashboard_lambda_invoke_arn" {
  type = string
}

variable "auth_lambda_function_name" {
  type = string
}

variable "catalog_lambda_function_name" {
  type = string
}

variable "library_lambda_function_name" {
  type = string
}

variable "progress_lambda_function_name" {
  type = string
}

variable "dashboard_lambda_function_name" {
  type = string
}

resource "aws_api_gateway_rest_api" "this" {
  name        = var.api_name
  description = "Episodic App REST API"

  endpoint_configuration {
    types = ["REGIONAL"]
  }

  tags = var.tags
}

resource "aws_api_gateway_resource" "api" {
  rest_api_id = aws_api_gateway_rest_api.this.id
  parent_id   = aws_api_gateway_rest_api.this.root_resource_id
  path_part   = "api"
}

resource "aws_api_gateway_resource" "v1" {
  rest_api_id = aws_api_gateway_rest_api.this.id
  parent_id   = aws_api_gateway_resource.api.id
  path_part   = "v1"
}

# Lambda invoke permissions for API Gateway
resource "aws_lambda_permission" "auth" {
  action        = "lambda:InvokeFunction"
  function_name = var.auth_lambda_function_name
  principal     = "apigateway.amazonaws.com"
  source_arn    = "${aws_api_gateway_rest_api.this.execution_arn}/*/*"
}

resource "aws_lambda_permission" "catalog" {
  action        = "lambda:InvokeFunction"
  function_name = var.catalog_lambda_function_name
  principal     = "apigateway.amazonaws.com"
  source_arn    = "${aws_api_gateway_rest_api.this.execution_arn}/*/*"
}

resource "aws_lambda_permission" "library" {
  action        = "lambda:InvokeFunction"
  function_name = var.library_lambda_function_name
  principal     = "apigateway.amazonaws.com"
  source_arn    = "${aws_api_gateway_rest_api.this.execution_arn}/*/*"
}

resource "aws_lambda_permission" "progress" {
  action        = "lambda:InvokeFunction"
  function_name = var.progress_lambda_function_name
  principal     = "apigateway.amazonaws.com"
  source_arn    = "${aws_api_gateway_rest_api.this.execution_arn}/*/*"
}

resource "aws_lambda_permission" "dashboard" {
  action        = "lambda:InvokeFunction"
  function_name = var.dashboard_lambda_function_name
  principal     = "apigateway.amazonaws.com"
  source_arn    = "${aws_api_gateway_rest_api.this.execution_arn}/*/*"
}

resource "aws_api_gateway_resource" "auth" {
  rest_api_id = aws_api_gateway_rest_api.this.id
  parent_id   = aws_api_gateway_resource.v1.id
  path_part   = "auth"
}

resource "aws_api_gateway_resource" "auth_proxy" {
  rest_api_id = aws_api_gateway_rest_api.this.id
  parent_id   = aws_api_gateway_resource.auth.id
  path_part   = "{proxy+}"
}

resource "aws_api_gateway_method" "auth_proxy_get" {
  rest_api_id   = aws_api_gateway_rest_api.this.id
  resource_id   = aws_api_gateway_resource.auth_proxy.id
  http_method   = "GET"
  authorization = "NONE"
}

resource "aws_api_gateway_method" "auth_proxy_post" {
  rest_api_id   = aws_api_gateway_rest_api.this.id
  resource_id   = aws_api_gateway_resource.auth_proxy.id
  http_method   = "POST"
  authorization = "NONE"
}

resource "aws_api_gateway_integration" "auth_lambda_get" {
  rest_api_id             = aws_api_gateway_rest_api.this.id
  resource_id             = aws_api_gateway_resource.auth_proxy.id
  http_method             = aws_api_gateway_method.auth_proxy_get.http_method
  integration_http_method = "POST"
  type                    = "AWS_PROXY"
  uri                     = var.auth_lambda_invoke_arn
}

resource "aws_api_gateway_integration" "auth_lambda_post" {
  rest_api_id             = aws_api_gateway_rest_api.this.id
  resource_id             = aws_api_gateway_resource.auth_proxy.id
  http_method             = aws_api_gateway_method.auth_proxy_post.http_method
  integration_http_method = "POST"
  type                    = "AWS_PROXY"
  uri                     = var.auth_lambda_invoke_arn
}

# OPTIONS for auth/{proxy+}
resource "aws_api_gateway_method" "auth_proxy_options" {
  rest_api_id   = aws_api_gateway_rest_api.this.id
  resource_id   = aws_api_gateway_resource.auth_proxy.id
  http_method   = "OPTIONS"
  authorization = "NONE"
}

resource "aws_api_gateway_integration" "auth_proxy_options" {
  rest_api_id = aws_api_gateway_rest_api.this.id
  resource_id = aws_api_gateway_resource.auth_proxy.id
  http_method = aws_api_gateway_method.auth_proxy_options.http_method
  type        = "MOCK"
  request_templates = { "application/json" = "{\"statusCode\": 200}" }
}

resource "aws_api_gateway_method_response" "auth_proxy_options_200" {
  rest_api_id = aws_api_gateway_rest_api.this.id
  resource_id = aws_api_gateway_resource.auth_proxy.id
  http_method = aws_api_gateway_method.auth_proxy_options.http_method
  status_code = "200"
  response_parameters = {
    "method.response.header.Access-Control-Allow-Headers" = true
    "method.response.header.Access-Control-Allow-Methods" = true
    "method.response.header.Access-Control-Allow-Origin"  = true
  }
  response_models = { "application/json" = "Empty" }
}

resource "aws_api_gateway_integration_response" "auth_proxy_options" {
  rest_api_id = aws_api_gateway_rest_api.this.id
  resource_id = aws_api_gateway_resource.auth_proxy.id
  http_method = aws_api_gateway_method.auth_proxy_options.http_method
  status_code = aws_api_gateway_method_response.auth_proxy_options_200.status_code
  response_parameters = local.cors_headers
}

resource "aws_api_gateway_resource" "series" {
  rest_api_id = aws_api_gateway_rest_api.this.id
  parent_id   = aws_api_gateway_resource.v1.id
  path_part   = "series"
}

resource "aws_api_gateway_resource" "series_proxy" {
  rest_api_id = aws_api_gateway_rest_api.this.id
  parent_id   = aws_api_gateway_resource.series.id
  path_part   = "{proxy+}"
}

resource "aws_api_gateway_method" "series_proxy_get" {
  rest_api_id   = aws_api_gateway_rest_api.this.id
  resource_id   = aws_api_gateway_resource.series_proxy.id
  http_method   = "GET"
  authorization = "NONE"
}

resource "aws_api_gateway_integration" "catalog_lambda_get" {
  rest_api_id             = aws_api_gateway_rest_api.this.id
  resource_id             = aws_api_gateway_resource.series_proxy.id
  http_method             = aws_api_gateway_method.series_proxy_get.http_method
  integration_http_method = "POST"
  type                    = "AWS_PROXY"
  uri                     = var.catalog_lambda_invoke_arn
}

# OPTIONS for series/{proxy+}
resource "aws_api_gateway_method" "series_proxy_options" {
  rest_api_id   = aws_api_gateway_rest_api.this.id
  resource_id   = aws_api_gateway_resource.series_proxy.id
  http_method   = "OPTIONS"
  authorization = "NONE"
}

resource "aws_api_gateway_integration" "series_proxy_options" {
  rest_api_id = aws_api_gateway_rest_api.this.id
  resource_id = aws_api_gateway_resource.series_proxy.id
  http_method = aws_api_gateway_method.series_proxy_options.http_method
  type        = "MOCK"
  request_templates = { "application/json" = "{\"statusCode\": 200}" }
}

resource "aws_api_gateway_method_response" "series_proxy_options_200" {
  rest_api_id = aws_api_gateway_rest_api.this.id
  resource_id = aws_api_gateway_resource.series_proxy.id
  http_method = aws_api_gateway_method.series_proxy_options.http_method
  status_code = "200"
  response_parameters = {
    "method.response.header.Access-Control-Allow-Headers" = true
    "method.response.header.Access-Control-Allow-Methods" = true
    "method.response.header.Access-Control-Allow-Origin"  = true
  }
  response_models = { "application/json" = "Empty" }
}

resource "aws_api_gateway_integration_response" "series_proxy_options" {
  rest_api_id = aws_api_gateway_rest_api.this.id
  resource_id = aws_api_gateway_resource.series_proxy.id
  http_method = aws_api_gateway_method.series_proxy_options.http_method
  status_code = aws_api_gateway_method_response.series_proxy_options_200.status_code
  response_parameters = local.cors_headers
}

resource "aws_api_gateway_resource" "library" {
  rest_api_id = aws_api_gateway_rest_api.this.id
  parent_id   = aws_api_gateway_resource.v1.id
  path_part   = "library"
}

resource "aws_api_gateway_resource" "library_proxy" {
  rest_api_id = aws_api_gateway_rest_api.this.id
  parent_id   = aws_api_gateway_resource.library.id
  path_part   = "{proxy+}"
}

resource "aws_api_gateway_method" "library_root_get" {
  rest_api_id   = aws_api_gateway_rest_api.this.id
  resource_id   = aws_api_gateway_resource.library.id
  http_method   = "GET"
  authorization = "NONE"
}

resource "aws_api_gateway_integration" "library_root_lambda" {
  rest_api_id             = aws_api_gateway_rest_api.this.id
  resource_id             = aws_api_gateway_resource.library.id
  http_method             = aws_api_gateway_method.library_root_get.http_method
  integration_http_method = "POST"
  type                    = "AWS_PROXY"
  uri                     = var.library_lambda_invoke_arn
}

resource "aws_api_gateway_method" "library_proxy_get" {
  rest_api_id   = aws_api_gateway_rest_api.this.id
  resource_id   = aws_api_gateway_resource.library_proxy.id
  http_method   = "GET"
  authorization = "NONE"
}

resource "aws_api_gateway_method" "library_proxy_put" {
  rest_api_id   = aws_api_gateway_rest_api.this.id
  resource_id   = aws_api_gateway_resource.library_proxy.id
  http_method   = "PUT"
  authorization = "NONE"
}

resource "aws_api_gateway_method" "library_proxy_delete" {
  rest_api_id   = aws_api_gateway_rest_api.this.id
  resource_id   = aws_api_gateway_resource.library_proxy.id
  http_method   = "DELETE"
  authorization = "NONE"
}

resource "aws_api_gateway_integration" "library_lambda_get" {
  rest_api_id             = aws_api_gateway_rest_api.this.id
  resource_id             = aws_api_gateway_resource.library_proxy.id
  http_method             = aws_api_gateway_method.library_proxy_get.http_method
  integration_http_method = "POST"
  type                    = "AWS_PROXY"
  uri                     = var.library_lambda_invoke_arn
}

resource "aws_api_gateway_integration" "library_lambda_put" {
  rest_api_id             = aws_api_gateway_rest_api.this.id
  resource_id             = aws_api_gateway_resource.library_proxy.id
  http_method             = aws_api_gateway_method.library_proxy_put.http_method
  integration_http_method = "POST"
  type                    = "AWS_PROXY"
  uri                     = var.library_lambda_invoke_arn
}

resource "aws_api_gateway_integration" "library_lambda_delete" {
  rest_api_id             = aws_api_gateway_rest_api.this.id
  resource_id             = aws_api_gateway_resource.library_proxy.id
  http_method             = aws_api_gateway_method.library_proxy_delete.http_method
  integration_http_method = "POST"
  type                    = "AWS_PROXY"
  uri                     = var.library_lambda_invoke_arn
}

# OPTIONS for library/{proxy+}
resource "aws_api_gateway_method" "library_proxy_options" {
  rest_api_id   = aws_api_gateway_rest_api.this.id
  resource_id   = aws_api_gateway_resource.library_proxy.id
  http_method   = "OPTIONS"
  authorization = "NONE"
}

resource "aws_api_gateway_integration" "library_proxy_options" {
  rest_api_id = aws_api_gateway_rest_api.this.id
  resource_id = aws_api_gateway_resource.library_proxy.id
  http_method = aws_api_gateway_method.library_proxy_options.http_method
  type        = "MOCK"
  request_templates = { "application/json" = "{\"statusCode\": 200}" }
}

resource "aws_api_gateway_method_response" "library_proxy_options_200" {
  rest_api_id = aws_api_gateway_rest_api.this.id
  resource_id = aws_api_gateway_resource.library_proxy.id
  http_method = aws_api_gateway_method.library_proxy_options.http_method
  status_code = "200"
  response_parameters = {
    "method.response.header.Access-Control-Allow-Headers" = true
    "method.response.header.Access-Control-Allow-Methods" = true
    "method.response.header.Access-Control-Allow-Origin"  = true
  }
  response_models = { "application/json" = "Empty" }
}

resource "aws_api_gateway_integration_response" "library_proxy_options" {
  rest_api_id = aws_api_gateway_rest_api.this.id
  resource_id = aws_api_gateway_resource.library_proxy.id
  http_method = aws_api_gateway_method.library_proxy_options.http_method
  status_code = aws_api_gateway_method_response.library_proxy_options_200.status_code
  response_parameters = local.cors_headers
}

resource "aws_api_gateway_resource" "episodes" {
  rest_api_id = aws_api_gateway_rest_api.this.id
  parent_id   = aws_api_gateway_resource.v1.id
  path_part   = "episodes"
}

resource "aws_api_gateway_resource" "episodes_proxy" {
  rest_api_id = aws_api_gateway_rest_api.this.id
  parent_id   = aws_api_gateway_resource.episodes.id
  path_part   = "{proxy+}"
}

resource "aws_api_gateway_method" "episodes_proxy_get" {
  rest_api_id   = aws_api_gateway_rest_api.this.id
  resource_id   = aws_api_gateway_resource.episodes_proxy.id
  http_method   = "GET"
  authorization = "NONE"
}

resource "aws_api_gateway_method" "episodes_proxy_put" {
  rest_api_id   = aws_api_gateway_rest_api.this.id
  resource_id   = aws_api_gateway_resource.episodes_proxy.id
  http_method   = "PUT"
  authorization = "NONE"
}

resource "aws_api_gateway_integration" "progress_lambda_get" {
  rest_api_id             = aws_api_gateway_rest_api.this.id
  resource_id             = aws_api_gateway_resource.episodes_proxy.id
  http_method             = aws_api_gateway_method.episodes_proxy_get.http_method
  integration_http_method = "POST"
  type                    = "AWS_PROXY"
  uri                     = var.progress_lambda_invoke_arn
}

resource "aws_api_gateway_integration" "progress_lambda_put" {
  rest_api_id             = aws_api_gateway_rest_api.this.id
  resource_id             = aws_api_gateway_resource.episodes_proxy.id
  http_method             = aws_api_gateway_method.episodes_proxy_put.http_method
  integration_http_method = "POST"
  type                    = "AWS_PROXY"
  uri                     = var.progress_lambda_invoke_arn
}

# OPTIONS for episodes/{proxy+}
resource "aws_api_gateway_method" "episodes_proxy_options" {
  rest_api_id   = aws_api_gateway_rest_api.this.id
  resource_id   = aws_api_gateway_resource.episodes_proxy.id
  http_method   = "OPTIONS"
  authorization = "NONE"
}

resource "aws_api_gateway_integration" "episodes_proxy_options" {
  rest_api_id = aws_api_gateway_rest_api.this.id
  resource_id = aws_api_gateway_resource.episodes_proxy.id
  http_method = aws_api_gateway_method.episodes_proxy_options.http_method
  type        = "MOCK"
  request_templates = { "application/json" = "{\"statusCode\": 200}" }
}

resource "aws_api_gateway_method_response" "episodes_proxy_options_200" {
  rest_api_id = aws_api_gateway_rest_api.this.id
  resource_id = aws_api_gateway_resource.episodes_proxy.id
  http_method = aws_api_gateway_method.episodes_proxy_options.http_method
  status_code = "200"
  response_parameters = {
    "method.response.header.Access-Control-Allow-Headers" = true
    "method.response.header.Access-Control-Allow-Methods" = true
    "method.response.header.Access-Control-Allow-Origin"  = true
  }
  response_models = { "application/json" = "Empty" }
}

resource "aws_api_gateway_integration_response" "episodes_proxy_options" {
  rest_api_id = aws_api_gateway_rest_api.this.id
  resource_id = aws_api_gateway_resource.episodes_proxy.id
  http_method = aws_api_gateway_method.episodes_proxy_options.http_method
  status_code = aws_api_gateway_method_response.episodes_proxy_options_200.status_code
  response_parameters = local.cors_headers
}

resource "aws_api_gateway_resource" "dashboard" {
  rest_api_id = aws_api_gateway_rest_api.this.id
  parent_id   = aws_api_gateway_resource.v1.id
  path_part   = "dashboard"
}

resource "aws_api_gateway_method" "dashboard_get" {
  rest_api_id   = aws_api_gateway_rest_api.this.id
  resource_id   = aws_api_gateway_resource.dashboard.id
  http_method   = "GET"
  authorization = "NONE"
}

resource "aws_api_gateway_integration" "dashboard_lambda" {
  rest_api_id             = aws_api_gateway_rest_api.this.id
  resource_id             = aws_api_gateway_resource.dashboard.id
  http_method             = aws_api_gateway_method.dashboard_get.http_method
  integration_http_method = "POST"
  type                    = "AWS_PROXY"
  uri                     = var.dashboard_lambda_invoke_arn
}

resource "aws_api_gateway_resource" "history" {
  rest_api_id = aws_api_gateway_rest_api.this.id
  parent_id   = aws_api_gateway_resource.v1.id
  path_part   = "history"
}

resource "aws_api_gateway_method" "history_get" {
  rest_api_id   = aws_api_gateway_rest_api.this.id
  resource_id   = aws_api_gateway_resource.history.id
  http_method   = "GET"
  authorization = "NONE"
}

resource "aws_api_gateway_integration" "history_lambda" {
  rest_api_id             = aws_api_gateway_rest_api.this.id
  resource_id             = aws_api_gateway_resource.history.id
  http_method             = aws_api_gateway_method.history_get.http_method
  integration_http_method = "POST"
  type                    = "AWS_PROXY"
  uri                     = var.dashboard_lambda_invoke_arn
}

resource "aws_api_gateway_resource" "calendar" {
  rest_api_id = aws_api_gateway_rest_api.this.id
  parent_id   = aws_api_gateway_resource.v1.id
  path_part   = "calendar"
}

resource "aws_api_gateway_method" "calendar_get" {
  rest_api_id   = aws_api_gateway_rest_api.this.id
  resource_id   = aws_api_gateway_resource.calendar.id
  http_method   = "GET"
  authorization = "NONE"
}

resource "aws_api_gateway_integration" "calendar_lambda" {
  rest_api_id             = aws_api_gateway_rest_api.this.id
  resource_id             = aws_api_gateway_resource.calendar.id
  http_method             = aws_api_gateway_method.calendar_get.http_method
  integration_http_method = "POST"
  type                    = "AWS_PROXY"
  uri                     = var.dashboard_lambda_invoke_arn
}

# CORS - OPTIONS mock integrations
locals {
  cors_headers = {
    "method.response.header.Access-Control-Allow-Headers" = "'Content-Type,Authorization'"
    "method.response.header.Access-Control-Allow-Methods" = "'GET,POST,PUT,DELETE,OPTIONS'"
    "method.response.header.Access-Control-Allow-Origin"  = "'*'"
  }
}

# Auth OPTIONS
resource "aws_api_gateway_method" "auth_options" {
  rest_api_id   = aws_api_gateway_rest_api.this.id
  resource_id   = aws_api_gateway_resource.auth.id
  http_method   = "OPTIONS"
  authorization = "NONE"
}

resource "aws_api_gateway_integration" "auth_options" {
  rest_api_id = aws_api_gateway_rest_api.this.id
  resource_id = aws_api_gateway_resource.auth.id
  http_method = aws_api_gateway_method.auth_options.http_method
  type        = "MOCK"

  request_templates = {
    "application/json" = "{\"statusCode\": 200}"
  }
}

resource "aws_api_gateway_method_response" "auth_options_200" {
  rest_api_id = aws_api_gateway_rest_api.this.id
  resource_id = aws_api_gateway_resource.auth.id
  http_method = aws_api_gateway_method.auth_options.http_method
  status_code = "200"

  response_parameters = {
    "method.response.header.Access-Control-Allow-Headers" = true
    "method.response.header.Access-Control-Allow-Methods" = true
    "method.response.header.Access-Control-Allow-Origin"  = true
  }

  response_models = {
    "application/json" = "Empty"
  }
}

resource "aws_api_gateway_integration_response" "auth_options" {
  rest_api_id = aws_api_gateway_rest_api.this.id
  resource_id = aws_api_gateway_resource.auth.id
  http_method = aws_api_gateway_method.auth_options.http_method
  status_code = aws_api_gateway_method_response.auth_options_200.status_code

  response_parameters = local.cors_headers
}

# Catalog OPTIONS
resource "aws_api_gateway_method" "catalog_options" {
  rest_api_id   = aws_api_gateway_rest_api.this.id
  resource_id   = aws_api_gateway_resource.series.id
  http_method   = "OPTIONS"
  authorization = "NONE"
}

resource "aws_api_gateway_integration" "catalog_options" {
  rest_api_id = aws_api_gateway_rest_api.this.id
  resource_id = aws_api_gateway_resource.series.id
  http_method = aws_api_gateway_method.catalog_options.http_method
  type        = "MOCK"

  request_templates = {
    "application/json" = "{\"statusCode\": 200}"
  }
}

resource "aws_api_gateway_method_response" "catalog_options_200" {
  rest_api_id = aws_api_gateway_rest_api.this.id
  resource_id = aws_api_gateway_resource.series.id
  http_method = aws_api_gateway_method.catalog_options.http_method
  status_code = "200"

  response_parameters = {
    "method.response.header.Access-Control-Allow-Headers" = true
    "method.response.header.Access-Control-Allow-Methods" = true
    "method.response.header.Access-Control-Allow-Origin"  = true
  }

  response_models = {
    "application/json" = "Empty"
  }
}

resource "aws_api_gateway_integration_response" "catalog_options" {
  rest_api_id = aws_api_gateway_rest_api.this.id
  resource_id = aws_api_gateway_resource.series.id
  http_method = aws_api_gateway_method.catalog_options.http_method
  status_code = aws_api_gateway_method_response.catalog_options_200.status_code

  response_parameters = local.cors_headers
}

# Library OPTIONS
resource "aws_api_gateway_method" "library_options" {
  rest_api_id   = aws_api_gateway_rest_api.this.id
  resource_id   = aws_api_gateway_resource.library.id
  http_method   = "OPTIONS"
  authorization = "NONE"
}

resource "aws_api_gateway_integration" "library_options" {
  rest_api_id = aws_api_gateway_rest_api.this.id
  resource_id = aws_api_gateway_resource.library.id
  http_method = aws_api_gateway_method.library_options.http_method
  type        = "MOCK"

  request_templates = {
    "application/json" = "{\"statusCode\": 200}"
  }
}

resource "aws_api_gateway_method_response" "library_options_200" {
  rest_api_id = aws_api_gateway_rest_api.this.id
  resource_id = aws_api_gateway_resource.library.id
  http_method = aws_api_gateway_method.library_options.http_method
  status_code = "200"

  response_parameters = {
    "method.response.header.Access-Control-Allow-Headers" = true
    "method.response.header.Access-Control-Allow-Methods" = true
    "method.response.header.Access-Control-Allow-Origin"  = true
  }

  response_models = {
    "application/json" = "Empty"
  }
}

resource "aws_api_gateway_integration_response" "library_options" {
  rest_api_id = aws_api_gateway_rest_api.this.id
  resource_id = aws_api_gateway_resource.library.id
  http_method = aws_api_gateway_method.library_options.http_method
  status_code = aws_api_gateway_method_response.library_options_200.status_code

  response_parameters = local.cors_headers
}

# Episodes OPTIONS
resource "aws_api_gateway_method" "episodes_options" {
  rest_api_id   = aws_api_gateway_rest_api.this.id
  resource_id   = aws_api_gateway_resource.episodes.id
  http_method   = "OPTIONS"
  authorization = "NONE"
}

resource "aws_api_gateway_integration" "episodes_options" {
  rest_api_id = aws_api_gateway_rest_api.this.id
  resource_id = aws_api_gateway_resource.episodes.id
  http_method = aws_api_gateway_method.episodes_options.http_method
  type        = "MOCK"

  request_templates = {
    "application/json" = "{\"statusCode\": 200}"
  }
}

resource "aws_api_gateway_method_response" "episodes_options_200" {
  rest_api_id = aws_api_gateway_rest_api.this.id
  resource_id = aws_api_gateway_resource.episodes.id
  http_method = aws_api_gateway_method.episodes_options.http_method
  status_code = "200"

  response_parameters = {
    "method.response.header.Access-Control-Allow-Headers" = true
    "method.response.header.Access-Control-Allow-Methods" = true
    "method.response.header.Access-Control-Allow-Origin"  = true
  }

  response_models = {
    "application/json" = "Empty"
  }
}

resource "aws_api_gateway_integration_response" "episodes_options" {
  rest_api_id = aws_api_gateway_rest_api.this.id
  resource_id = aws_api_gateway_resource.episodes.id
  http_method = aws_api_gateway_method.episodes_options.http_method
  status_code = aws_api_gateway_method_response.episodes_options_200.status_code

  response_parameters = local.cors_headers
}

# Dashboard OPTIONS
resource "aws_api_gateway_method" "dashboard_options" {
  rest_api_id   = aws_api_gateway_rest_api.this.id
  resource_id   = aws_api_gateway_resource.dashboard.id
  http_method   = "OPTIONS"
  authorization = "NONE"
}

resource "aws_api_gateway_integration" "dashboard_options" {
  rest_api_id = aws_api_gateway_rest_api.this.id
  resource_id = aws_api_gateway_resource.dashboard.id
  http_method = aws_api_gateway_method.dashboard_options.http_method
  type        = "MOCK"

  request_templates = {
    "application/json" = "{\"statusCode\": 200}"
  }
}

resource "aws_api_gateway_method_response" "dashboard_options_200" {
  rest_api_id = aws_api_gateway_rest_api.this.id
  resource_id = aws_api_gateway_resource.dashboard.id
  http_method = aws_api_gateway_method.dashboard_options.http_method
  status_code = "200"

  response_parameters = {
    "method.response.header.Access-Control-Allow-Headers" = true
    "method.response.header.Access-Control-Allow-Methods" = true
    "method.response.header.Access-Control-Allow-Origin"  = true
  }

  response_models = {
    "application/json" = "Empty"
  }
}

resource "aws_api_gateway_integration_response" "dashboard_options" {
  rest_api_id = aws_api_gateway_rest_api.this.id
  resource_id = aws_api_gateway_resource.dashboard.id
  http_method = aws_api_gateway_method.dashboard_options.http_method
  status_code = aws_api_gateway_method_response.dashboard_options_200.status_code

  response_parameters = local.cors_headers
}

# History OPTIONS
resource "aws_api_gateway_method" "history_options" {
  rest_api_id   = aws_api_gateway_rest_api.this.id
  resource_id   = aws_api_gateway_resource.history.id
  http_method   = "OPTIONS"
  authorization = "NONE"
}

resource "aws_api_gateway_integration" "history_options" {
  rest_api_id = aws_api_gateway_rest_api.this.id
  resource_id = aws_api_gateway_resource.history.id
  http_method = aws_api_gateway_method.history_options.http_method
  type        = "MOCK"

  request_templates = {
    "application/json" = "{\"statusCode\": 200}"
  }
}

resource "aws_api_gateway_method_response" "history_options_200" {
  rest_api_id = aws_api_gateway_rest_api.this.id
  resource_id = aws_api_gateway_resource.history.id
  http_method = aws_api_gateway_method.history_options.http_method
  status_code = "200"

  response_parameters = {
    "method.response.header.Access-Control-Allow-Headers" = true
    "method.response.header.Access-Control-Allow-Methods" = true
    "method.response.header.Access-Control-Allow-Origin"  = true
  }

  response_models = {
    "application/json" = "Empty"
  }
}

resource "aws_api_gateway_integration_response" "history_options" {
  rest_api_id = aws_api_gateway_rest_api.this.id
  resource_id = aws_api_gateway_resource.history.id
  http_method = aws_api_gateway_method.history_options.http_method
  status_code = aws_api_gateway_method_response.history_options_200.status_code

  response_parameters = local.cors_headers
}

# Calendar OPTIONS
resource "aws_api_gateway_method" "calendar_options" {
  rest_api_id   = aws_api_gateway_rest_api.this.id
  resource_id   = aws_api_gateway_resource.calendar.id
  http_method   = "OPTIONS"
  authorization = "NONE"
}

resource "aws_api_gateway_integration" "calendar_options" {
  rest_api_id = aws_api_gateway_rest_api.this.id
  resource_id = aws_api_gateway_resource.calendar.id
  http_method = aws_api_gateway_method.calendar_options.http_method
  type        = "MOCK"

  request_templates = {
    "application/json" = "{\"statusCode\": 200}"
  }
}

resource "aws_api_gateway_method_response" "calendar_options_200" {
  rest_api_id = aws_api_gateway_rest_api.this.id
  resource_id = aws_api_gateway_resource.calendar.id
  http_method = aws_api_gateway_method.calendar_options.http_method
  status_code = "200"

  response_parameters = {
    "method.response.header.Access-Control-Allow-Headers" = true
    "method.response.header.Access-Control-Allow-Methods" = true
    "method.response.header.Access-Control-Allow-Origin"  = true
  }

  response_models = {
    "application/json" = "Empty"
  }
}

resource "aws_api_gateway_integration_response" "calendar_options" {
  rest_api_id = aws_api_gateway_rest_api.this.id
  resource_id = aws_api_gateway_resource.calendar.id
  http_method = aws_api_gateway_method.calendar_options.http_method
  status_code = aws_api_gateway_method_response.calendar_options_200.status_code

  response_parameters = local.cors_headers
}

resource "aws_api_gateway_deployment" "this" {
  rest_api_id = aws_api_gateway_rest_api.this.id

  depends_on = [
    aws_api_gateway_integration.auth_lambda_get,
    aws_api_gateway_integration.auth_lambda_post,
    aws_api_gateway_integration.catalog_lambda_get,
    aws_api_gateway_integration.library_root_lambda,
    aws_api_gateway_integration.library_lambda_get,
    aws_api_gateway_integration.library_lambda_put,
    aws_api_gateway_integration.library_lambda_delete,
    aws_api_gateway_integration.progress_lambda_get,
    aws_api_gateway_integration.progress_lambda_put,
    aws_api_gateway_integration.dashboard_lambda,
    aws_api_gateway_integration.history_lambda,
    aws_api_gateway_integration.calendar_lambda,
    aws_api_gateway_integration.auth_options,
    aws_api_gateway_integration.catalog_options,
    aws_api_gateway_integration.library_options,
    aws_api_gateway_integration.episodes_options,
    aws_api_gateway_integration.dashboard_options,
    aws_api_gateway_integration.history_options,
    aws_api_gateway_integration.calendar_options,
    aws_api_gateway_integration.auth_proxy_options,
    aws_api_gateway_integration.series_proxy_options,
    aws_api_gateway_integration.library_proxy_options,
    aws_api_gateway_integration.episodes_proxy_options,
  ]

  triggers = {
    redeployment = timestamp()
  }

  lifecycle {
    create_before_destroy = true
  }
}

resource "aws_api_gateway_stage" "this" {
  deployment_id = aws_api_gateway_deployment.this.id
  rest_api_id   = aws_api_gateway_rest_api.this.id
  stage_name    = "prod"
  tags          = var.tags
}

# Stage-wide rate limit applied to every method (the request asked for 60
# requests per minute = 1 req/s, with a burst allowance for the app's parallel
# season/episode fetches). Requests over the limit get 429 Too Many Requests.
resource "aws_api_gateway_method_settings" "throttle" {
  rest_api_id = aws_api_gateway_rest_api.this.id
  stage_name  = aws_api_gateway_stage.this.stage_name
  method_path = "*/*"

  settings {
    throttling_rate_limit  = var.throttle_rate_limit
    throttling_burst_limit = var.throttle_burst_limit
  }
}

output "api_id" {
  value = aws_api_gateway_rest_api.this.id
}

output "invoke_url" {
  value = aws_api_gateway_stage.this.invoke_url
}

output "execution_arn" {
  value = aws_api_gateway_rest_api.this.execution_arn
}
