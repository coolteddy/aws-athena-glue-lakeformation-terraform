# Terraform `for_each`, Instance Addresses, and Interpolation Notes

These notes capture the Terraform concepts used in the `terraform/`
Athena workgroup step.

## Lake Formation Data Lake Settings

The sandbox uses Terraform to control Lake Formation's account-level default
Data Catalog behavior:

```hcl
resource "aws_lakeformation_data_lake_settings" "this" {
  admins = [var.your_iam_principal_arn]
}
```

This resource is account/region-level Lake Formation configuration, not a
database or table permission.

The important lesson:

```text
Data lake settings affect future databases and tables.
They do not clean up permissions already attached to existing resources.
```

For this learning repo, we intentionally omit default permission blocks:

```hcl
create_database_default_permissions
create_table_default_permissions
```

Omitting those blocks means newly created Data Catalog databases and tables
should not automatically get the old `IAMAllowedPrincipals` compatibility
grants.

Do not write empty blocks like this:

```hcl
create_database_default_permissions {}
create_table_default_permissions {}
```

AWS rejects that shape because the provider sends an incomplete permission
entry without a valid principal ARN.

The practical migration model is:

```text
1. Set future Lake Formation defaults with aws_lakeformation_data_lake_settings.
2. Add explicit Lake Formation permissions or LF-Tag permissions.
3. Remove old IAMAllowedPrincipals rows from existing resources.
4. Test access with an assumed role.
```

## `for_each` Uses Keys As Instance Addresses

When a resource uses `for_each`, Terraform creates one resource instance for
each item.

Example:

```hcl
resource "aws_athena_workgroup" "team" {
  for_each = {
    team1 = "sandbox-lakehouse-lf-tbac-team1-workgroup"
    team2 = "sandbox-lakehouse-lf-tbac-team2-workgroup"
  }

  name = each.value
}
```

Terraform stores these instances in state using the map keys:

```hcl
aws_athena_workgroup.team["team1"]
aws_athena_workgroup.team["team2"]
```

The important rule:

```text
for_each keys become Terraform instance addresses
```

So Terraform knows that:

```hcl
aws_athena_workgroup.team["team1"]
```

means "the Athena workgroup for team1".

## `each.key` And `each.value`

Inside a `for_each` resource, Terraform gives you two temporary values:

```hcl
each.key
each.value
```

For this map:

```hcl
{
  team1 = "sandbox-lakehouse-lf-tbac-team1-workgroup"
  team2 = "sandbox-lakehouse-lf-tbac-team2-workgroup"
}
```

The first resource instance sees:

```hcl
each.key   = "team1"
each.value = "sandbox-lakehouse-lf-tbac-team1-workgroup"
```

The second resource instance sees:

```hcl
each.key   = "team2"
each.value = "sandbox-lakehouse-lf-tbac-team2-workgroup"
```

That lets us use:

```hcl
name = each.value
```

for the AWS resource name, and:

```hcl
tags = {
  Team = each.key
}
```

for the shorter team tag.

## List vs Set vs Map

A list is ordered:

```hcl
["team1", "team2"]
```

A set is unordered but unique:

```hcl
toset(["team1", "team2"])
```

A map has keys and values:

```hcl
{
  team1 = "sandbox-lakehouse-lf-tbac-team1-workgroup"
  team2 = "sandbox-lakehouse-lf-tbac-team2-workgroup"
}
```

Terraform `for_each` works with maps and sets.

## `for_each` With A Set

Example:

```hcl
resource "aws_s3_bucket" "team_temp" {
  for_each = toset(var.teams)

  bucket = lower("${var.environment}-${var.project_prefix}-${each.value}-temp")
}
```

If:

```hcl
var.teams = ["team1", "team2"]
```

Then:

```hcl
toset(var.teams)
```

becomes a set of unique strings:

```hcl
toset([
  "team1",
  "team2",
])
```

Terraform creates:

```hcl
aws_s3_bucket.team_temp["team1"]
aws_s3_bucket.team_temp["team2"]
```

For a set of strings:

```hcl
each.key == each.value
```

So for the `team1` instance:

```hcl
each.key   = "team1"
each.value = "team1"
```

