terraform {
  required_version = ">= 0.12"
  required_providers {
    aws = {
      source = "hashicorp/aws"
      # Minimum version to handle Lambda deployment into VPC
      # https://github.com/hashicorp/terraform-provider-aws/issues/10329
      version = ">= 2.31.0"
    }
  }
}

provider "aws" {
  region  = var.region
  profile = var.profile_name
  default_tags {
    tags = var.default_tag
  }
}
