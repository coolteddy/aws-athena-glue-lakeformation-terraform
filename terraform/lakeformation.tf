resource "aws_lakeformation_data_lake_settings" "this" {
  admins = [var.your_iam_principal_arn]
}

resource "aws_lakeformation_lf_tag" "classification" {
  key    = "Classification"
  values = ["Shared"]
}

resource "aws_lakeformation_resource_lf_tags" "team2_database_classification" {
  database {
    name = aws_glue_catalog_database.team["team2"].name
  }

  lf_tag {
    key   = aws_lakeformation_lf_tag.classification.key
    value = "Shared"
  }
}

resource "aws_lakeformation_permissions" "reader_classification_database" {
  principal   = aws_iam_role.reader.arn
  permissions = ["DESCRIBE"]

  lf_tag_policy {
    resource_type = "DATABASE"

    expression {
      key    = aws_lakeformation_lf_tag.classification.key
      values = ["Shared"]
    }
  }
}

resource "aws_lakeformation_permissions" "reader_classification_tables" {
  principal   = aws_iam_role.reader.arn
  permissions = ["DESCRIBE", "SELECT"]

  lf_tag_policy {
    resource_type = "TABLE"

    expression {
      key    = aws_lakeformation_lf_tag.classification.key
      values = ["Shared"]
    }
  }
}
