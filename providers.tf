terraform {
  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = ">= 4.37.0"
    }
  }
  required_version = ">= 3.33.0"
}

provider "aws" {
  region  = "us-east-1"
}