# Terraform Learning: S3, Athena, Glue, and Lake Formation

Personal AWS sandbox notes and Terraform for learning how S3, Athena, Glue,
IAM, and Lake Formation fit together.

This is intentionally small and step-by-step. The main working directory is:

```text
terraform/
```

## What This Builds

- One shared KMS key.
- Per-team S3 temp buckets.
- Shared S3 buckets for published data and Athena query results.
- Per-team Athena workgroups.
- Per-team Glue databases.
- Simple IAM roles for access testing.
- A small Lake Formation LF-Tag based access-control example.

## What This Is For

The purpose is learning, not production. The repo is designed around this
workflow:

1. Create or inspect the AWS resource in the console.
2. Understand what the resource does.
3. Rebuild the same idea in Terraform.
4. Run `terraform plan`.
5. Apply only after checking the plan.
6. Test with the AWS CLI.

## Files

```text
terraform/                                  # Terraform used for the hands-on sandbox
docs/LEARNING_PLAN.md                       # current learning checkpoint and next steps
docs/TERRAFORM_NOTES.md                     # Terraform syntax notes
docs/ATHENA_IAM_CLI_TESTING_NOTES.md        # Athena/IAM/Lake Formation test notes
```

## Safety

Do not commit local Terraform state or local variable files.

The `.gitignore` excludes:

```text
*.tfstate
*.tfstate.*
*.tfvars
*.tfvars.json
.terraform/
```

Use `terraform.tfvars.example` as the public template and keep real account
values only in your local ignored `terraform.tfvars`.

## Basic Commands

```bash
cd terraform
terraform init
terraform fmt
terraform validate
AWS_PROFILE=<your-profile> terraform plan
AWS_PROFILE=<your-profile> terraform apply
```

Run AWS CLI tests from the same region as the Terraform provider.
