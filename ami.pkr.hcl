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
    source      = "./ami/"
    destination = "/tmp/"
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

      # moving files and setting permissions
      "sudo mkdir -p /srv/openclaw /srv/openclaw/config",
      "sudo cp -a /tmp/. /srv/openclaw/",
      "sudo mkdir -p /usr/local/lib/docker/cli-plugins",
      "sudo mv /srv/openclaw/docker-compose /usr/local/lib/docker/cli-plugins/docker-compose",
      "sudo chmod 755 /usr/local/lib/docker/cli-plugins/docker-compose",
      "sudo chmod 700 /srv/openclaw",
      "sudo chmod 600 /srv/openclaw/.env",
      "sudo chmod 644 /srv/openclaw/docker-compose.yml",
      "sudo chmod 644 /srv/openclaw/init.mjs",
      "sudo chmod 600 /srv/openclaw/openclaw.json.tmpl",
      "sudo chown -R ec2-user:ec2-user /srv/openclaw",

      # automatic updates
      "sudo systemctl enable --now dnf-automatic.timer",

      # automatic startup
      "sudo tee /etc/systemd/system/openclaw.service >/dev/null <<'EOF'",
      "[Unit]",
      "Description=OpenClaw Docker Compose",
      "Requires=docker.service",
      "After=docker.service network-online.target",
      "Wants=network-online.target",
      "",
      "[Service]",
      "Type=oneshot",
      "WorkingDirectory=/srv/openclaw",
      "ExecStart=/usr/bin/docker compose up -d",
      "ExecStop=/usr/bin/docker compose down",
      "RemainAfterExit=yes",
      "TimeoutStartSec=0",
      "",
      "[Install]",
      "WantedBy=multi-user.target",
      "EOF",
      "sudo systemctl daemon-reload",
      "sudo systemctl enable openclaw.service",
    ]
  }
}
