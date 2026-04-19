resource "helm_release" "argocd" {
  name             = "argocd"
  repository       = "https://argoproj.github.io/argo-helm"
  chart            = "argo-cd"
  version          = "9.5.0"
  namespace        = "argocd"
  create_namespace = true

  values = [file("${path.module}/argocd-values.yaml")]

  depends_on = [module.eks]
}
