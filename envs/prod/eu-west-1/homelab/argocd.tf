resource "helm_release" "argocd" {
  name       = "argocd"
  repository = "https://argoproj.github.io/argo-helm"
  chart      = "argo-cd"
  version    = "9.5.0"
  namespace  = kubernetes_namespace.argocd.metadata[0].name

  values = [file("${path.module}/argocd-values.yaml")]
}
