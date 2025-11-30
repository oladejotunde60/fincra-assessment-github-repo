provider "aws" {
  region = var.aws_region

  default_tags {
    tags = {
      Project     = "Flask-EKS-App"
      ManagedBy   = "Terraform"
      Environment = var.environment
    }
  }
}

provider "kubernetes" {
  host                   = try(aws_eks_cluster.main.endpoint, "")
  cluster_ca_certificate = try(base64decode(aws_eks_cluster.main.certificate_authority[0].data), "")
  token                  = try(data.aws_eks_cluster_auth.main.token, "")
}

provider "helm" {
  kubernetes {
    host                   = try(aws_eks_cluster.main.endpoint, "")
    cluster_ca_certificate = try(base64decode(aws_eks_cluster.main.certificate_authority[0].data), "")
    token                  = try(data.aws_eks_cluster_auth.main.token, "")
  }
}

data "aws_eks_cluster_auth" "main" {
  name = try(aws_eks_cluster.main.name, "")
}

data "aws_caller_identity" "current" {}
data "aws_availability_zones" "available" {
  state = "available"
}
