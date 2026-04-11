# --- Karpenter ---

# Tag the EKS node security group so Karpenter can discover it
resource "aws_ec2_tag" "karpenter_sg" {
  resource_id = module.eks.node_security_group_id
  key         = "karpenter.sh/discovery"
  value       = var.cluster_name
}

# IAM role for nodes that Karpenter launches
resource "aws_iam_role" "karpenter_node" {
  name = local.karpenter_node_role

  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [{
      Effect = "Allow"
      Principal = {
        Service = "ec2.amazonaws.com"
      }
      Action = "sts:AssumeRole"
    }]
  })
}

resource "aws_iam_role_policy_attachment" "karpenter_node_worker" {
  role       = aws_iam_role.karpenter_node.name
  policy_arn = "arn:aws:iam::aws:policy/AmazonEKSWorkerNodePolicy"
}

resource "aws_iam_role_policy_attachment" "karpenter_node_cni" {
  role       = aws_iam_role.karpenter_node.name
  policy_arn = "arn:aws:iam::aws:policy/AmazonEKS_CNI_Policy"
}

resource "aws_iam_role_policy_attachment" "karpenter_node_ecr" {
  role       = aws_iam_role.karpenter_node.name
  policy_arn = "arn:aws:iam::aws:policy/AmazonEC2ContainerRegistryReadOnly"
}

resource "aws_iam_role_policy_attachment" "karpenter_node_ssm" {
  role       = aws_iam_role.karpenter_node.name
  policy_arn = "arn:aws:iam::aws:policy/AmazonSSMManagedInstanceCore"
}

# Instance profile — EC2 instances need this to use the role
resource "aws_iam_instance_profile" "karpenter_node" {
  name = "${local.karpenter_node_role}-profile"
  role = aws_iam_role.karpenter_node.name
}

# EKS access entry so Karpenter-launched nodes can join the cluster
resource "aws_eks_access_entry" "karpenter_node" {
  cluster_name  = module.eks.cluster_name
  principal_arn = aws_iam_role.karpenter_node.arn
  type          = "EC2_LINUX"
}

# SQS queue for spot interruption & rebalance events
# preparing for spot instances
resource "aws_sqs_queue" "karpenter" {
  name                      = "${var.cluster_name}-karpenter"
  message_retention_seconds = 300
  sqs_managed_sse_enabled   = true
}

resource "aws_sqs_queue_policy" "karpenter" {
  queue_url = aws_sqs_queue.karpenter.id

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Effect    = "Allow"
        Principal = { Service = ["events.amazonaws.com", "sqs.amazonaws.com"] }
        Action    = "sqs:SendMessage"
        Resource  = aws_sqs_queue.karpenter.arn
      }
    ]
  })
}

# EventBridge rules → SQS for spot interruptions and rebalance
resource "aws_cloudwatch_event_rule" "karpenter_interruption" {
  name = "${var.cluster_name}-karpenter-interruption"
  event_pattern = jsonencode({
    source      = ["aws.ec2"]
    detail-type = ["EC2 Spot Instance Interruption Warning"]
  })
}

resource "aws_cloudwatch_event_target" "karpenter_interruption" {
  rule      = aws_cloudwatch_event_rule.karpenter_interruption.name
  target_id = "KarpenterInterruptionQueueTarget"
  arn       = aws_sqs_queue.karpenter.arn
}

resource "aws_cloudwatch_event_rule" "karpenter_rebalance" {
  name = "${var.cluster_name}-karpenter-rebalance"
  event_pattern = jsonencode({
    source      = ["aws.ec2"]
    detail-type = ["EC2 Instance Rebalance Recommendation"]
  })
}

resource "aws_cloudwatch_event_target" "karpenter_rebalance" {
  rule      = aws_cloudwatch_event_rule.karpenter_rebalance.name
  target_id = "KarpenterRebalanceQueueTarget"
  arn       = aws_sqs_queue.karpenter.arn
}

resource "aws_cloudwatch_event_rule" "karpenter_state_change" {
  name = "${var.cluster_name}-karpenter-state-change"
  event_pattern = jsonencode({
    source      = ["aws.ec2"]
    detail-type = ["EC2 Instance State-change Notification"]
  })
}

