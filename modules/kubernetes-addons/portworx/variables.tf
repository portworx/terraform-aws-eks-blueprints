variable "helm_config" {
  description = "Helm chart config. Repository and version required. See https://registry.terraform.io/providers/hashicorp/helm/latest/docs"
  type        = any
  default     = {}
}

variable "chart_values" {
  description = "custom values for the chart"
  type        = any
  default     = {}
}

variable "set_values" {
  description = "Forced set values"
  type        = any
  default     = []
}

variable "set_sensitive_values" {
  description = "Forced set_sensitive values"
  type        = any
  default     = []
}

variable "aws_access_key_id" {
  description = "aws access key id value"
  type        = string
  default     = ""
}

variable "aws_secret_access_key" {
  description = "aws secret access key value"
  type        = string
  default     = ""
}

variable "manage_via_gitops" {
  description = "Determines if the add-on should be managed via GitOps"
  type        = bool
  default     = false
}

variable "irsa_policies" {
  description = "Additional IAM policy ARNs for Portworx IRSA"
  type        = list(string)
  default     = []
}

variable "irsa_config" {
  description = "Input configuration for IRSA module"
  type = object({
    kubernetes_namespace              = string
    create_kubernetes_namespace       = optional(bool)
    kubernetes_service_account        = string
    create_kubernetes_service_account = optional(bool)
    irsa_iam_policies                 = optional(list(string))
  })
  default = null
}

variable "addon_context" {
  description = "Input configuration for the addon"
  type = object({
    aws_caller_identity_account_id = string
    aws_caller_identity_arn        = string
    aws_eks_cluster_endpoint       = string
    aws_partition_id               = string
    aws_region_name                = string
    eks_cluster_id                 = string
    eks_oidc_issuer_url            = string
    eks_oidc_provider_arn          = string
    tags                           = map(string)
    irsa_iam_role_path             = optional(string)
    irsa_iam_permissions_boundary  = optional(string)
  })
}
