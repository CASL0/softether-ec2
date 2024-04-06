locals {
  name = "softether"
  cidr = "10.0.0.0/24"
  azs  = slice(data.aws_availability_zones.available.names, 0, 1)

  dnsmasq_conf = file("${path.module}/files/etc/dnsmasq.conf")

  vpnserver_user_data = <<-EOF
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

  vpnclient_user_data = <<-EOF
    #!/bin/bash
    yum -y update
    yum -y groupinstall "Development Tools"
    yum -y install \
      readline-devel \
      ncurses-devel \
      openssl-devel \
      curl
    mkdir -p /opt/softether
    curl -o /opt/softether/softether-vpnclient.tar.gz https://jp.softether-download.com/files/softether/v4.42-9798-rtm-2023.06.30-tree/Linux/SoftEther_VPN_Client/64bit_-_Intel_x64_or_AMD64/softether-vpnclient-v4.42-9798-rtm-2023.06.30-linux-x64-64bit.tar.gz
    tar zxvf /opt/softether/softether-vpnclient.tar.gz -C /opt/softether
  EOF

  squid_user_data = <<-EOF
    #!/bin/bash
    yum -y update && yum -y install squid
    systemctl enable squid
    systemctl start squid
  EOF

  dnsmasq_user_data = <<-EOF
    #!/bin/bash
    yum -y update && yum -y install dnsmasq
    echo "nameserver 8.8.8.8" > /etc/resolv.conf 
    echo "${local.dnsmasq_conf}" > /etc/dnsmasq.conf
    systemctl enable dnsmasq
    systemctl start dnsmasq
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

  azs             = local.azs
  public_subnets  = [for k, v in local.azs : cidrsubnet(local.cidr, 4, k)]
  private_subnets = [for k, v in local.azs : cidrsubnet(local.cidr, 4, k + 8)]

  enable_nat_gateway = true
  single_nat_gateway = true

  tags = local.tags
}

module "ssh_security_group" {
  source  = "terraform-aws-modules/security-group/aws"
  version = "~> 5.0"

  name        = "security-group for ssh"
  description = "Security group that allows SSH access"
  vpc_id      = module.vpc.vpc_id

  ingress_cidr_blocks = ["0.0.0.0/0"]
  ingress_rules       = ["ssh-tcp"]

  tags = local.tags
}

module "vpn_security_group" {
  source  = "terraform-aws-modules/security-group/aws"
  version = "~> 5.0"

  name        = "security-group for vpn"
  description = "Security group that allows VPN access"
  vpc_id      = module.vpc.vpc_id

  ingress_cidr_blocks = ["0.0.0.0/0"]

  # IPsec と Ethernet over HTTPS を許可
  ingress_rules = ["ipsec-500-udp", "ipsec-4500-udp", "https-443-tcp"]

  tags = local.tags
}

module "outbound_security_group" {
  source  = "terraform-aws-modules/security-group/aws"
  version = "~> 5.0"

  name        = "security-group for outbound"
  description = "Security group that allows all outbound accesses"
  vpc_id      = module.vpc.vpc_id

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

module "vpn_ec2" {
  source  = "terraform-aws-modules/ec2-instance/aws"
  version = "~> 5.0"

  name          = "${local.name}_vpn"
  ami           = data.aws_ami.amazon_linux.id
  instance_type = "t2.micro"
  key_name      = "ec2-key"

  availability_zone = element(module.vpc.azs, 0)
  subnet_id         = element(module.vpc.public_subnets, 0)
  vpc_security_group_ids = [
    module.ssh_security_group.security_group_id,
    module.vpn_security_group.security_group_id,
    module.outbound_security_group.security_group_id,
  ]
  associate_public_ip_address = true

  user_data_base64            = base64encode(local.vpnserver_user_data)
  user_data_replace_on_change = true

  tags = local.tags
}

module "proxy_ec2" {
  source  = "terraform-aws-modules/ec2-instance/aws"
  version = "~> 5.0"

  name          = "${local.name}_proxy"
  ami           = data.aws_ami.amazon_linux.id
  instance_type = "t2.micro"
  key_name      = "ec2-key"

  availability_zone = element(module.vpc.azs, 0)
  subnet_id         = element(module.vpc.private_subnets, 0)
  vpc_security_group_ids = [
    module.ssh_security_group.security_group_id,
    module.vpn_security_group.security_group_id,
    module.outbound_security_group.security_group_id,
  ]

  user_data_base64            = base64encode("${local.vpnclient_user_data}\n${local.squid_user_data}")
  user_data_replace_on_change = true

  tags = local.tags
}

module "dns_dhcp_ec2" {
  source  = "terraform-aws-modules/ec2-instance/aws"
  version = "~> 5.0"

  name          = "${local.name}_dns_dhcp"
  ami           = data.aws_ami.amazon_linux.id
  instance_type = "t2.nano"
  key_name      = "ec2-key"

  availability_zone = element(module.vpc.azs, 0)
  subnet_id         = element(module.vpc.private_subnets, 0)
  vpc_security_group_ids = [
    module.ssh_security_group.security_group_id,
    module.vpn_security_group.security_group_id,
    module.outbound_security_group.security_group_id,
  ]

  user_data_base64            = base64encode("${local.vpnclient_user_data}\n${local.dnsmasq_user_data}")
  user_data_replace_on_change = true

  tags = local.tags
}
