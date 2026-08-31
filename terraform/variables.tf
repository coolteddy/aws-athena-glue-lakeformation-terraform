variable "aws_region" {
  description = "AWS region for the sandbox. eu-west-2 is the default, but any region works for learning."
  type        = string
  default     = "eu-west-2"
}

variable "environment" {
  description = "Environment tag value. Kept separate from Terraform workspace on purpose — mirrors the real repo's var.environment pattern."
  type        = string
  default     = "sandbox"
}

variable "owner_tag" {
  description = "Your name/handle, purely for the Owner tag so you can find your own resources in a shared sandbox account."
  type        = string
}

variable "project_prefix" {
  description = "Short prefix used for learning resource names."
  type        = string
  default     = "lakehouse-lf-tbac"
}

variable "teams" {
  description = "Synthetic team names for per-team temp buckets."
  type        = list(string)
  default     = ["team1", "team2"]
}

variable "athena_query_scan_cutoff_bytes" {
  description = "Per-query bytes-scanned cutoff for each Athena workgroup. 1 GiB is a sandbox cost guardrail."
  type        = number
  default     = 1073741824
}

variable "your_iam_principal_arn" {
  description = "IAM role ARN allowed to assume the learning test role. Set only in local terraform.tfvars."
  type        = string
}