resource "aws_cloudwatch_event_target" "karpenter_state_change" {
  rule      = aws_cloudwatch_event_rule.karpenter_state_change.name
  target_id = "KarpenterStateChangeQueueTarget"
  arn       = aws_sqs_queue.karpenter.arn
}

# IRSA role for the Karpenter controller pod
module "karpenter_irsa" {
  source  = "terraform-aws-modules/iam/aws//modules/iam-role-for-service-accounts-eks"
  version = "~> 5.0"

  role_name = "${var.cluster_name}-karpenter"

  oidc_providers = {
    main = {
      provider_arn               = module.eks.oidc_provider_arn
      namespace_service_accounts = ["${local.karpenter_namespace}:karpenter"]
    }
  }
}

# Controller permissions — what Karpenter needs to manage EC2/pricing/SSM
resource "aws_iam_role_policy" "karpenter_controller" {
  name = "karpenter-controller"
  role = module.karpenter_irsa.iam_role_name

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Sid    = "EC2"
        Effect = "Allow"
        Action = [
          "ec2:CreateLaunchTemplate", "ec2:DeleteLaunchTemplate",
          "ec2:CreateFleet", "ec2:CreateTags",
          "ec2:RunInstances", "ec2:TerminateInstances",
          "ec2:DescribeInstances", "ec2:DescribeInstanceTypes",
          "ec2:DescribeInstanceTypeOfferings",
          "ec2:DescribeAvailabilityZones",
          "ec2:DescribeSubnets", "ec2:DescribeSecurityGroups",
          "ec2:DescribeLaunchTemplates",
          "ec2:DescribeImages", "ec2:DescribeSpotPriceHistory"
        ]
        Resource = "*"
      },
      {
        Sid    = "PassRole"
        Effect = "Allow"
        Action = "iam:PassRole"
        Resource = aws_iam_role.karpenter_node.arn
      },
      {
        Sid    = "SSM"
        Effect = "Allow"
        Action = "ssm:GetParameter"
        Resource = "arn:aws:ssm:${var.region}::parameter/aws/service/*"
      },
      {
        Sid    = "Pricing"
        Effect = "Allow"
        Action = ["pricing:GetProducts"]
        Resource = "*"
      },
      {
        Sid    = "SQS"
        Effect = "Allow"
        Action = [
          "sqs:DeleteMessage",
          "sqs:GetQueueUrl",
          "sqs:ReceiveMessage"
        ]
        Resource = aws_sqs_queue.karpenter.arn
      },
      {
        Sid    = "EKS"
        Effect = "Allow"
        Action = ["eks:DescribeCluster"]
        Resource = module.eks.cluster_arn
      },
      {
        Sid    = "InstanceProfile"
        Effect = "Allow"
        Action = [
          "iam:GetInstanceProfile",
          "iam:CreateInstanceProfile",
          "iam:DeleteInstanceProfile",
          "iam:AddRoleToInstanceProfile",
          "iam:RemoveRoleFromInstanceProfile"
        ]
        Resource = "*"
      }
    ]
  })
}

# Install Karpenter via Helm
resource "helm_release" "karpenter" {
  name       = "karpenter"
  namespace  = local.karpenter_namespace
  repository = "oci://public.ecr.aws/karpenter"
  chart      = "karpenter"
  version    = local.karpenter_version

  create_namespace = true

  values = [yamlencode({
    settings = {
      clusterName       = module.eks.cluster_name
      clusterEndpoint   = module.eks.cluster_endpoint
      interruptionQueue = aws_sqs_queue.karpenter.name
    }

    serviceAccount = {
      annotations = {
        "eks.amazonaws.com/role-arn" = module.karpenter_irsa.iam_role_arn
      }
    }

    # Run on the system managed node group, not on Karpenter-provisioned nodes
    nodeSelector = {
      role = "system"
    }
  })]

  depends_on = [
    module.eks,
    aws_iam_role_policy.karpenter_controller,
    aws_eks_access_entry.karpenter_node
  ]
}
