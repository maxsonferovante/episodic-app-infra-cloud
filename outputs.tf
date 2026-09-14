output "api_endpoint" {
  value = module.api_gateway.invoke_url
}

output "dynamodb_table_name" {
  value = module.dynamodb.table_name
}

output "lambda_functions" {
  value = { for k, v in module.lambda : k => v.function_name }
}
