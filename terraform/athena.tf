locals {
  team_workgroups = {
    for team in var.teams :
    team => lower("${var.environment}-${var.project_prefix}-${team}-workgroup")
  }
}

resource "aws_athena_workgroup" "team" {
  for_each = local.team_workgroups

  name  = each.value
  state = "ENABLED"

  configuration {
    enforce_workgroup_configuration    = true
    publish_cloudwatch_metrics_enabled = true
    bytes_scanned_cutoff_per_query     = var.athena_query_scan_cutoff_bytes

    engine_version {
      selected_engine_version = "Athena engine version 3"
    }

    result_configuration {
      output_location = "s3://${aws_s3_bucket.shared["query-results"].bucket}/${each.value}/"

      encryption_configuration {
        encryption_option = "SSE_KMS"
        kms_key_arn       = aws_kms_key.learning.arn
      }
    }
  }

  tags = {
    Team        = each.key
    Environment = var.environment
    Owner       = var.owner_tag
  }
}
