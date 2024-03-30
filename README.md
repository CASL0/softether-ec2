# softether-ec2

## Prerequisites

1. Terraform をインストールしてください。

   - https://developer.hashicorp.com/terraform/tutorials/aws-get-started/install-cli

1. 次の環境変数を設定してください。
   - AWS_ACCESS_KEY_ID
   - AWS_SECRET_ACCESS_KEY

## Getting Started

次のコマンドで EC2 を構築してください。

```sh
terraform plan
terraform apply -auto-approve
```

SSH で EC2 にアクセスし、SoftEther のセットアップを実施してください。

```sh
cd /opt/softether/vpnserver
make
sudo ./vpnserver start
```

<!-- prettier-ignore-start -->
<!-- BEGIN_TF_DOCS -->
## Requirements

| Name | Version |
|------|---------|
| <a name="requirement_terraform"></a> [terraform](#requirement\_terraform) | >= 1.0 |
| <a name="requirement_aws"></a> [aws](#requirement\_aws) | >= 5.00 |

## Providers

| Name | Version |
|------|---------|
| <a name="provider_aws"></a> [aws](#provider\_aws) | 5.41.0 |

## Modules

| Name | Source | Version |
|------|--------|---------|
| <a name="module_outbound_security_group"></a> [outbound\_security\_group](#module\_outbound\_security\_group) | terraform-aws-modules/security-group/aws | ~> 5.0 |
| <a name="module_ssh_security_group"></a> [ssh\_security\_group](#module\_ssh\_security\_group) | terraform-aws-modules/security-group/aws | ~> 5.0 |
| <a name="module_vpc"></a> [vpc](#module\_vpc) | terraform-aws-modules/vpc/aws | ~> 5.0 |
| <a name="module_vpn_ec2"></a> [vpn\_ec2](#module\_vpn\_ec2) | terraform-aws-modules/ec2-instance/aws | ~> 5.0 |
| <a name="module_vpn_security_group"></a> [vpn\_security\_group](#module\_vpn\_security\_group) | terraform-aws-modules/security-group/aws | ~> 5.0 |

## Resources

| Name | Type |
|------|------|
| [aws_ami.amazon_linux](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/data-sources/ami) | data source |
| [aws_availability_zones.available](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/data-sources/availability_zones) | data source |

## Inputs

No inputs.

## Outputs

| Name | Description |
|------|-------------|
| <a name="output_ami"></a> [ami](#output\_ami) | AWS AMI |
| <a name="output_ssh"></a> [ssh](#output\_ssh) | ssh command |
<!-- END_TF_DOCS -->
<!-- prettier-ignore-end -->
