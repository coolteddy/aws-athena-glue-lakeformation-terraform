resource "aws_s3_bucket" "team_temp" {
  for_each = toset(var.teams)

  bucket = lower("${var.environment}-${var.project_prefix}-${each.value}-temp")

  tags = {
    Name        = lower("${var.environment}-${var.project_prefix}-${each.value}-temp")
    Team        = each.value
    Environment = var.environment
    Owner       = var.owner_tag
  }
}

resource "aws_s3_bucket_ownership_controls" "team_temp" {
  for_each = aws_s3_bucket.team_temp

  bucket = each.value.id

  rule {
    object_ownership = "BucketOwnerEnforced"
  }
}

resource "aws_s3_bucket_public_access_block" "team_temp" {
  for_each = aws_s3_bucket.team_temp

  bucket                  = each.value.id
  block_public_acls       = true
  block_public_policy     = true
  ignore_public_acls      = true
  restrict_public_buckets = true
}

resource "aws_s3_bucket_server_side_encryption_configuration" "team_temp" {
  for_each = aws_s3_bucket.team_temp

  bucket = each.value.id

  rule {
    apply_server_side_encryption_by_default {
      sse_algorithm     = "aws:kms"
      kms_master_key_id = aws_kms_key.learning.arn
    }

    bucket_key_enabled = true
  }
}

resource "aws_s3_bucket" "shared" {
  for_each = toset(["published", "query-results"])

  bucket = lower("${var.environment}-${var.project_prefix}-${each.value}")

  tags = {
    Name        = lower("${var.environment}-${var.project_prefix}-${each.value}")
    Zone        = each.value
    Environment = var.environment
    Owner       = var.owner_tag
  }
}

resource "aws_s3_bucket_ownership_controls" "shared" {
  for_each = aws_s3_bucket.shared

  bucket = each.value.id

  rule {
    object_ownership = "BucketOwnerEnforced"
  }
}

resource "aws_s3_bucket_public_access_block" "shared" {
  for_each = aws_s3_bucket.shared

  bucket                  = each.value.id
  block_public_acls       = true
  block_public_policy     = true
  ignore_public_acls      = true
  restrict_public_buckets = true
}

resource "aws_s3_bucket_server_side_encryption_configuration" "shared" {
  for_each = aws_s3_bucket.shared

  bucket = each.value.id

  rule {
    apply_server_side_encryption_by_default {
      sse_algorithm     = "aws:kms"
      kms_master_key_id = aws_kms_key.learning.arn
    }

    bucket_key_enabled = true
  }
}
