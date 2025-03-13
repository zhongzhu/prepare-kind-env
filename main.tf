terraform {
  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = "~> 4.16"
    }
  }

  required_version = ">= 1.2.0"
}

provider "aws" {
  region  = "ap-southeast-2"
}

data "aws_availability_zone" "example" {
  name = "ap-southeast-2a"
}

data "aws_subnet" "example" {
  filter {
    name   = "tag:Name"
    values = ["subnet-private1-ap-southeast-2a"]
  }
}

resource "aws_security_group" "example" {
  name        = "my-securigy-group"
  description = "Allow SSH access from specific IPv4 address"
  vpc_id      = "vpc-xxxxxxxxxxxxxxxx"

  ingress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["10.190.0.0/16"]
  }

  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }
}

resource "aws_instance" "example" {
  ami           = "ami-xxxxxxxxxxx"
  instance_type = "c5.4xlarge"
  subnet_id = data.aws_subnet.example.id
  vpc_security_group_ids = [aws_security_group.example.id]
  key_name = "my-aws-key-pair"
  # associate_public_ip_address = true

  ebs_block_device {
    device_name = "/dev/sda1"
    volume_size = 50
    volume_type = "gp3"
  }

  tags = {
    Name = "my-linux-1"
  }

  user_data = <<-EOF
    #!/bin/bash
    set -eux

    sudo apt update -y && sudo apt upgrade -y
    sudo apt install -y docker.io
    sudo systemctl start docker
    sudo systemctl enable docker

    sudo usermod -aG docker ubuntu

    # 安装KinD v0.27.0
    curl -Lo ./kind https://kind.sigs.k8s.io/dl/v0.27.0/kind-linux-amd64
    chmod +x ./kind
    sudo mv ./kind /usr/local/bin/
    sudo chown ubuntu:ubuntu /usr/local/bin/kind

    # Install kubectl
    curl -LO "https://dl.k8s.io/release/$(curl -L -s https://dl.k8s.io/release/stable.txt)/bin/linux/amd64/kubectl"
    chmod +x kubectl
    sudo mv kubectl /usr/local/bin/
    sudo chown ubuntu:ubuntu /usr/local/bin/kubectl

    # Configure Kubernetes cluster
    cat <<EOT > kind-config.yaml
    kind: Cluster
    apiVersion: kind.x-k8s.io/v1alpha4
    nodes:
      - role: control-plane
      - role: worker
      - role: worker
      - role: worker
    EOT

    # Create the Kind cluster
    kind create cluster --config=kind-config.yaml    
  EOF
}
