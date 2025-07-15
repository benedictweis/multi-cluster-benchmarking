terraform {
  required_providers {
    aws = {
      source = "hashicorp/aws"
      version = "6.2.0"
    }
  }
}

variable aws_region {
  description = "The AWS region to deploy resources in"
  type        = string
}

variable "aws_access_key" {
  description = "AWS access key"
  type        = string
  sensitive   = true
  
}

variable "aws_secret_key" {
  description = "AWS secret key"
  type        = string
  sensitive   = true

}


provider "aws" {
  region     = var.aws_region
  access_key = var.aws_access_key
  secret_key = var.aws_secret_key
}
