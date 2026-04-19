# EKS Teardown / Bring-up Roadmap

**Goal:** Click a button to tear down the EKS cluster to save money when no one's using it, and have a visitor bring it back up via a landing page in ~30 minutes. Secrets, S3 data, DNS, and ACM certs survive across cycles.

**Status legend:** `[ ]` todo · `[~]` in progress · `[x]` done · `[?]` design not finalized

**How to use this file:** each step below has a design section and a task list. The ones marked `[?]` still need a design pass before implementation — we'll go through them one by one.

---

## Step 1 — Split Terraform into two layers

### Why

Right now everything is one state (`envs/prod/eu-west-1/terraform.tfstate`). If we `terraform destroy` we also blow away the VPC, S3 bucket, Secrets Manager entries, OIDC role, and ACM cert — which means losing all user data, losing the DNS-validated cert (and waiting for re-validation), and losing the GitHub OIDC trust. We need a persistent layer and a disposable layer.

### Design — two-layer split

```
envs/prod/eu-west-1/
  foundation/          ← ALWAYS ON — cheap, persistent
    providers.tf
    variables.tf
    locals.tf
    vpc.tf             ← VPC + subnets (NAT gateway decision below)
    s3.tf              ← namiview-prod-bucket (user data)
    secrets.tf         ← all AWS Secrets Manager entries (PATs, mongo creds, etc.)
    github-oidc.tf     ← namiview-terraform-ci role (GitHub OIDC provider + role)
    acm.tf             ← wildcard/SAN cert — DNS-validated, keep to avoid re-issue
    outputs.tf         ← exports everything the EKS layer needs

  eks/                 ← ON DEMAND — torn down to save money
    providers.tf       ← aws + kubernetes + helm (helm/k8s providers need cluster)
    variables.tf
    locals.tf
    data.tf            ← terraform_remote_state "foundation"
    eks.tf             ← cluster + managed node group + addons
    karpenter.tf       ← IRSA, SQS, EventBridge, Helm release, service-linked spot role
    alb.tf             ← AWS Load Balancer Controller Helm release (ACM arn from foundation)
    argocd-bootstrap.tf
    argocd.tf
    outputs.tf
```

### State backend keys

- `s3://namiview-terraform-state/prod/eu-west-1/foundation/terraform.tfstate`
- `s3://namiview-terraform-state/prod/eu-west-1/eks/terraform.tfstate`

### Cross-layer linkage

```hcl
# eks/data.tf
data "terraform_remote_state" "foundation" {
  backend = "s3"
  config = {
    bucket = "namiview-terraform-state"
    key    = "prod/eu-west-1/foundation/terraform.tfstate"
    region = "eu-west-1"
  }
}
```

### NAT Gateway decision

- **Keep in foundation** — simpler, but NAT costs ~$32/mo even when cluster is down.
- **Move to EKS layer** — saves ~$32/mo while torn down, adds ~2 min to bring-up, and the NAT public IP changes on each recreate.

**Decision:** move NAT to EKS layer. Keep VPC/subnets/route tables in foundation, only the NAT gateway + EIP + default route lives in `eks/`.

### Outputs foundation must expose

```
vpc_id
private_subnets
public_subnets
vpc_cidr_block
private_route_table_ids   # for EKS layer to attach NAT gateway default route
s3_bucket_name
s3_bucket_arn
acm_certificate_arn
github_actions_role_arn
secrets_manager_arns      # map used by ESO
```

### Migration plan (one-time)

1. Back up current flat state to a dated S3 key.
2. Create `foundation/` and `eks/` subdirectories.
3. Move `.tf` files into their new homes.
4. Split `locals.tf`, `variables.tf`, `outputs.tf` by concern.
5. `terraform init` in each new layer (new backend key).
6. Use `terraform state mv` with `-state` / `-state-out` flags to split the flat state into two per-layer state files, push each to its backend key.
7. `terraform plan` in each layer, expect **zero** changes.
8. Commit, push.

### Tasks

- [ ] Create `foundation/` and `eks/` directory scaffolds
- [ ] Decide exact file splits
- [ ] Add `terraform_remote_state` data source in `eks/data.tf`
- [ ] Move NAT gateway resource into `eks/`, expose `private_route_table_ids` from foundation
- [ ] Back up flat state to dated S3 key
- [ ] Run state migration
- [ ] Verify `terraform plan` clean in both layers

---

## Step 2 — Bootstrap ordering on cold cluster  `[?]`

### Why

