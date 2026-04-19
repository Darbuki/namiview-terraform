# foundation/ — persistent AWS state

This directory is the first slice of the **foundation / workload** Terraform
split described in `.claude/ROADMAP.md`.

## What lives here

Resources that must survive an EKS teardown / rebuild:

- AWS Secrets Manager entries (values populated by hand, not TF-managed).
- (future) Route53 hosted zones, ACM certs, the S3 state bucket's own
  bootstrap, long-lived IAM users/roles, etc.

Every resource in this layer should carry `lifecycle { prevent_destroy =
true }` — a `terraform destroy` on this layer should be a rare, deliberate
act.

## What does NOT live here

Anything tied to the EKS cluster's lifecycle — VPC, EKS, Karpenter,
ArgoCD, IRSA roles for workloads, ALB/Route53 records pointing at the
cluster. Those stay in the flat state at `envs/prod/eu-west-1/*.tf` until
they are migrated in a later step of the roadmap.

## State

Backend key: `prod/eu-west-1/foundation/terraform.tfstate` (separate from
the flat layer's `prod/eu-west-1/terraform.tfstate`).

## How the workload layer references these secrets

The workload layer's ESO IAM policy references these secrets by **ARN
name pattern** (`arn:aws:secretsmanager:REGION:ACCOUNT:secret:NAME-*`),
not via `terraform_remote_state`. That keeps the two layers decoupled:
the workload layer does not need to read this layer's state.

The secret **name** is the contract between the two layers, and it is
derived from `cluster_name` — so both layers must use the same
`cluster_name` value.

## First-apply workflow

```
cd envs/prod/eu-west-1/foundation
terraform init
terraform plan
terraform apply
# Then, in the AWS Console, populate secret values for:
#   namiview-prod/anthropic-api-key
#   namiview-prod/triage-agent-github-pat
```

Secret values are **never** committed and **never** set from Terraform —
they are populated manually in the AWS Console.
