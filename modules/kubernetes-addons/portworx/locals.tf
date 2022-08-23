locals {
  name                 = "portworx"
  namespace            = "kube-system"
  service_account_name = "${local.name}-sa"

  set_values = try(length(var.aws_access_key_id) > 0, false) ? concat([
      {
        name  = "envVars"
        value = "AWS_ACCESS_KEY_ID=${var.aws_access_key_id};AWS_SECRET_ACCESS_KEY=${var.aws_secret_access_key}"
      }
    ],var.set_values): var.set_values

  set_sensitive_values = var.set_sensitive_values

  default_helm_config = {
    name                       = local.name
    description                = "A Helm chart for portworx"
    chart                      = "portworx"
    repository                 = "https://raw.githubusercontent.com/portworx/helm/eks-blueprint/repo/staging"
    version                    = "2.11.0"
    namespace                  = local.namespace
    values                     = local.default_helm_values
    set_values                 = []
    set_sensitive_values       = null
  }

  helm_config = merge(
    local.default_helm_config,
    var.helm_config
  )

  irsa_config = {
    create_kubernetes_namespace = false
    kubernetes_namespace        = local.namespace
    create_kubernetes_service_account = true  
    kubernetes_service_account        = "${local.service_account_name}"
    irsa_iam_policies = concat([aws_iam_policy.portworx_blueprint_metering.arn], var.irsa_policies)
  }

  argocd_gitops_config = {
    enable             = false
    serviceAccountName = local.service_account_name
  }

   default_helm_values = [templatefile("${path.module}/values.yaml", merge({
        imageVersion                = "2.11.0"
        clusterName                 = "mycluster"      
        drives                      = "type=gp2,size=200"  
        useInternalKVDB             = true
        kvdbDevice                  = "type=gp2,size=150"
        envVars                     = ""
        maxStorageNodesPerZone      = 3 
        useOpenshiftInstall         = false
        etcdEndPoint                = ""
        dataInterface               = ""
        managementInterface         = ""
        useStork                    = true
        storkVersion                = "2.11.0"
        customRegistryURL           = ""
        registrySecret              = ""
        licenseSecret               = ""
        monitoring                  = false
        enableCSI                   = false
        enableAutopilot             = false
        KVDBauthSecretName          = ""
        eksServiceAccount           = "${local.service_account_name}"
        useAWSMarketplace           = false
    },var.chart_values)
  )]
}



resource "aws_iam_policy" "portworx_blueprint_metering" {
  name = "portworx_blueprint_metering"

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
          Action = [
            "aws-marketplace:MeterUsage",
            "aws-marketplace:RegisterUsage"
          ],
          Effect = "Allow",
          Resource = "*"
      },
    ]
  })
}
