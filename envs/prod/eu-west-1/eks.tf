module "eks" {
  source  = "terraform-aws-modules/eks/aws"
  version = "~> 21.0"

  name               = var.cluster_name
  kubernetes_version = "1.35"

  vpc_id     = module.vpc.vpc_id
  subnet_ids = module.vpc.private_subnets

  # Control plane logging
  enabled_log_types = ["api", "audit", "authenticator", "controllerManager", "scheduler"]

  # Access
  endpoint_public_access       = true
  # TODO: When not actively working, restrict via Console to block public access.
  # Long-term: private endpoint + VPN/bastion.
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

  # EKS managed add-ons
  addons = {
    coredns                = { most_recent = true }
    kube-proxy             = { most_recent = true }
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

  # Static system node group
  eks_managed_node_groups = {
    system = {
      instance_types = ["t3.medium"]
      min_size       = 3
      max_size       = 4
      desired_size   = 3

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