## `for_each` With A Map

In the Athena workgroup example, we first turn the list into a map:

```hcl
locals {
  team_workgroups = {
    for team in var.teams :
    team => lower("${var.environment}-${var.project_prefix}-${team}-workgroup")
  }
}
```

If:

```hcl
var.teams = ["team1", "team2"]
```

Then Terraform builds:

```hcl
{
  team1 = "sandbox-lakehouse-lf-tbac-team1-workgroup"
  team2 = "sandbox-lakehouse-lf-tbac-team2-workgroup"
}
```

Then this:

```hcl
resource "aws_athena_workgroup" "team" {
  for_each = local.team_workgroups

  name = each.value
}
```

creates:

```hcl
aws_athena_workgroup.team["team1"]
aws_athena_workgroup.team["team2"]
```

This is useful because:

```hcl
each.key
```

is the short team name, while:

```hcl
each.value
```

is the full AWS resource name.

## Referencing A `for_each` Resource

A resource created with `for_each` behaves like a map.

Example:

```hcl
aws_athena_workgroup.team
```

is like:

```hcl
{
  team1 = aws_athena_workgroup.team["team1"]
  team2 = aws_athena_workgroup.team["team2"]
}
```

To reference one instance directly:

```hcl
aws_athena_workgroup.team["team1"].name
```

To loop over all instances in an output:

```hcl
output "team_workgroups" {
  value = {
    for team, workgroup in aws_athena_workgroup.team :
    team => workgroup.name
  }
}
```

This produces:

```hcl
team_workgroups = {
  "team1" = "sandbox-lakehouse-lf-tbac-team1-workgroup"
  "team2" = "sandbox-lakehouse-lf-tbac-team2-workgroup"
}
```

## What Outputs Do

Terraform outputs do not create AWS resources.

They only print useful values after `terraform apply`.

Example:

```hcl
output "team_workgroups" {
  value = {
    for team, workgroup in aws_athena_workgroup.team :
    team => workgroup.name
  }
}
```

This says:

```text
For each Athena workgroup Terraform created, print:
team name => workgroup name
```

Outputs are useful because they show the important names, ARNs, or IDs without
needing to search through the AWS console.

## Interpolation

Terraform interpolation means inserting values into strings.

Example:

```hcl
"${var.environment}-${var.project_prefix}-${team}-workgroup"
```

If:

```hcl
var.environment    = "sandbox"
var.project_prefix = "lakehouse-lf-tbac"
team               = "team1"
```

Then Terraform evaluates the string as:

```text
sandbox-lakehouse-lf-tbac-team1-workgroup
```

Interpolation is common when building AWS names.

## Interpolation With Resource Attributes

This example builds an S3 path using a bucket Terraform created:

```hcl
output_location = "s3://${aws_s3_bucket.shared["query-results"].bucket}/${each.value}/"
```

Breakdown:

```hcl
aws_s3_bucket.shared["query-results"].bucket
```

returns the actual bucket name:

```text
sandbox-lakehouse-lf-tbac-query-results
```

And:

```hcl
each.value
```

returns the workgroup name:

```text
sandbox-lakehouse-lf-tbac-team1-workgroup
```

So Terraform builds:

```text
s3://sandbox-lakehouse-lf-tbac-query-results/sandbox-lakehouse-lf-tbac-team1-workgroup/
```

## `lower(...)`

S3 bucket names must be lowercase.

This:

```hcl
lower("${var.environment}-${var.project_prefix}-${each.value}-temp")
```

forces the final string to lowercase.

That protects against invalid S3 names if someone later sets a variable with
capital letters.

## Why `for_each` Is Often Better Than `count`

With `count`, Terraform addresses resources by number:

```hcl
aws_athena_workgroup.team[0]
aws_athena_workgroup.team[1]
```

With `for_each`, Terraform addresses resources by meaningful keys:

```hcl
aws_athena_workgroup.team["team1"]
aws_athena_workgroup.team["team2"]
```

For named cloud resources, `for_each` is usually easier to understand and safer
to maintain.

If the team list changes order, `for_each` still knows which resource belongs
to which team because the key is stable.