Today the cluster has been up for weeks and everything's already reconciled. On a fresh bring-up, we have ordering problems:

- **CRDs before CRs** — ExternalSecret, ServiceMonitor, Karpenter NodePool, ALB IngressClassParams all need their CRDs installed before ArgoCD tries to sync resources using them.
- **ESO before apps** — any app pulling secrets from Secrets Manager (`namiview-api`, ARC runner sets) must wait for External Secrets Operator to be ready AND its IRSA to be working.
- **ALB Controller before Ingresses** — no Ingress provisions until the controller's webhook is up.
- **Karpenter before workloads** — workload pods with `nodeSelector: role=workload` will stay Pending until Karpenter reconciles and provisions a node. That's fine, but it means cold-boot time is dominated by Karpenter + node join.
- **ArgoCD before anything** — and ArgoCD itself has to come up on the system managed node group.

### What needs designing

- Where is the boundary between Terraform and ArgoCD on cold boot?
  - Today: TF installs ArgoCD + Karpenter + ALB Controller via `helm_release`, then ArgoCD installs everything else.
  - Question: should `cert-manager`, `external-secrets`, `kube-prometheus-stack` be TF-installed too, so ArgoCD only handles the app layer? Or is the current split correct?
- ArgoCD sync-wave annotations — audit which apps have them, assign waves so:
  - wave 0: CRDs (kube-prometheus-stack CRDs-only app, ESO CRDs)
  - wave 1: operators (ESO controller, cert-manager)
  - wave 2: cluster services (ClusterSecretStore, ClusterIssuer)
  - wave 3: app namespaces, ExternalSecrets, Certificates
  - wave 4: workloads
- What's an acceptable cold-boot timeout before we consider bring-up failed?

### Tasks

- [ ] Map current install path: what TF installs vs what ArgoCD installs
- [ ] Pick the TF/ArgoCD boundary
- [ ] Annotate every ArgoCD `Application` with `argocd.argoproj.io/sync-wave`
- [ ] Add `CreateNamespace=true` + `ServerSideApply=true` where missing
- [ ] Dry-run cold boot in a scratch cluster (or in a branch) to find ordering bugs

---

## Step 3 — DNS automation on new ALB  `[?]`

### Why

Each fresh cluster gets a new ALB with a new `*.elb.amazonaws.com` hostname. Cloudflare's CNAME for `eks.namiview.com` currently points at the current ALB. On recreate, that CNAME has to move.

### Options

- **`external-dns` in-cluster** — watches Ingresses, updates Cloudflare via API token. Pros: automatic, declarative. Cons: another pod, needs its own secret.
- **Post-apply step in `eks.yml`** — `terraform output alb_hostname`, then `curl` Cloudflare API to update CNAME. Pros: no in-cluster component, one-shot. Cons: drift if someone changes DNS manually, logic lives in CI not in the cluster.
- **Stable ALB hostname via `ingress.alb.ingress.kubernetes.io/load-balancer-name` + a shared group** — you already have `alb.ingress.kubernetes.io/group.name: eks-namiview`, so ALB is reused across Ingresses, but the _hostname_ still changes on teardown. Doesn't solve the problem.

### What needs designing

- Pick `external-dns` vs CI post-apply.
- If `external-dns`: Cloudflare API token scope, ESO binding, which Ingresses it watches.
- If CI post-apply: where the Cloudflare token lives (Secrets Manager → pulled in the GitHub Action via OIDC), idempotency.

### Tasks

- [ ] Decide external-dns vs post-apply
- [ ] Implement chosen option
- [ ] Test by destroying and recreating ALB, confirm DNS updates within ~1 min

---

## Step 4 — GitHub Actions workflow split  `[?]`

### Why

Currently `.github/workflows/terraform.yml` runs `plan` against flat state. After the TF split we need two workflows.

### Plan

- `.github/workflows/foundation.yml`
  - Triggers: `push` on `main` for `foundation/**` changes, `pull_request` for plan only.
  - Runs on `arc-runner-set-terraform` (foundation changes are rare, cluster is usually up when we touch them).
  - Steps: AWS CLI install, OIDC assume-role, `setup-terraform` with `terraform_wrapper: false`, `init`, `plan`, `apply` on merge.

- `.github/workflows/eks.yml`
  - Triggers: `workflow_dispatch` with `action` input (`plan` / `apply` / `destroy`), plus `repository_dispatch: [eks-up]` from Cloudflare Worker.
  - Post-apply: write progress to Cloudflare KV at each major step.

### Chicken-and-egg

