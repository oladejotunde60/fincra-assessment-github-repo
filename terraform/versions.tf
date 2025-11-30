terraform {
  required_version = ">= 1.5.0"

  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = "~> 5.0"
    }
    kubernetes = {
      source  = "hashicorp/kubernetes"
      version = "~> 2.23"
    }
    helm = {
      source  = "hashicorp/helm"
      version = "~> 2.11"
    }
  }

  backend "s3" {
      bucket         = "fincra-terraform-state-837644358342"
      key            = "eks-flask-app/terraform.tfstate"
      region         = "eu-west-1"
      dynamodb_table = "fincra-terraform-state-lock"
      encrypt        = true
}
}
