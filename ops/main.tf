provider "aws" {
  region              = "us-east-1"
  allowed_account_ids = ["919759177803"]
}

terraform {
  # https://github.com/hashicorp/terraform/releases
  required_version = ">= 1.14.6, < 2.0.0"
  required_providers {
    aws = {
      # https://github.com/hashicorp/terraform-provider-aws/releases
      version = "< 7.0"
    }
  }
  backend "s3" {
    bucket = "codabool-tf"
    key    = "claw.tfstate"
    region = "us-east-1"
  }
}

module "ec2" {
  source        = "github.com/CodaBool/AWS/modules/ec2"
  name          = "claw" # will use "name*" for ami filtering
  subnet        = "subnet-02bd6f23bd2e48675"
  ssh_ip        = var.ssh_ip
  ip            = ""
}

variable "ssh_ip" {
  type = string
  default = ""
}

output "private_dns" {
  value = module.ec2.instance.private_dns
}

output "id" {
  value = module.ec2.instance.id
}