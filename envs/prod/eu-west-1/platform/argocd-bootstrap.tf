resource "kubernetes_manifest" "argocd_project" {
  manifest = {
    apiVersion = "argoproj.io/v1alpha1"
    kind       = "AppProject"
    metadata = {
      name      = "namiview"
      namespace = local.argocd_namespace
    }
    spec = {
      description = "Default project"
      sourceRepos = [
        local.gitops_repo,
        local.charts_repo,
        "https://charts.external-secrets.io",
        "https://prometheus-community.github.io/helm-charts",
        "https://grafana-community.github.io/helm-charts",
        "https://grafana.github.io/helm-charts",
        "ghcr.io/actions/actions-runner-controller-charts",
        "https://kedacore.github.io/charts",
        "https://pkgs.tailscale.com/helmcharts"
      ]
      destinations = [
        { namespace = "namiview", server = local.k8s_server },
        { namespace = "namiview-agents", server = local.k8s_server },
        { namespace = "argocd", server = local.k8s_server },
        { namespace = "monitoring", server = local.k8s_server },
        { namespace = "kube-system", server = local.k8s_server },
        { namespace = "external-secrets", server = local.k8s_server },
        { namespace = "karpenter", server = local.k8s_server },
        { namespace = "arc-systems", server = local.k8s_server },
        { namespace = "arc-runners", server = local.k8s_server },
        { namespace = "keda", server = local.k8s_server },
        { namespace = "tailscale", server = local.k8s_server },
        { namespace = "namiview-dev", server = local.k8s_server },
        { namespace = "logging", server = local.k8s_server },
      ]
      # Only the cluster-scoped resources our apps actually create
      clusterResourceWhitelist = [
        { group = "", kind = "Namespace" },
        { group = "rbac.authorization.k8s.io", kind = "ClusterRole" },
        { group = "rbac.authorization.k8s.io", kind = "ClusterRoleBinding" },
        { group = "external-secrets.io", kind = "ClusterSecretStore" },
        { group = "storage.k8s.io", kind = "StorageClass" },
        { group = "apiextensions.k8s.io", kind = "CustomResourceDefinition" },
        { group = "admissionregistration.k8s.io", kind = "MutatingWebhookConfiguration" },
        { group = "admissionregistration.k8s.io", kind = "ValidatingWebhookConfiguration" },
        { group = "karpenter.sh", kind = "NodePool" },
        { group = "karpenter.k8s.aws", kind = "EC2NodeClass" },
        { group = "apiregistration.k8s.io", kind = "APIService" },
        { group = "networking.k8s.io", kind = "IngressClass" },
        # Tailscale operator's CRDs — Connector advertises subnet routes,
        # ProxyClass customizes proxy pods, DNSConfig manages tailnet DNS.
        # All cluster-scoped despite living "near" namespaces conceptually.
        { group = "tailscale.com", kind = "Connector" },
        { group = "tailscale.com", kind = "ProxyClass" },
        { group = "tailscale.com", kind = "DNSConfig" },
      ]
    }
  }

  depends_on = [helm_release.argocd]
}

resource "kubernetes_manifest" "argocd_apps_root" {
  manifest = {
    apiVersion = "argoproj.io/v1alpha1"
    kind       = "Application"
    metadata = {
      name      = "apps-root"
      namespace = local.argocd_namespace
    }
    spec = {
      project = "namiview"
      source = {
        repoURL        = local.gitops_repo
        targetRevision = var.argocd_target_revision
        path           = "apps-eks"
      }
      destination = {
        server    = local.k8s_server
        namespace = local.argocd_namespace
      }
      syncPolicy = {
        automated = {
          prune    = true
          selfHeal = true
        }
      }
    }
  }

  computed_fields = ["spec.operation", "metadata.labels", "metadata.annotations", "metadata.finalizers"]

  depends_on = [kubernetes_manifest.argocd_project]
}

resource "kubernetes_manifest" "argocd_apps_root_dev" {
  manifest = {
    apiVersion = "argoproj.io/v1alpha1"
    kind       = "Application"
    metadata = {
      name      = "apps-root-dev"
      namespace = local.argocd_namespace
    }
    spec = {
      project = "namiview"
      source = {
        repoURL        = local.gitops_repo
        targetRevision = var.argocd_dev_target_revision
        path           = "apps-eks-dev"
      }
      destination = {
        server    = local.k8s_server
        namespace = local.argocd_namespace
      }
      syncPolicy = {
        automated = {
          prune    = true
          selfHeal = true
        }
      }
    }
  }

  computed_fields = ["spec.operation", "metadata.labels", "metadata.annotations", "metadata.finalizers"]

  depends_on = [kubernetes_manifest.argocd_project]
}

resource "kubernetes_manifest" "argocd_infrastructure_root" {
  manifest = {
    apiVersion = "argoproj.io/v1alpha1"
    kind       = "Application"
    metadata = {
      name      = "infrastructure-root"
      namespace = local.argocd_namespace
    }
    spec = {
      project = "namiview"
      source = {
        repoURL        = local.gitops_repo
        targetRevision = var.argocd_infrastructure_target_revision
        path           = "infrastructure-eks"
      }
      destination = {
        server    = local.k8s_server
        namespace = local.argocd_namespace
      }
      syncPolicy = {
        automated = {
          prune    = true
          selfHeal = true
        }
      }
    }
  }

  computed_fields = ["spec.operation", "metadata.labels", "metadata.annotations", "metadata.finalizers"]

  depends_on = [kubernetes_manifest.argocd_project]
}
