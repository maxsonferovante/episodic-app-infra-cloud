variable "queue_name" {
  type = string
}

variable "visibility_timeout_seconds" {
  type    = number
  default = 360
}

variable "max_receive_count" {
  type    = number
  default = 3
}

variable "tags" {
  type    = map(string)
  default = {}
}

resource "aws_sqs_queue" "dlq" {
  name                      = "${var.queue_name}-dlq"
  message_retention_seconds = 1209600
  sqs_managed_sse_enabled   = true
  tags                      = var.tags
}

resource "aws_sqs_queue" "this" {
  name                       = var.queue_name
  visibility_timeout_seconds = var.visibility_timeout_seconds
  # Long polling reduces empty responses and request cost (SQS best practice).
  receive_wait_time_seconds = 20
  sqs_managed_sse_enabled   = true
  redrive_policy = jsonencode({
    deadLetterTargetArn = aws_sqs_queue.dlq.arn
    maxReceiveCount     = var.max_receive_count
  })
  tags = var.tags
}

output "queue_arn" {
  value = aws_sqs_queue.this.arn
}

output "queue_url" {
  value = aws_sqs_queue.this.url
}

output "dlq_arn" {
  value = aws_sqs_queue.dlq.arn
}
