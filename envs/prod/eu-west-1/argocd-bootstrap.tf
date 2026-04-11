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
        "https://charts.external-secrets.io"
      ]
      destinations = [{
        namespace = "*"
        server    = local.k8s_server
      }]
      clusterResourceWhitelist = [{
        group = "*"
        kind  = "*"
      }]
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
