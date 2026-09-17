# Identity And Authorization Learning Plan

This track separates identity, authentication, and authorization learning from
the Lake Formation ABAC hands-on notes.

## Core Terms

Authentication:

```text
Proving who the user is.
```

Authorization:

```text
Deciding what the user can do.
```

## Current Data Platform Context

Glue:

```text
Metadata/catalog.
```

Athena:

```text
Query engine.
```

Lake Formation:

```text
Data authorization and governance.
```

IAM Identity Center, Entra, and SAML:

```text
Workforce identity, federation, and session attributes.
```

## Learning Order

1. IAM Identity Center native users and attributes

   Goal:

   ```text
   Create Alice/Bob users in IAM Identity Center with department/job_role-style
   attributes.
   ```

2. Lake Formation and IAM Identity Center integration

   Goal:

   ```text
   Understand workforce identities, groups, auditing, and identity-aware Lake
   Formation behavior.
   ```

3. Microsoft Entra ID to IAM Identity Center

   Pattern A:

   ```text
   Entra -> IAM Identity Center -> permission set -> AWSReservedSSO role
   ```

   Goal:

   ```text
   Learn AWS-native workforce federation with external IdP attributes.
   ```

4. Direct SAML federation to IAM role

   Pattern B:

   ```text
   Entra -> AWS STS AssumeRoleWithSAML -> IAM role
   ```

   Goal:

   ```text
   Understand non-IAM-Identity-Center, legacy, or vendor federation into AWS
   roles.
   ```

5. Mini Posit-style Athena app

   Goal:

   ```text
   Build a small local app or notebook that runs Athena using governed
   credentials.
   ```

   Test both identity patterns:

   ```text
   Pattern A credentials from IAM Identity Center
   Pattern B credentials from direct SAML federation
   ```

6. Access portal, full Cedar, and AWS Verified Permissions

   Goal:

   ```text
   Learn application authorization and workflow authorization later.
   ```

## Pattern A vs Pattern B

Pattern A:

```text
Entra/Okta -> IAM Identity Center -> permission set -> AWSReservedSSO role
```

Use this for AWS-native workforce access across AWS accounts.

Pattern B:

```text
Entra/Okta -> AWS STS AssumeRoleWithSAML -> IAM role
```

Use this to understand direct federation, older federation patterns, or vendor
integrations that do not use IAM Identity Center.

## External Tool Rule

If a tool queries through Athena with governed credentials, Lake Formation is in
the access path.

If a tool reads governed S3 data directly with broad IAM permissions, it can
bypass Lake Formation.

## How This Relates To Posit And Denodo

Mini Posit-style learning is a practical test harness for external analytics
tools.

Pattern A version:

```text
Tool/app -> IAM Identity Center credentials -> Athena -> Lake Formation
```

Pattern B version:

```text
Tool/app -> direct SAML-federated IAM role credentials -> Athena -> Lake Formation
```

The key comparison:

```text
Which identity reaches AWS?
Which principal attributes are present?
What appears in CloudTrail and Lake Formation audit logs?
Does Lake Formation ABAC evaluate the attributes correctly?
```

## Deferred Questions

```text
How do Posit and Denodo obtain AWS credentials in real deployments?
Can they use IAM Identity Center credentials directly?
Can they use direct SAML federation?
What identity appears in CloudTrail and Lake Formation audit logs?
Which pattern gives cleaner ABAC attributes?
How should Lake Formation ABAC grants be managed as code?
```
