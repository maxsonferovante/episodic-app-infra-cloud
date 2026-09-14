variable "rule_name" {
  type = string
}

variable "schedule_expression" {
  type = string
}

variable "target_arn" {
  type = string
}

variable "target_id" {
  type = string
}

variable "lambda_function_name" {
  type = string
}

variable "tags" {
  type    = map(string)
  default = {}
}

resource "aws_cloudwatch_event_rule" "this" {
  name                = var.rule_name
  description         = "Trigger ${var.rule_name}"
  schedule_expression = var.schedule_expression
  tags                = var.tags
}

resource "aws_cloudwatch_event_target" "this" {
  rule      = aws_cloudwatch_event_rule.this.name
  target_id = var.target_id
  arn       = var.target_arn
}

resource "aws_lambda_permission" "this" {
  statement_id  = "AllowExecutionFromEventBridge"
  action        = "lambda:InvokeFunction"
  function_name = var.lambda_function_name
  principal     = "events.amazonaws.com"
  source_arn    = aws_cloudwatch_event_rule.this.arn
}

output "rule_arn" {
  value = aws_cloudwatch_event_rule.this.arn
}

output "rule_name" {
  value = aws_cloudwatch_event_rule.this.name
}
