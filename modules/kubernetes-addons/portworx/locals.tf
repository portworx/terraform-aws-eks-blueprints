resource "random_string" "id" {
  length  = 4
  special = false
  upper   = false
}

locals {
  name = "portworx"

  custom_namespace = try(var.helm_config["set"][index(var.helm_config.set.*.name, "namespace")], null)
  namespace        = local.custom_namespace != null ? local.custom_namespace["value"] : "kube-system"

  create_namespace_flag = try(var.helm_config["set"][index(var.helm_config.set.*.name, "createNamespace")], null)
  create_namespace      = local.create_namespace_flag != null ? local.create_namespace_flag["value"] : false

  service_account_name = "${local.name}-sa"

  aws_marketplace_config = try(var.helm_config["set"][index(var.helm_config.set.*.name, "aws.marketplace")], null)
  use_aws_marketplace    = local.aws_marketplace_config != null ? local.aws_marketplace_config["value"] : false

  default_helm_config = {
    name        = local.name
    description = "A Helm chart for portworx"
    chart       = "portworx"
    repository  = "https://raw.githubusercontent.com/portworx/eks-blueprint-helm/main/repo/stable"
    version     = "3.0.0"
    namespace   = local.namespace
    values      = local.default_helm_values
  }

  helm_config = merge(
    local.default_helm_config,
    var.helm_config
  )

  irsa_iam_policies_list = local.use_aws_marketplace != false ? [aws_iam_policy.portworx_eksblueprint_metering[0].arn] : []

  irsa_config = {
    create_kubernetes_namespace         = local.create_namespace
    kubernetes_namespace                = local.namespace
    create_kubernetes_service_account   = true
    create_service_account_secret_token = true
    kubernetes_service_account          = "${local.service_account_name}"
    irsa_iam_policies                   = local.irsa_iam_policies_list
  }

  default_helm_values = [templatefile("${path.module}/values.yaml", {
    imageVersion           = "3.0.0"
    clusterName            = local.name
    drives                 = "type=gp3+size=200"
    useInternalKVDB        = true
    kvdbDevice             = "type=gp3,size=64"
    pxOperatorImageVersion = "23.5.1"
    envVars                = ""
    maxStorageNodesPerZone = 3
    useOpenshiftInstall    = false
    etcdEndPoint           = ""
    dataInterface          = ""
    managementInterface    = ""
    useStork               = true
    storkVersion           = "23.6.0"
    customRegistryURL      = ""
    registrySecret         = ""
    licenseSecret          = ""
    monitoring             = false
    enableCSI              = true
    enableAutopilot        = false
    KVDBauthSecretName     = ""
    eksServiceAccount      = "${local.service_account_name}"
    awsAccessKeyId         = ""
    awsSecretAccessKey     = ""
    deleteType             = "Uninstall"
    awsProduct             = "PX-ENTERPRISE"
    namespace              = "kube-system"
    createNamespace        = false
    }
  )]
}

resource "aws_iam_policy" "portworx_eksblueprint_metering" {
  count = try(local.use_aws_marketplace, false) ? 1 : 0
  name  = "portworx_eksblueprint_metering-${random_string.id.result}"

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Action = [
          "aws-marketplace:MeterUsage",
          "aws-marketplace:RegisterUsage"
        ],
        Effect   = "Allow",
        Resource = "*"
      },
    ]
  })
}
