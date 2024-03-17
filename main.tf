locals {
  name = "softether"
  cidr = "10.0.0.0/24"
  azs  = slice(data.aws_availability_zones.available.names, 0, 1)

  user_data = <<-EOF
    #!/bin/bash
    yum -y update
    yum -y groupinstall "Development Tools"
    yum -y install \
      readline-devel \
      ncurses-devel \
      openssl-devel \
      curl
    mkdir -p /opt/softether
    curl -o /opt/softether/softether-vpnserver.tar.gz https://jp.softether-download.com/files/softether/v4.42-9798-rtm-2023.06.30-tree/Linux/SoftEther_VPN_Server/64bit_-_Intel_x64_or_AMD64/softether-vpnserver-v4.42-9798-rtm-2023.06.30-linux-x64-64bit.tar.gz
    tar zxvf /opt/softether/softether-vpnserver.tar.gz -C /opt/softether
  EOF

  tags = {
    Terraform  = "true"
    Repository = "https://github.com/CASL0/softether-ec2.git"
  }
}

data "aws_availability_zones" "available" {}

module "vpc" {
  source  = "terraform-aws-modules/vpc/aws"
  version = "~> 5.0"

  name = local.name
  cidr = local.cidr

  azs            = local.azs
  public_subnets = [for k, v in local.azs : cidrsubnet(local.cidr, 4, k)]

  tags = local.tags
}

module "security_group" {
  source  = "terraform-aws-modules/security-group/aws"
  version = "~> 5.0"

  name        = "security-group"
  description = "Security group that allows SSH, IPSec access"
  vpc_id      = module.vpc.vpc_id

  ingress_cidr_blocks = ["0.0.0.0/0"]
  ingress_rules       = ["ssh-tcp"]

  ingress_with_cidr_blocks = [
    {
      from_port   = 500
      to_port     = 500
      protocol    = "udp"
      description = "Internet Key Exchange (IKE)"
      cidr_blocks = "0.0.0.0/0"
    },
    {
      from_port   = 4500
      to_port     = 4500
      protocol    = "udp"
      description = "NAT traversal"
      cidr_blocks = "0.0.0.0/0"
    }
  ]

  egress_rules = ["all-all"]

  tags = local.tags
}

data "aws_ami" "amazon_linux" {
  most_recent = true

  filter {
    name   = "name"
    values = ["amzn2-ami-hvm-*-x86_64-gp2"]
  }

  filter {
    name   = "virtualization-type"
    values = ["hvm"]
  }

  owners = ["amazon"]
}

module "ec2" {
  source  = "terraform-aws-modules/ec2-instance/aws"
  version = "~> 5.0"

  name          = local.name
  ami           = data.aws_ami.amazon_linux.id
  instance_type = "t2.micro"
  key_name      = "ec2-key"

  availability_zone = element(module.vpc.azs, 0)
  subnet_id         = element(module.vpc.public_subnets, 0)
  vpc_security_group_ids = [
    module.security_group.security_group_id
  ]
  associate_public_ip_address = true

  user_data_base64            = base64encode(local.user_data)
  user_data_replace_on_change = true

  tags = local.tags
}
