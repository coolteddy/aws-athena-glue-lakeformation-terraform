output "team_temp_buckets" {
  value = { for team, bucket in aws_s3_bucket.team_temp : team => bucket.bucket }
}

output "shared_buckets" {
  value = { for name, bucket in aws_s3_bucket.shared : name => bucket.bucket }
}

output "kms_key_alias" {
  value = aws_kms_alias.learning.name
}

output "kms_key_arn" {
  value = aws_kms_key.learning.arn
}

output "team_workgroups" {
  value = { for team, workgroup in aws_athena_workgroup.team : team => workgroup.name }
}

output "team_databases" {
  value = { for team, database in aws_glue_catalog_database.team : team => database.name }
}

output "team1_analyst_role_arn" {
  value = aws_iam_role.team1_analyst.arn
}

output "team1_analyst_assume_role_command" {
  value = "aws sts assume-role --role-arn ${aws_iam_role.team1_analyst.arn} --role-session-name team1-analyst-test"
}

output "reader_role_arn" {
  value = aws_iam_role.reader.arn
}

output "reader_assume_role_command" {
  value = "aws sts assume-role --role-arn ${aws_iam_role.reader.arn} --role-session-name reader-test"
}

output "lf_data_location_role_arn" {
  value = aws_iam_role.lf_data_location.arn
}

output "registered_iceberg_location" {
  value = "s3://${aws_s3_bucket.team_temp["team2"].bucket}/iceberg/"
}

output "iceberg_creator_role_arn" {
  value = aws_iam_role.iceberg_creator.arn
}

output "iceberg_creator_assume_role_command" {
  value = "aws sts assume-role --role-arn ${aws_iam_role.iceberg_creator.arn} --role-session-name iceberg-creator-test"
}

output "abac_test_role_arns" {
  value = { for name, role in aws_iam_role.abac_test : name => role.arn }
}

output "abac_test_assume_role_commands" {
  value = {
    for name, role in aws_iam_role.abac_test :
    name => "aws sts assume-role --role-arn ${role.arn} --role-session-name abac-${name}-test"
  }
}

output "abac_permanent_analytics_role_arn" {
  value = aws_iam_role.abac_permanent_analytics.arn
}

output "abac_permanent_analytics_assume_role_command" {
  value = "aws sts assume-role --role-arn ${aws_iam_role.abac_permanent_analytics.arn} --role-session-name abac-permanent-analytics-test"
}
