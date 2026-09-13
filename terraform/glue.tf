locals {
  team_database_names = {
    for team in var.teams :
    team => replace(lower("${var.project_prefix}_${team}_${var.environment}"), "-", "_")
  }
}

resource "aws_glue_catalog_database" "team" {
  for_each = local.team_database_names

  name = each.value

  description = "Learning Glue database for ${each.key}"
}

resource "aws_glue_catalog_table" "customers_iceberg_tf" {
  name          = "customers_iceberg_tf"
  database_name = "iceberg_learning_db"

  open_table_format_input {
    iceberg_input {
      metadata_operation = "CREATE"
      version            = 2

      iceberg_table_input {
        location = "s3://${aws_s3_bucket.team_temp["team2"].bucket}/iceberg/customers_iceberg_tf/"

        schema {
          schema_id = 0
          type      = "struct"

          fields {
            id       = 1
            name     = "customer_id"
            required = false
            type     = "\"int\""
          }

          fields {
            id       = 2
            name     = "customer_name"
            required = false
            type     = "\"string\""
          }

          fields {
            id       = 3
            name     = "region"
            required = false
            type     = "\"string\""
          }
        }
      }
    }
  }

  depends_on = [
    aws_lakeformation_resource.team2_iceberg_location
  ]
}
