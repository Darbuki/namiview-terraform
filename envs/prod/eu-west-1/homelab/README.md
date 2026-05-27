# homelab layer

Cluster-coupled bootstrap for the homelab k3s cluster:
- ArgoCD Helm release
- AppProject `namiview`
- Root Applications for `apps-homelab`, `apps-homelab-dev`, `infrastructure-homelab`

Durable AWS resources (IAM users for the cluster, S3 buckets, SQS queues,
Secrets Manager, ECR) live in the foundation layers:
- `envs/prod/eu-west-1/foundation/` — prod IAM user, prod bucket+queues, ECR, SM
- `envs/dev/eu-west-1/foundation/`  — dev IAM user, dev bucket+queues

## Bootstrap order

1. Foundation layers applied (IAM users created, access keys output)
2. k3s installed on the server (Phase 2)
3. `aws-credentials` secrets manually created in `external-secrets`, `namiview`,
   `namiview-dev` namespaces from foundation outputs
4. `terraform apply` here to bring up ArgoCD + AppProject + root Apps
