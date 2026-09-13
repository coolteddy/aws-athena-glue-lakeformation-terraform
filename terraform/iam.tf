resource "aws_iam_role" "team1_analyst" {
  name                 = "${var.project_prefix}-team1-analyst"
  max_session_duration = 3600

  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [{
      Effect = "Allow"
      Principal = {
        AWS = var.your_iam_principal_arn
      }
      Action = "sts:AssumeRole"
    }]
  })
}

resource "aws_iam_role_policy" "team1_analyst" {
  name = "${var.project_prefix}-team1-analyst-policy"
  role = aws_iam_role.team1_analyst.id

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Sid    = "UseTeam1AthenaWorkgroup"
        Effect = "Allow"
        Action = [
          "athena:StartQueryExecution",
          "athena:GetQueryExecution",
          "athena:GetQueryResults",
          "athena:StopQueryExecution",
          "athena:GetWorkGroup"
        ]
        Resource = aws_athena_workgroup.team["team1"].arn
      },
      {
        Sid    = "ReadTeam1GlueMetadata"
        Effect = "Allow"
        Action = [
          "glue:GetDatabase",
          "glue:GetTable",
          "glue:GetTables",
          "glue:GetPartition",
          "glue:GetPartitions"
        ]
        Resource = [
          "arn:aws:glue:${var.aws_region}:${data.aws_caller_identity.current.account_id}:catalog",
          aws_glue_catalog_database.team["team1"].arn,
          "arn:aws:glue:${var.aws_region}:${data.aws_caller_identity.current.account_id}:table/${aws_glue_catalog_database.team["team1"].name}/*"
        ]
      },
      {
        Sid    = "ReadTeam1Data"
        Effect = "Allow"
        Action = [
          "s3:GetObject",
          "s3:GetBucketLocation",
          "s3:ListBucket"
        ]
        Resource = [
          aws_s3_bucket.team_temp["team1"].arn,
          "${aws_s3_bucket.team_temp["team1"].arn}/*"
        ]
      },
      {
        Sid    = "WriteTeam1QueryResults"
        Effect = "Allow"
        Action = [
          "s3:GetObject",
          "s3:GetBucketLocation",
          "s3:PutObject",
          "s3:ListBucket"
        ]
        Resource = [
          aws_s3_bucket.shared["query-results"].arn,
          "${aws_s3_bucket.shared["query-results"].arn}/${aws_athena_workgroup.team["team1"].name}/*"
        ]
      },
      {
        Sid    = "UseLearningKmsKey"
        Effect = "Allow"
        Action = [
          "kms:Decrypt",
          "kms:GenerateDataKey",
          "kms:DescribeKey"
        ]
        Resource = aws_kms_key.learning.arn
      }
    ]
  })
}

resource "aws_iam_role" "reader" {
  name                 = "${var.project_prefix}-reader"
  max_session_duration = 3600

  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [{
      Effect = "Allow"
      Principal = {
        AWS = var.your_iam_principal_arn
      }
      Action = "sts:AssumeRole"
    }]
  })
}

resource "aws_iam_role_policy" "reader" {
  name = "${var.project_prefix}-reader-policy"
  role = aws_iam_role.reader.id

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Sid    = "UseTeamAthenaWorkgroups"
        Effect = "Allow"
        Action = [
          "athena:StartQueryExecution",
          "athena:GetQueryExecution",
          "athena:GetQueryResults",
          "athena:StopQueryExecution",
          "athena:GetWorkGroup"
        ]
        Resource = [
          for team, workgroup in aws_athena_workgroup.team :
          workgroup.arn
        ]
      },
      {
        Sid    = "ReadTeamGlueMetadata"
        Effect = "Allow"
        Action = [
          "glue:GetDatabase",
          "glue:GetDatabases",
          "glue:GetTable",
          "glue:GetTables",
          "glue:GetPartition",
          "glue:GetPartitions"
        ]
        Resource = concat(
          [
            "arn:aws:glue:${var.aws_region}:${data.aws_caller_identity.current.account_id}:catalog"
          ],
          [
            for team, database in aws_glue_catalog_database.team :
            database.arn
          ],
          [
            for team, database in aws_glue_catalog_database.team :
            "arn:aws:glue:${var.aws_region}:${data.aws_caller_identity.current.account_id}:table/${database.name}/*"
          ]
        )
      },
      {
        Sid    = "ReadTeamDataBuckets"
        Effect = "Allow"
        Action = [
          "s3:GetObject",
          "s3:GetBucketLocation",
          "s3:ListBucket"
        ]
        Resource = concat(
          [
            for team, bucket in aws_s3_bucket.team_temp :
            bucket.arn
          ],
          [
            for team, bucket in aws_s3_bucket.team_temp :
            "${bucket.arn}/*"
          ]
        )
      },
      {
        Sid    = "WriteQueryResults"
        Effect = "Allow"
        Action = [
          "s3:GetObject",
          "s3:GetBucketLocation",
          "s3:PutObject",
          "s3:ListBucket"
        ]
        Resource = [
          aws_s3_bucket.shared["query-results"].arn,
          "${aws_s3_bucket.shared["query-results"].arn}/*"
        ]
      },
      {
        Sid    = "UseLearningKmsKey"
        Effect = "Allow"
        Action = [
          "kms:Decrypt",
          "kms:GenerateDataKey",
          "kms:DescribeKey"
        ]
        Resource = aws_kms_key.learning.arn
      }
    ]
  })
}

