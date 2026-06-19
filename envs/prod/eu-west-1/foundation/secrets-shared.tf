########################################################################
# Shared workload secrets (formerly in platform/secrets.tf)
#
# These secrets were originally created in the EKS-tied platform layer
# but the homelab consumes them via ExternalSecrets (jwt + google-creds +
# mongodb for namiview-api/worker; grafana for the in-cluster Grafana).
#
# Kept in foundation so EKS platform teardown (~2026-06-06) doesn't take
# them with it. Same name pattern as before (`${cluster_name}/<purpose>`),
# so all in-cluster ExternalSecret manifests keep working unchanged.
#
# Values are populated by hand in the AWS Console — never set from TF.
# `prevent_destroy = true` to match every other secret in this layer.
########################################################################

resource "aws_secretsmanager_secret" "jwt" {
  name        = "${var.cluster_name}/jwt"
  description = "JWT signing secret. Consumed by namiview-api (both EKS and homelab) via ExternalSecrets."

  lifecycle {
    prevent_destroy = true
  }
}

resource "aws_secretsmanager_secret" "google_creds" {
  name        = "${var.cluster_name}/google-creds"
  description = "Google OAuth credentials JSON. Consumed by namiview-api (both EKS and homelab) via ExternalSecrets."

  lifecycle {
    prevent_destroy = true
  }
}

resource "aws_secretsmanager_secret" "mongodb" {
  name        = "${var.cluster_name}/mongodb"
  description = "MongoDB Atlas connection credentials. Consumed by namiview-api + namiview-worker (both EKS and homelab) via ExternalSecrets."

  lifecycle {
    prevent_destroy = true
  }
}

resource "aws_secretsmanager_secret" "grafana" {
  name        = "${var.cluster_name}/grafana"
  description = "Grafana admin credentials. Consumed by the in-cluster Grafana (both EKS and homelab) via ExternalSecrets."

  lifecycle {
    prevent_destroy = true
  }
}

########################################################################
# Dev-only JWT signing secret (namiview#285)
#
# The homelab `namiview-dev` API currently reads `${cluster_name}/jwt` —
# i.e. dev signs JWTs with PROD's key, so a token minted for dev is valid
# in prod. This gives dev its own signing secret; pointing the dev API at
# it (apps-homelab-dev/namiview-api/values.yaml) makes dev-minted tokens
# invalid in prod.
#
# Lives under the `${cluster_name}/*` prefix so the existing ESO IAM read
# policy covers it with no IAM change. Unlike every other secret here, the
# value is GENERATED IN TF (deliberate decision) rather than set by hand.
########################################################################

resource "random_password" "jwt_dev" {
  length  = 64
  special = false
}

resource "aws_secretsmanager_secret" "jwt_dev" {
  name        = "${var.cluster_name}/dev-jwt"
  description = "Dev JWT signing secret (homelab namiview-dev). Distinct from ${var.cluster_name}/jwt so dev-minted tokens are rejected by prod."

  lifecycle {
    prevent_destroy = true
  }
}

resource "aws_secretsmanager_secret_version" "jwt_dev" {
  secret_id     = aws_secretsmanager_secret.jwt_dev.id
  secret_string = jsonencode({ JWT_SECRET = random_password.jwt_dev.result })
}
