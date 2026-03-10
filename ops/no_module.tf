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

locals {
  name   = "claw" # will use "name*" for ami filtering
  subnet = "subnet-02bd6f23bd2e48675"
  ssh_ip = var.ssh_ip
  ip     = "how would i know this before deploying?"
}


resource "aws_instance" "main" {
  ami                    = data.aws_ami.image.id
  instance_type          = var.instance_type
  subnet_id              = local.subnet # ipv6
  key_name               = var.key_name
  vpc_security_group_ids = [aws_security_group.main.id]
  # ipv6_addresses         = [var.ip]
  # for initial assignment
  ipv6_address_count   = 1
  iam_instance_profile = local.name
  tags = {
    Name = local.name
  }
}

# max price to request, use aws ec2 describe-spot-price-history
# data "external" "lowest_price" {
#   program = ["bash", "${path.module}/price.sh", var.instance_type]
# }

data "aws_ami" "image" {
  most_recent = true
  owners      = ["self"]
  filter {
    name   = "tag:Name"
    values = ["${local.name}*"]
  }
}

data "aws_vpc" "default" {
  default = true
}

resource "aws_security_group" "main" {
  name   = local.name
  vpc_id = data.aws_vpc.default.id
  ingress {
    from_port   = 22
    to_port     = 22
    protocol    = "tcp"
    cidr_blocks = ["107.200.81.38/32"]
    # ipv6_cidr_blocks = [var.ssh_ip] # must be ipv6 ending in /128
  }
  ingress {
    from_port        = 80
    to_port          = 80
    protocol         = "tcp"
    ipv6_cidr_blocks = ["::/0"]
  }
  egress {
    from_port        = 0
    to_port          = 0
    protocol         = "-1"
    ipv6_cidr_blocks = ["::/0"]
  }
  tags = {
    Name = local.name
  }
}


resource "aws_iam_role" "cw_assume" {
  name = local.name
  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [{
      Action = "sts:AssumeRole"
      Effect = "Allow"
      Principal = {
        Service = "ec2.amazonaws.com"
      }
    }]
  })
}

# Cloudwatch resources
resource "aws_iam_instance_profile" "ec2_profile" {
  name = local.name
  role = aws_iam_role.cw_assume.name
}

resource "aws_iam_role_policy_attachment" "ssm" {
  role       = aws_iam_role.cw_assume.name
  policy_arn = "arn:aws:iam::aws:policy/AmazonSSMManagedInstanceCore"
}

resource "aws_iam_role_policy_attachment" "logs" {
  role       = aws_iam_role.cw_assume.name
  policy_arn = "arn:aws:iam::aws:policy/CloudWatchAgentServerPolicy"
}

resource "aws_iam_role_policy_attachment" "retention" {
  role       = aws_iam_role.cw_assume.name
  policy_arn = aws_iam_policy.retention.arn
}

# could rm ssm, ssm-agent requires ipv4
resource "aws_iam_policy" "retention" {
  name_prefix = "change_retention"
  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [{
      Action   = "logs:PutRetentionPolicy"
      Effect   = "Allow"
      Resource = "*"
      },
      {
        Action   = "ssm:*"
        Effect   = "Allow"
        Resource = "*"
    }]
  })
}

variable "ssh_ip" {
  type    = string
  default = ""
}

output "private_dns" {
  value = aws_instance.main.private_dns
}

output "id" {
  value = aws_instance.main.id
}
