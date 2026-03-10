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
  instance_type = "t4g.small"
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
  provisioner "file" {
    source      = "./.env"
    destination = "/tmp/.env"
  }
  provisioner "file" {
    source      = "../docker-compose.yml"
    destination = "/tmp/docker-compose.yml"
  }
  provisioner "file" {
    source      = "./docker-compose"
    destination = "/tmp/docker-compose"
  }
  provisioner "shell" {
    inline = [
      // install dependencies
      "sudo dnf update -y",
      "sudo dnf install -y docker git openssh-server dnf-automatic",

      // docker setup
      "sudo systemctl enable docker",
      "sudo systemctl start docker",
      "sudo usermod -aG docker ec2-user",

      // optionally start ssh
      "sudo systemctl enable sshd",
      "sudo systemctl start sshd",

      // setup volumes
      "sudo mkdir -p /srv/openclaw/state /srv/openclaw/workspace",
      "sudo chown -R ec2-user:ec2-user /srv/openclaw",
      "sudo chmod 700 /srv/openclaw",
      "sudo chmod 700 /srv/openclaw/state /srv/openclaw/workspace",

      // mv .env
      "sudo mv /tmp/.env /srv/openclaw/.env",
      "sudo chown ec2-user:ec2-user /srv/openclaw/.env",
      "sudo chmod 600 /srv/openclaw/.env",

      // mv docker-compose.yml
      "sudo mv /tmp/docker-compose.yml /srv/openclaw/docker-compose.yml",
      "sudo chown ec2-user:ec2-user /srv/openclaw/docker-compose.yml",
      "sudo chmod 644 /srv/openclaw/docker-compose.yml",

      // install compose
      // get latest version num from:
      "sudo mkdir -p /usr/local/lib/docker/cli-plugins",
      "sudo mv /tmp/docker-compose /usr/local/lib/docker/cli-plugins/docker-compose",
      "sudo chmod 755 /usr/local/lib/docker/cli-plugins/docker-compose",

      "sudo systemctl enable --now dnf-automatic.timer",
    ]
  }
}
