packer {
  required_plugins {
    amazon = {
      version = ">= 1.8.0"
      source  = "github.com/hashicorp/amazon"
    }
  }
}

variable "unique_ami_name" {
  type = string
}

# uses an api call similar to this:
# aws ec2 describe-images --owners amazon --filters "Name=architecture,Values=arm64" "Name=name,Values=al2*" --query "Images | sort_by(@, &CreationDate) | [].[ImageId, Name]" | jq '.[]'
source "amazon-ebs" "al2023" {
  ami_name      = var.unique_ami_name
  instance_type = "t4g.nano"
  region        = "us-east-1"
  force_deregister = true
  force_delete_snapshot = true
  source_ami_filter {
    filters = {
      name                = "al2023-ami-minimal*"
      architecture        = "arm64"
    }
    most_recent = true
    owners      = ["amazon"]
  }
  ssh_username = "ec2-user"
  tags = {
    Name = var.unique_ami_name
  }
}

build {
  name = "init"
  sources = [
    "source.amazon-ebs.al2023"
  ]
  // provisioner "file" {
  //   source = "../.env"
  //   destination = "/home/ec2-user/.env"
  // }
  provisioner "shell" {
    // environment_vars = [
    //   "FOO=hello world",
    // ]
    inline = [
      "sudo dnf update -y",
      "sudo dnf install -y docker git amazon-cloudwatch-agent openssh-server",

      "sudo systemctl enable docker",
      "sudo systemctl start docker",
      "sudo usermod -aG docker ec2-user",

      "sudo systemctl enable sshd",
      "sudo systemctl start sshd",
    ]
  }
}
