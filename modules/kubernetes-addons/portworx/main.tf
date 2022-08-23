module "helm_addon"{
  source = "../helm-addon"
  manage_via_gitops = var.manage_via_gitops
  addon_context        = var.addon_context

  set_values           = local.set_values
  set_sensitive_values = local.set_sensitive_values
  helm_config          = local.helm_config
  irsa_config          = local.irsa_config
}
