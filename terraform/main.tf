provider "aws" {
  region = var.region

  default_tags {
    tags = {
      Project     = var.project_name
      Environment = var.environment
      ManagedBy   = "terraform"
      Assignment  = "kubernetes-observability-pipeline"
    }
  }
}

data "aws_caller_identity" "current" {}

data "aws_partition" "current" {}

data "aws_iam_session_context" "current" {
  arn = data.aws_caller_identity.current.arn
}

data "aws_iam_policy_document" "platform_admin_assume_role" {
  statement {
    actions = ["sts:AssumeRole"]

    principals {
      type        = "AWS"
      identifiers = [data.aws_iam_session_context.current.issuer_arn]
    }
  }
}

resource "aws_iam_role" "platform_admin" {
  count = var.cluster_admin_role_name == null ? 0 : 1

  name               = var.cluster_admin_role_name
  assume_role_policy = data.aws_iam_policy_document.platform_admin_assume_role.json

  tags = {
    Purpose = "EKS cluster administration"
  }
}

data "aws_iam_policy_document" "ebs_csi_assume_role" {
  statement {
    actions = [
      "sts:AssumeRole",
      "sts:TagSession"
    ]

    principals {
      type        = "Service"
      identifiers = ["pods.eks.amazonaws.com"]
    }
  }
}

resource "aws_iam_role" "ebs_csi" {
  name               = "${var.cluster_name}-ebs-csi"
  assume_role_policy = data.aws_iam_policy_document.ebs_csi_assume_role.json
}

resource "aws_iam_role_policy_attachment" "ebs_csi" {
  role       = aws_iam_role.ebs_csi.name
  policy_arn = "arn:aws:iam::aws:policy/service-role/AmazonEBSCSIDriverPolicy"
}

module "vpc" {
  source  = "terraform-aws-modules/vpc/aws"
  version = "6.7.0"

  name = "${var.project_name}-vpc"
  cidr = var.vpc_cidr

  azs = ["${var.region}a", "${var.region}b"]

  private_subnets = ["10.20.11.0/24", "10.20.12.0/24"]
  public_subnets  = ["10.20.101.0/24", "10.20.102.0/24"]

  enable_nat_gateway = true
  single_nat_gateway = true

  enable_dns_hostnames = true
  enable_dns_support   = true

  public_subnet_tags = {
    "kubernetes.io/role/elb" = 1
    "kubernetes.io/cluster/${var.cluster_name}" = "shared"
  }

  private_subnet_tags = {
    "kubernetes.io/role/internal-elb" = 1
    "kubernetes.io/cluster/${var.cluster_name}" = "shared"
  }
}

module "eks" {
  source  = "terraform-aws-modules/eks/aws"
  version = "21.25.0"

  name               = var.cluster_name
  kubernetes_version = "1.35"

  endpoint_public_access  = false
  endpoint_private_access = true

  authentication_mode = "API"

  vpc_id     = module.vpc.vpc_id
  subnet_ids = module.vpc.private_subnets

  enable_cluster_creator_admin_permissions = false

  enabled_log_types = [
    "api",
    "audit",
    "authenticator",
    "controllerManager",
    "scheduler"
  ]

  encryption_config = {
    resources = ["secrets"]
  }

  access_entries = merge(
    var.additional_access_entries,
    var.cluster_admin_role_name == null ? {} : {
      platform_admin = {
        principal_arn = aws_iam_role.platform_admin[0].arn
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
  )

  eks_managed_node_groups = {
    observability = {
      name           = "observability"
      min_size       = var.node_min_size
      max_size       = var.node_max_size
      desired_size   = var.node_desired_size
      capacity_type  = "ON_DEMAND"
      disk_size      = 50
      instance_types = var.node_instance_types

      labels = {
        workload = "observability"
      }

      tags = {
        Workload = "vector-observability"
      }
    }
  }

  addons = {
    eks-pod-identity-agent = {
      before_compute = true
      most_recent    = true
    }
    coredns = {
      most_recent = true
      timeouts = {
        create = "60m"
      }
    }
    kube-proxy = {
      most_recent = true
    }
    vpc-cni = {
      before_compute = true
      most_recent    = true
    }
    aws-ebs-csi-driver = {
      most_recent = true
      pod_identity_association = [{
        role_arn        = aws_iam_role.ebs_csi.arn
        service_account = "ebs-csi-controller-sa"
      }]
      timeouts = {
        create = "60m"
      }
    }
  }
}
