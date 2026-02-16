resource "aws_dynamodb_table" "urls" {
  name           = var.table_name
  billing_mode   = "PAY_PER_REQUEST"
  hash_key       = "shortCode"

  attribute {
    name = "shortCode"
    type = "S"
  }

  stream_enabled   = var.enable_streams
  stream_view_type = var.enable_streams ? "NEW_AND_OLD_IMAGES" : null

  point_in_time_recovery {
    enabled = true
  }

  server_side_encryption {
    enabled = true
  }

  ttl {
    enabled        = false
    attribute_name = ""
  }

  tags = merge(
    var.tags,
    {
      Name        = var.table_name
      Environment = var.environment
    }
  )
}