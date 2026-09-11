variable "project_name" {
  type        = string
  description = "Project prefix used for AWS resources."
  default     = "oo-observability"
}

variable "environment" {
  type        = string
  description = "Deployment environment."
  default     = "lab"
}

variable "region" {
  type        = string
  description = "AWS region."
  default     = "ap-south-1"
}

variable "cluster_name" {
  type        = string
  description = "EKS cluster name."
  default     = "oo-observability-eks"
}

variable "cluster_admin_role_name" {
  type        = string
  description = "IAM role name granted AmazonEKSClusterAdminPolicy through an EKS access entry."
  default     = null
}

variable "vpc_cidr" {
  type        = string
  description = "VPC CIDR."
  default     = "10.20.0.0/16"
}

variable "node_instance_types" {
  type        = list(string)
  description = "EC2 instance types used by the EKS managed node group."
  default     = ["m7i-flex.large"]

  validation {
    condition     = length(var.node_instance_types) > 0
    error_message = "At least one node instance type must be provided."
  }
}

variable "node_min_size" {
  type        = number
  description = "Minimum managed node count."
  default     = 2
}

variable "node_desired_size" {
  type        = number
  description = "Desired managed node count."
  default     = 2
}

variable "node_max_size" {
  type        = number
  description = "Maximum managed node count."
  default     = 4
}

variable "additional_access_entries" {
  type = map(object({
    principal_arn     = string
    kubernetes_groups = optional(list(string), [])
    policy_associations = optional(map(object({
      policy_arn = string
      access_scope = object({
        namespaces = optional(list(string), [])
        type       = string
      })
    })), {})
  }))
  description = "Optional additional EKS access entries."
  default     = {}
}
