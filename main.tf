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
  name      = "claw" # will use "name*" for ami filtering, keyname
  subnet    = "subnet-02bd6f23bd2e48675"
  ip        = "2600:1f18:1248:e300:f523:4a18:df36:eca1"
  ssh_ipv6  = ["2600:1700:8c00:591f::2b8/128", "2600:1700:8c00:591f::2c0/128"]
  log_group = "/aws/ec2/claw/openclaw"
}


resource "aws_instance" "main" {
  ami                    = data.aws_ami.image.id
  instance_type          = "t4g.small"
  subnet_id              = local.subnet # ipv6
  key_name               = local.name
  # too many things break without the ipv4
  associate_public_ip_address = true
  vpc_security_group_ids = [aws_security_group.main.id]
  ipv6_addresses         = [local.ip]
  # for initial assignment
  # ipv6_address_count   = 1
  iam_instance_profile = local.name
  root_block_device {
    volume_type = "gp3"
    volume_size = 12 # base image uses ~2Gb
  }
  #   if you increase the size you can grow the partition:
  # sudo growpart /dev/nvme0n1 1
  # sudo xfs_growfs -d /

  # force IMDSv2
  metadata_options {
    http_tokens = "required"
  }
  tags = {
    Name = local.name
  }
}


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
    from_port        = 22
    to_port          = 22
    protocol         = "tcp"
    ipv6_cidr_blocks = local.ssh_ipv6
  }
  egress {
    from_port        = 0
    to_port          = 0
    protocol         = "-1"
    ipv6_cidr_blocks = ["::/0"]
  }
  egress {
    from_port        = 0
    to_port          = 0
    protocol         = "-1"
    cidr_blocks = ["0.0.0.0/0"]
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
resource "aws_cloudwatch_log_group" "main" {
  name              = local.log_group
  retention_in_days = 30
  tags = {
    Name = local.name
  }
}

resource "aws_iam_instance_profile" "ec2_profile" {
  name = local.name
  role = aws_iam_role.cw_assume.name
}

resource "aws_iam_policy" "docker_awslogs" {
  name_prefix = "${local.name}-"
  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Effect = "Allow"
        Action = [
          "logs:CreateLogStream",
          "logs:PutLogEvents",
          "logs:DescribeLogStreams"
        ]
        Resource = [
          aws_cloudwatch_log_group.main.arn,
          "${aws_cloudwatch_log_group.main.arn}:*"
        ]
      }
    ]
  })
}

resource "aws_iam_role_policy_attachment" "docker_awslogs" {
  role       = aws_iam_role.cw_assume.name
  policy_arn = aws_iam_policy.docker_awslogs.arn
}

output "private_dns" {
  value = aws_instance.main.private_dns
}

output "id" {
  value = aws_instance.main.id
}

output "log_group_name" {
  value = aws_cloudwatch_log_group.main.name
}

output "ipv6" {
  value = aws_instance.main.ipv6_addresses[0]
}
