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
