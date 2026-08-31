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

