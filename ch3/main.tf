locals {
  # Common tags to be assigned to all resources
  common_tags = {
    owner   = var.owner
    se-region = "AMER - Northeast E1"
    purposse = "education"
    ttl = "7 days"
    terraform = "true"
    hc-internet-facing = "true"
  }
}
terraform {
  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = "~> 2.5"
    }
  }
}
provider "aws" {
  region  = var.aws_region
}
data "aws_ami" "an_image" {
  most_recent      = true
  owners           = ["self"]
  filter {
    name   = "name"
    values = ["${var.owner}-consul-*"]
  }
}
resource "tls_private_key" "my_private_key" {
 algorithm = "RSA"
 rsa_bits = 4096
}
resource "local_file" "private_key" {
 content = tls_private_key.my_private_key.private_key_pem
 filename = "${var.owner}-consul-key.pem"
 file_permission = 0400
}
resource "aws_key_pair" "consul_key" {
 key_name = "${var.owner}-consul-key"
 public_key = tls_private_key.my_private_key.public_key_openssh
}
resource aws_vpc "consul-demo" {
  cidr_block           = var.vpc_cidr
  enable_dns_hostnames = true
  tags = {
    Name = "${var.owner}-vpc"
  }
}
resource aws_subnet "consul-demo" {
  vpc_id     = aws_vpc.consul-demo.id
  cidr_block = var.vpc_cidr
  tags = {
    name = "${var.owner}-subnet"
    owner   = var.owner
    se-region = "AMER - Northeast E1"
    purpose = "education"
    ttl = "7 days"
    terraform = "true"
    hc-internet-facing = "true"
  }
}
resource aws_internet_gateway "consul-demo" {
  vpc_id = aws_vpc.consul-demo.id

  tags = {
    Name = "${var.owner}-internet-gateway"
    owner   = var.owner
    se-region = "AMER - Northeast E1"
    purpose = "education"
    ttl = "7 days"
    terraform = "true"
    hc-internet-facing = "true"
  }
}
resource aws_route_table "consul-demo" {
  vpc_id = aws_vpc.consul-demo.id
  route {
    cidr_block = "0.0.0.0/0"
    gateway_id = aws_internet_gateway.consul-demo.id
  }
}
resource aws_route_table_association "consul-demo" {
  subnet_id      = aws_subnet.consul-demo.id
  route_table_id = aws_route_table.consul-demo.id
}
resource aws_security_group "consul-demo" {
  name   = "${var.owner}-security-group"
  vpc_id = aws_vpc.consul-demo.id
  ingress {
    from_port   = 22
    to_port     = 22
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }
  ingress {
    from_port   = 8300
    to_port     = 8302
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }
  ingress {
    from_port   = 8500
    to_port     = 8500
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }
  ingress {
    from_port   = 8501
    to_port     = 8501
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }
  ingress {
    from_port   = 8600
    to_port     = 8600
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }
  ingress {
    from_port   = 80
    to_port     = 80
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }
  ingress {
    from_port   = 443
    to_port     = 443
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }
  egress {
    from_port       = 0
    to_port         = 0
    protocol        = "-1"
    cidr_blocks     = ["0.0.0.0/0"]
    prefix_list_ids = []
  }
  tags = {
    Name = "${var.owner}-security-group"
    owner   = var.owner
    se-region = "AMER - Northeast E1"
    purpose = "education"
    ttl = "7 days"
    terraform = "true"
    hc-internet-facing = "true"
  }
}
resource aws_instance "consul-server" {
  count                       = 3
  ami                         = data.aws_ami.an_image.id
  instance_type               = var.instance_type
  key_name                    = aws_key_pair.consul_key.key_name
  // key_name                    = "rjackson-east"
  associate_public_ip_address = true
  subnet_id                   = aws_subnet.consul-demo.id
  vpc_security_group_ids      = [aws_security_group.consul-demo.id]
  iam_instance_profile        = aws_iam_instance_profile.instance_profile.name
  user_data = templatefile("files/server_template.tpl", { server_name_tag = "${var.owner}-consul-server-instance", server_number = count.index})
  tags = {
    Name  = "${var.owner}-consul-server-instance"
    Instance = "${var.owner}-consul-server-instance-${count.index}"
    owner   = var.owner
    se-region = "AMER - Northeast E1"
    purpose = "education"
    ttl = "7 days"
    terraform = "true"
    hc-internet-facing = "true"
  }
  provisioner "file" {
    source      = "files/dc1-server-consul-${count.index}.pem"
    destination = "/tmp/dc1-server-consul-${count.index}.pem"
  }
  provisioner "file" {
    source      = "files/dc1-server-consul-${count.index}-key.pem"
    destination = "/tmp/dc1-server-consul-${count.index}-key.pem"
  }
  provisioner "file" {
    source      = "files/server_acl.hcl"
    destination = "/tmp/server_acl.hcl"
  }
  provisioner "remote-exec" {
    inline = [
      "sudo mv /tmp/*.pem /etc/consul/consul.d/"
    ]
  }
  connection {
    type        = "ssh"
    user        = "ubuntu"
    private_key = local_file.private_key.content
    host        = self.public_ip
  }
}
resource aws_instance "consul-client" {
  count                       = 5
  ami                         = data.aws_ami.an_image.id
  instance_type               = var.instance_type
  key_name                    = aws_key_pair.consul_key.key_name
  associate_public_ip_address = true
  subnet_id                   = aws_subnet.consul-demo.id
  vpc_security_group_ids      = [aws_security_group.consul-demo.id]
  iam_instance_profile        = aws_iam_instance_profile.instance_profile.name
  tags = {
    Name  = "${var.owner}-consul-client-instance-${count.index}"
    owner   = var.owner
    se-region = "AMER - Northeast E1"
    purpose = "education"
    ttl = "7 days"
    terraform = "true"
    hc-internet-facing = "true"
  }
}
resource null_resource "provisioning-clients" {
  for_each = { for client in aws_instance.consul-client : client.tags.Name => client }
  provisioner "file" {
    source      = "files/httpd.json"
    destination = "/tmp/httpd.json"
  }
  provisioner "file" {
    source      = "files/client_acl.hcl"
    destination = "/tmp/client_acl.hcl"
  }
  provisioner "remote-exec" {
    inline = [
      "sudo cat << EOF > /tmp/consul-client.hcl",
      "advertise_addr = \"${each.value.public_ip}\"",
      "server = false",
      "enable_script_checks = true",
      "bind_addr = \"${each.value.private_ip}\"",
      "retry_join = [\"${aws_instance.consul-server[0].public_ip}\",\"${aws_instance.consul-server[1].public_ip}\",\"${aws_instance.consul-server[2].public_ip}\"]",
      "client_addr = \"${each.value.private_ip}\"",
      "ca_file =\"/etc/consul/consul.d/consul-agent-ca.pem\"",
      "verify_incoming = true",
      "verify_outgoing = true",
      "verify_server_hostname = true",
      "auto_encrypt = {",
      "  tls = true",
      "}",
      "EOF",
      "sudo mv /tmp/consul-client.hcl /etc/consul/consul.d/consul-client.hcl",
      "sudo mv /tmp/httpd.json /etc/consul/consul.d/httpd.json",
      "nohup python3 -m http.server 8080 &",
      "sleep 60"
    ]
  }
  provisioner "remote-exec" {
    inline = [
      "sudo systemctl start consul",
    ]
  }
  connection {
    type        = "ssh"
    user        = "ubuntu"
    private_key = local_file.private_key.content
    // private_key = file("~/hashicorp/aws/rjackson-east2.pem")
    host        = each.value.public_ip
  }
}
resource "aws_iam_instance_profile" "instance_profile" {
  name_prefix = var.owner
  role        = aws_iam_role.instance_role.name
}
resource "aws_iam_role" "instance_role" {
  name_prefix        = var.owner
  assume_role_policy = data.aws_iam_policy_document.instance_role.json
}
data "aws_iam_policy_document" "instance_role" {
  statement {
    effect  = "Allow"
    actions = ["sts:AssumeRole"]

    principals {
      type        = "Service"
      identifiers = ["ec2.amazonaws.com"]
    }
  }
}
resource "aws_iam_role_policy" "metadata_access" {
  name   = "metadata_access"
  role   = aws_iam_role.instance_role.id
  policy = data.aws_iam_policy_document.metadata_access.json
}
data "aws_iam_policy_document" "metadata_access" {
  statement {
    effect = "Allow"
    actions = [
      "ec2:DescribeInstances",
    ]
    resources = ["*"]
  }
}