ARC runners live inside the cluster. If cluster is down, `eks.yml` can't run on `arc-runner-set-terraform`.

- **Option A:** `eks.yml` always runs on `ubuntu-latest`. Needs re-opened public EKS endpoint, or VPN.
- **Option B:** `apply` runs on `ubuntu-latest` (no cluster needed — we're creating it). `destroy` runs on `ubuntu-latest` with temporary public endpoint OR deletes Helm releases via ArgoCD first.
- **Option C:** Temporary public access during apply/destroy, CIDR-scoped to GitHub Actions runner IP ranges.

### What needs designing

- Pick option A/B/C.
- If B: how does `destroy` reach the cluster for helm/kubernetes provider destroys? (probably: remove ArgoCD-managed releases via ArgoCD CLI first, then TF destroy doesn't need cluster reachability)
- Confirmation gate for `destroy` (required reviewer? second input?).
- How does `repository_dispatch` from Worker authenticate? Scoped PAT.

### Tasks

- [ ] Resolve chicken-and-egg (pick option)
- [ ] Write `foundation.yml`
- [ ] Write `eks.yml` with plan/apply/destroy inputs
- [ ] Add `repository_dispatch: [eks-up]` trigger
- [ ] Post-apply hook to write progress to Cloudflare KV
- [ ] Gate `destroy` behind second confirmation

---

## Step 5 — Cloudflare Worker + landing page  `[?]`

### Why

When `eks.namiview.com` has no cluster behind it, visitors should see: "Namiview is currently down to save cost. Click to start (~30 min)."

### Architecture

```
visitor → eks.namiview.com (Cloudflare)
                │
                ├─ if cluster up   → proxy to ALB
                └─ if cluster down → landing page + "Start" button
                                       └─ POST /_start → GitHub repository_dispatch
                                                         → eks.yml apply
```

### Worker responsibilities

1. GET `/` → health-check ALB (or read KV flag). If up, proxy. If down, serve landing page.
2. POST `/_start` → rate-limit, call GitHub API `repos/Darbuki/namiview-terraform/dispatches` with `event_type: eks-up`.
3. GET `/_status` → read KV progress flag, return JSON for landing page polling.
4. POST `/_stop` (optional, admin-only) → `event_type: eks-down`.

### Progress indicator

`eks.yml` writes to Cloudflare KV at each milestone: `vpc-ready`, `cluster-ready`, `argocd-ready`, `apps-healthy`. Landing page polls `/_status` every ~30s.

### What needs designing

- Worker repo location (new repo? monorepo? in `namiview-terraform/cloudflare-worker/`?)
- KV namespace name + key schema
- PAT scope (fine-grained, `actions: write` + `contents: read` on `namiview-terraform`)
- Landing page design — branded, minimal, progress bar
- Anti-abuse on `/_start` (rate limit by IP, Turnstile challenge?)

### Tasks

- [ ] Pick repo location for Worker code
- [ ] Design landing page HTML/CSS
- [ ] Write Worker script
- [ ] Cloudflare KV namespace + binding
- [ ] Generate scoped PAT, store as Worker secret
- [ ] Deploy via `wrangler`
- [ ] Flip `eks.namiview.com` traffic through Worker
- [ ] End-to-end test

---

## Step 6 — Teardown safety

### Must survive every cycle

- [ ] S3 bucket + contents — lifecycle `prevent_destroy` + versioning
- [ ] Secrets Manager entries — PATs, mongo creds, google creds, JWT, dockerhub
- [ ] ACM cert (re-issuing hits rate limits)
- [ ] GitHub OIDC provider + `namiview-terraform-ci` role
- [ ] VPC + subnets + IGW (so subnet IDs stay stable)
- [ ] Cloudflare DNS (external to TF anyway)
- [ ] MongoDB Atlas (external service)

### Ephemeral (recreated, fine)

- EKS cluster + managed node group
- Karpenter nodes (all spot anyway)
- ALB (DNS handled by Step 3)
- NAT gateway (EIP changes, nothing depends on it)
- ArgoCD + all apps (redeploy from Git)

### Tasks

- [ ] Add `lifecycle { prevent_destroy = true }` to S3 bucket
- [ ] Verify S3 versioning enabled
- [ ] Audit foundation `.tf` for accidental coupling to EKS outputs
- [ ] Document ephemeral vs persistent list in this file and keep current

---

## Step 7 — Runbook + observability  `[?]`

### Why

First few cycles will hit unexpected issues. Need a place to look and a way to know when things went sideways.

### What needs designing

- **Runbook** — a checklist for "it's stuck during bring-up, where do I look":
  - Foundation apply failed → CI logs
  - EKS apply stuck → CloudTrail + EKS events
  - ArgoCD not syncing → ArgoCD UI + app status (how do I reach ArgoCD when cluster just came up? `kubectl port-forward` via ARC? or through the Ingress once ALB is up?)
  - App pods not scheduling → Karpenter logs, node pool events
- **Cost dashboard** — AWS Budgets alarm per environment, Grafana panel showing $/day if we can pull Cost Explorer into Prometheus somehow.
- **Teardown alerting** — if teardown fires while a user is mid-request, how do we know? Does the Worker log it? Does the GH workflow notify?
- **Metric retention across teardown** — Prometheus/Grafana data is in-cluster and dies with the cluster. Options: accept it, move to Grafana Cloud free tier, or put Prometheus remote-write to an external store.

### Tasks

- [ ] Write runbook in `.claude/RUNBOOK.md`
- [ ] Set up AWS Budget + alarm
- [ ] Decide on metrics retention across teardown
- [ ] Notification channel for teardown/bring-up events (Slack? email? GH issue?)

---

## Step 8 — First dry run

- [ ] Back up current flat state to dated S3 key
- [ ] Execute Step 1 migration
- [ ] Verify `plan` clean on both layers
- [ ] Manually trigger `eks.yml action=destroy`
- [ ] Confirm S3, Secrets, ACM, OIDC, VPC all intact
- [ ] Manually trigger `eks.yml action=apply`
- [ ] Confirm stack comes up, ArgoCD syncs, app reachable via DNS
- [ ] Record bring-up timings below

**Bring-up timing actuals:** _(fill in after first dry run)_

| Phase | Time |
|---|---|
| NAT + networking | |
| EKS control plane | |
| Managed node group ready | |
| Addons ready | |
| ArgoCD installed | |
| Cluster services synced (ESO, Karpenter, ALB Ctrl) | |
| Karpenter first node | |
| App pods healthy | |
| DNS updated | |
| **Total** | |

---

## Reference — current state (pre-split)

### Flat state

Key: `prod/eu-west-1/terraform.tfstate`
Providers: `aws ~> 6.0`, `helm ~> 3.0`, `kubernetes ~> 3.0`

### Current files

- `vpc.tf` — VPC, private `10.0.1.0/24, 10.0.2.0/24`, public `10.0.101.0/24, 10.0.102.0/24`, single NAT (~$32/mo)
- `eks.tf` — EKS `1.35`, private endpoint only, system node group (t3.medium × 2), addons, EBS CSI IRSA, gp3 StorageClass
- `karpenter.tf` — spot service-linked role, node role, SQS + EventBridge, IRSA, Helm release
- `alb.tf` — ACM cert, ALB Controller Helm release
- `argocd-bootstrap.tf` / `argocd.tf` — ArgoCD install + AppProject + root app
- `secrets.tf` — `arc-github-token`, `arc-github-token-terraform`, app secrets
- `github-oidc.tf` — OIDC provider + `namiview-terraform-ci` role
- `s3.tf` — `namiview-prod-bucket`

### Node layout

- System managed node group: `role=system`, t3.medium × 2–3 (Karpenter ctrl, CoreDNS, ArgoCD, ALB ctrl, ARC ctrl + runners)
- Karpenter NodePool `default`: `role=workload`, spot+on-demand, t3/t3a medium/large, limits cpu=16 mem=64Gi

### Application constraints

- `namiview-api`: request 250m/256Mi, limit 1000m/4Gi (bumped from 2Gi after 5.8MB image OOM)
- `nodeSelector: role=workload`
- PDB disabled, single replica

### ARC controllers

- `arc-runner-set` → `namiview` repo
- `arc-runner-set-terraform` → `namiview-terraform` repo
- `controllerServiceAccount.name: arc-controller-gha-rs-controller`
- `minRunners: 0, maxRunners: 3`
- Secrets via ESO from Secrets Manager (`arc-github-token`, `arc-github-token-terraform`)

---

## Future roadmap steps (placeholders)

- [ ] **Step 9** — Auto-teardown after N hours of zero traffic (Worker + GitHub API)
- [ ] **Step 10** — WAF on the ALB (see `feedback_waf_security.md`)
- [ ] **Step 11** — Multi-region DR (if we ever care)
- [ ] **Step 12** — Restore public EKS API behind bastion / Tailscale subnet router
