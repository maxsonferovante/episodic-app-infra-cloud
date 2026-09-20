variable "table_name" {
  type = string
}

variable "tags" {
  type    = map(string)
  default = {}
}

resource "aws_dynamodb_table" "this" {
  name         = var.table_name
  billing_mode = "PAY_PER_REQUEST"
  hash_key     = "PK"
  range_key    = "SK"

  attribute {
    name = "PK"
    type = "S"
  }

  attribute {
    name = "SK"
    type = "S"
  }

  attribute {
    name = "GSI1PK"
    type = "S"
  }

  attribute {
    name = "GSI1SK"
    type = "S"
  }

  global_secondary_index {
    name            = "GSI1"
    hash_key        = "GSI1PK"
    range_key       = "GSI1SK"
    projection_type = "ALL"
  }

  attribute {
    name = "GSI2PK"
    type = "S"
  }

  attribute {
    name = "GSI2SK"
    type = "S"
  }

  # Air-date index for release windows: GSI2PK = "AIR#<YYYY-MM>",
  # GSI2SK = "<YYYY-MM-DD>#<series>#S<ss>#E<ee>". Month buckets keep writes
  # spread across partitions while a window query stays a bounded range read.
  global_secondary_index {
    name            = "GSI2"
    hash_key        = "GSI2PK"
    range_key       = "GSI2SK"
    projection_type = "ALL"
  }

  attribute {
    name = "GSI3PK"
    type = "S"
  }

  attribute {
    name = "GSI3SK"
    type = "S"
  }

  # Library-by-added-date index: GSI3PK = "USR#<uid>",
  # GSI3SK = "<addedAt>#<seriesId>". Lets `/library` page newest-first with a
  # keyset cursor instead of scanning the whole user partition.
  global_secondary_index {
    name            = "GSI3"
    hash_key        = "GSI3PK"
    range_key       = "GSI3SK"
    projection_type = "ALL"
  }

  # PITR desligado deliberadamente (custo de backup contínuo): sem
  # `point_in_time_recovery` gerenciado, use backups on-demand manuais.
  point_in_time_recovery {
    enabled = false
  }

  tags = var.tags
}

output "table_name" {
  value = aws_dynamodb_table.this.name
}

output "table_arn" {
  value = aws_dynamodb_table.this.arn
}
