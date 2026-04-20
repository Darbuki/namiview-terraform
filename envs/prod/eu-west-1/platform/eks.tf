module "eks" {
  source  = "terraform-aws-modules/eks/aws"
  version = "~> 21.0"

  name               = var.cluster_name
  kubernetes_version = "1.35"

  vpc_id     = module.vpc.vpc_id
  subnet_ids = module.vpc.private_subnets

  # Control plane logging
  # Only audit logs — the rest add cost with little value for a small project
  enabled_log_types = ["audit"]

  endpoint_public_access                   = false
  endpoint_private_access                  = true
  enable_cluster_creator_admin_permissions = false

  access_entries = {
    ci = {
      principal_arn = "arn:aws:iam::${data.aws_caller_identity.current.account_id}:role/namiview-terraform-ci"
      policy_associations = {
        cluster_admin = {
          policy_arn = "arn:aws:eks::aws:cluster-access-policy/AmazonEKSClusterAdminPolicy"
          access_scope = {
            type = "cluster"
          }
        }
      }
    }
    dar = {
      principal_arn = "arn:aws:iam::${data.aws_caller_identity.current.account_id}:user/darNamiview"
      policy_associations = {
        cluster_admin = {
          policy_arn = "arn:aws:eks::aws:cluster-access-policy/AmazonEKSClusterAdminPolicy"
          access_scope = {
            type = "cluster"
          }
        }
      }
    }
  }

  # Own the `karpenter.sh/discovery` tag on the shared node security group.
  # Declaring it here makes TF authoritative and eliminates the plan churn.
  node_security_group_tags = {
    "karpenter.sh/discovery" = var.cluster_name
  }

  # EKS managed add-ons.
  # TODO: drift source #2 — `most_recent = true` re-resolves the latest
  # published addon version on every plan. When AWS ships a new version,
  # the plan quietly upgrades and can trigger a node group rollout (~15min
  # apply). Pin versions explicitly once we've settled on a baseline, so
  # upgrades become PR-reviewed events rather than apply-time surprises.
  addons = {
    coredns    = { most_recent = true }
    kube-proxy = { most_recent = true }
    vpc-cni = {
      most_recent    = true
      before_compute = true
      configuration_values = jsonencode({
        env = {
          ENABLE_PREFIX_DELEGATION = "true"
        }
      })
    }
    eks-pod-identity-agent = { most_recent = true }
    metrics-server         = { most_recent = true }
    aws-ebs-csi-driver = {
      most_recent              = true
      service_account_role_arn = module.ebs_csi_irsa.iam_role_arn
    }
  }

  # TODO: drift source #3 — the module-internal
  # `aws_iam_openid_connect_provider` shows a thumbprint diff on most plans
  # because the `tls_certificate` data source re-reads AWS's OIDC cert and
  # the thumbprint rotates. Benign but noisy. Can't set `lifecycle` on a
  # resource inside the module from here; options are (a) ignore the noise,
  # or (b) fork/wrap the module to add `ignore_changes = [thumbprint_list]`.

  # Static system node group
  eks_managed_node_groups = {
    system = {
      instance_types = ["t3.medium"]
      min_size       = 2
      max_size       = 3
      desired_size   = 2

      labels = {
        role = "system"
      }
    }
  }
}

# gp3 StorageClass — cheaper and faster than default gp2
resource "kubernetes_storage_class" "gp3" {
  metadata {
    name = "gp3"
    annotations = {
      "storageclass.kubernetes.io/is-default-class" = "true"
    }
  }

  storage_provisioner    = "ebs.csi.aws.com"
  volume_binding_mode    = "WaitForFirstConsumer"
  reclaim_policy         = "Delete"
  allow_volume_expansion = true

  parameters = {
    type = "gp3"
  }

  depends_on = [module.eks]
}

module "ebs_csi_irsa" {
  source  = "terraform-aws-modules/iam/aws//modules/iam-role-for-service-accounts-eks"
  version = "~> 5.0"

  role_name             = "${var.cluster_name}-ebs-csi-driver"
  attach_ebs_csi_policy = true

  oidc_providers = {
    main = {
      provider_arn               = module.eks.oidc_provider_arn
      namespace_service_accounts = ["kube-system:ebs-csi-controller-sa"]
    }
  }
}
