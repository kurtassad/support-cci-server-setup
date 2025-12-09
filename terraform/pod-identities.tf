module "aws_ebs_csi_pod_identity" {
  source  = "terraform-aws-modules/eks-pod-identity/aws"
  version = "2.4.1"

  name = "${module.eks.cluster_name}-aws-ebs-csi"

  attach_aws_ebs_csi_policy = true
  aws_ebs_csi_kms_arns      = [module.eks.kms_key_arn]

  associations = {
    addon = {
      cluster_name    = module.eks.cluster_name
      namespace       = "kube-system"
      service_account = "ebs-csi-controller-sa"
    }
  }

  tags = local.cost_center_tags
}

module "external_dns_pod_identity" {
  source  = "terraform-aws-modules/eks-pod-identity/aws"
  version = "2.4.1"

  name = "${module.eks.cluster_name}-external-dns"

  attach_external_dns_policy    = true
  external_dns_hosted_zone_arns = local.hosted_zones

  associations = {
    this = {
      cluster_name    = module.eks.cluster_name
      namespace       = "external-dns"
      service_account = "external-dns-sa"
    }
  }

  tags = local.cost_center_tags
}

module "cert_manager_pod_identity" {
  source  = "terraform-aws-modules/eks-pod-identity/aws"
  version = "2.4.1"

  name = "${module.eks.cluster_name}-cert-manager"

  attach_cert_manager_policy    = true
  cert_manager_hosted_zone_arns = local.hosted_zones

  associations = {
    this = {
      cluster_name    = module.eks.cluster_name
      namespace       = "cert-manager"
      service_account = "cert-manager"
    }
  }

  tags = local.cost_center_tags
}