resource "aws_iam_role" "lf_data_location" {
  name                 = "${var.project_prefix}-data-location"
  max_session_duration = 3600

  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [{
      Effect = "Allow"
      Principal = {
        Service = "lakeformation.amazonaws.com"
      }
      Action = "sts:AssumeRole"
    }]
  })
}

resource "aws_iam_role_policy" "lf_data_location" {
  name = "${var.project_prefix}-data-location-policy"
  role = aws_iam_role.lf_data_location.id

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Sid    = "ListTeam2TempBucket"
        Effect = "Allow"
        Action = [
          "s3:GetBucketLocation",
          "s3:ListBucket"
        ]
        Resource = aws_s3_bucket.team_temp["team2"].arn
      },
      {
        Sid    = "ReadWriteTeam2TempObjects"
        Effect = "Allow"
        Action = [
          "s3:GetObject",
          "s3:PutObject",
          "s3:DeleteObject"
        ]
        Resource = "${aws_s3_bucket.team_temp["team2"].arn}/*"
      },
      {
        Sid    = "UseLearningKmsKey"
        Effect = "Allow"
        Action = [
          "kms:Decrypt",
          "kms:GenerateDataKey",
          "kms:DescribeKey"
        ]
        Resource = aws_kms_key.learning.arn
      }
    ]
  })
}

resource "aws_iam_role" "iceberg_creator" {
  name                 = "${var.project_prefix}-iceberg-creator"
  max_session_duration = 3600

  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [{
      Effect = "Allow"
      Principal = {
        AWS = var.your_iam_principal_arn
      }
      Action = "sts:AssumeRole"
    }]
  })
}

resource "aws_iam_role_policy" "iceberg_creator" {
  name = "${var.project_prefix}-iceberg-creator-policy"
  role = aws_iam_role.iceberg_creator.id

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Sid    = "UseTeam2AthenaWorkgroup"
        Effect = "Allow"
        Action = [
          "athena:StartQueryExecution",
          "athena:GetQueryExecution",
          "athena:GetQueryResults",
          "athena:StopQueryExecution",
          "athena:GetWorkGroup"
        ]
        Resource = aws_athena_workgroup.team["team2"].arn
      },
      {
        Sid    = "ManageIcebergGlueMetadata"
        Effect = "Allow"
        Action = [
          "glue:GetDatabase",
          "glue:GetDatabases",
          "glue:CreateTable",
          "glue:GetTable",
          "glue:GetTables",
          "glue:UpdateTable",
          "glue:GetPartition",
          "glue:GetPartitions"
        ]
        Resource = [
          "arn:aws:glue:${var.aws_region}:${data.aws_caller_identity.current.account_id}:catalog",
          "arn:aws:glue:${var.aws_region}:${data.aws_caller_identity.current.account_id}:database/iceberg_learning_db",
          "arn:aws:glue:${var.aws_region}:${data.aws_caller_identity.current.account_id}:table/iceberg_learning_db/*"
        ]
      },
      {
        Sid    = "UseLakeFormationCredentials"
        Effect = "Allow"
        Action = [
          "lakeformation:GetDataAccess"
        ]
        Resource = "*"
      },
      {
        Sid    = "WriteQueryResults"
        Effect = "Allow"
        Action = [
          "s3:GetObject",
          "s3:GetBucketLocation",
          "s3:PutObject",
          "s3:ListBucket"
        ]
        Resource = [
          aws_s3_bucket.shared["query-results"].arn,
          "${aws_s3_bucket.shared["query-results"].arn}/*"
        ]
      },
      {
        Sid    = "UseLearningKmsKey"
        Effect = "Allow"
        Action = [
          "kms:Decrypt",
          "kms:GenerateDataKey",
          "kms:DescribeKey"
        ]
        Resource = aws_kms_key.learning.arn
      }
    ]
  })
}
