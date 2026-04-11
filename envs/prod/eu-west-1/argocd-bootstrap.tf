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
        "https://prometheus-community.github.io/helm-charts"
      ]
      destinations = [
        { namespace = "namiview",   server = local.k8s_server },
        { namespace = "argocd",     server = local.k8s_server },
        { namespace = "monitoring", server = local.k8s_server },
        { namespace = "kube-system", server = local.k8s_server },
        { namespace = "external-secrets", server = local.k8s_server },
        { namespace = "karpenter",  server = local.k8s_server },
      ]
      # Only the cluster-scoped resources our apps actually create
      clusterResourceWhitelist = [
        { group = "",                          kind = "Namespace" },
        { group = "rbac.authorization.k8s.io", kind = "ClusterRole" },
        { group = "rbac.authorization.k8s.io", kind = "ClusterRoleBinding" },
        { group = "external-secrets.io",       kind = "ClusterSecretStore" },
        { group = "storage.k8s.io",            kind = "StorageClass" },
        { group = "apiextensions.k8s.io",      kind = "CustomResourceDefinition" },
        { group = "admissionregistration.k8s.io", kind = "MutatingWebhookConfiguration" },
        { group = "admissionregistration.k8s.io", kind = "ValidatingWebhookConfiguration" },
        { group = "karpenter.sh",              kind = "NodePool" },
        { group = "karpenter.k8s.aws",         kind = "EC2NodeClass" },
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
        targetRevision = var.argocd_target_revision
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

  depends_on = [kubernetes_manifest.argocd_project]
}
