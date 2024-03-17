output "ami" {
  description = "AWS AMI"
  value       = data.aws_ami.amazon_linux.name
}

output "ssh" {
  description = "ssh command"
  value       = "ssh ec2-user@${module.ec2.public_ip}"
}
