output "region" {
  value = var.region
}

output "cluster_name" {
  value = module.eks.cluster_name
}

output "cluster_endpoint" {
  value = module.eks.cluster_endpoint
}

output "cluster_oidc_issuer_url" {
  value = module.eks.cluster_oidc_issuer_url
}

output "platform_admin_role_arn" {
  value = try(aws_iam_role.platform_admin[0].arn, null)
}

output "vpc_id" {
  value = module.vpc.vpc_id
}
