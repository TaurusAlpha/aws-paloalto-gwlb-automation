# ---------------------------------------------------------------------------------------------------------------------
# CREATE SECURITY GROUPS
# FW MGMT, FW DATA, LAMBDA
# ---------------------------------------------------------------------------------------------------------------------

resource "aws_security_group" "fw_mgmt_sg" {
  name        = "${var.name_prefix}-sgr-fw-mgmt-${random_id.deployment_id.hex}"
  description = "Allow inbound traffic only from Palo Alto Networks"
  vpc_id      = var.vpc_id

  lifecycle {
    create_before_destroy = true
  }

  tags = {
    Name = "${var.name_prefix}-sgr-fw-mgmt-${random_id.deployment_id.hex}"
  }
}

resource "aws_vpc_security_group_ingress_rule" "fw_mgmt_sg_ingress_https" {
  description       = "Allow inbound HTTPS from Management subnets"
  for_each          = data.aws_subnet.mgmt_subnet_data
  security_group_id = aws_security_group.fw_mgmt_sg.id
  ip_protocol       = "tcp"
  from_port         = 443
  to_port           = 443
  cidr_ipv4         = each.value.cidr_block
}

resource "aws_vpc_security_group_ingress_rule" "fw_mgmt_sg_ingress_https_user" {
  description       = "Allow HTTPS from User provided Management CIDRs"
  for_each          = try(toset(var.mgmt_ip_list))
  security_group_id = aws_security_group.fw_mgmt_sg.id
  ip_protocol       = "tcp"
  from_port         = 443
  to_port           = 443
  cidr_ipv4         = each.value
}

resource "aws_vpc_security_group_ingress_rule" "fw_mgmt_sg_ingress_ssh" {
  description       = "Allow inbound SSH from Management subnets"
  for_each          = data.aws_subnet.mgmt_subnet_data
  security_group_id = aws_security_group.fw_mgmt_sg.id
  ip_protocol       = "tcp"
  from_port         = 22
  to_port           = 22
  cidr_ipv4         = each.value.cidr_block
}

resource "aws_vpc_security_group_ingress_rule" "fw_mgmt_sg_ingress_ssh_user" {
  description       = "Allow SSH from User provided Management CIDRs"
  for_each          = try(toset(var.mgmt_ip_list))
  security_group_id = aws_security_group.fw_mgmt_sg.id
  ip_protocol       = "tcp"
  from_port         = 22
  to_port           = 22
  cidr_ipv4         = each.value
}

resource "aws_vpc_security_group_egress_rule" "mgmt_egress_any" {
  security_group_id = aws_security_group.fw_data_sg.id
  cidr_ipv4         = "0.0.0.0/0"
  ip_protocol       = "-1" # semantically equivalent to all ports
}

resource "aws_security_group" "fw_data_sg" {
  name        = "${var.name_prefix}-sgr-fw-data-${random_id.deployment_id.hex}"
  description = "Allow inbound traffic only from GWLB"
  vpc_id      = var.vpc_id

  lifecycle {
    create_before_destroy = true
  }

  tags = {
    Name = "${var.name_prefix}-sgr-fw-data-${random_id.deployment_id.hex}"
  }
}

resource "aws_vpc_security_group_ingress_rule" "fw_data_sg_ingress_geneve" {
  description       = "Allow GENEVE protocol"
  security_group_id = aws_security_group.fw_data_sg.id
  ip_protocol       = "udp"
  from_port         = 6081
  to_port           = 6081
  cidr_ipv4         = "0.0.0.0/0"
}

resource "aws_vpc_security_group_ingress_rule" "fw_data_sg_ingress_http_hc" {
  description       = "Allow HTTP Health Check for the GWLB target group"
  for_each          = data.aws_subnet.data_subnet_data
  security_group_id = aws_security_group.fw_data_sg.id
  ip_protocol       = "tcp"
  from_port         = 80
  to_port           = 80
  cidr_ipv4         = each.value.cidr_block
}

resource "aws_vpc_security_group_egress_rule" "data_egress_any" {
  security_group_id = aws_security_group.fw_mgmt_sg.id
  cidr_ipv4         = "0.0.0.0/0"
  ip_protocol       = "-1" # semantically equivalent to all ports
}

resource "aws_security_group" "lambda_sg" {
  name        = "${var.name_prefix}-sgr-asg-lambda-${random_id.deployment_id.hex}"
  description = "Allow lambda HTTPS outbound access only"
  vpc_id      = var.vpc_id

  tags = {
    Name = "${var.name_prefix}-sgr-asg-lambda-${random_id.deployment_id.hex}"
  }
}

resource "aws_vpc_security_group_egress_rule" "lambda_egress_https" {
  description       = "Allow HTTPS to AWS Services and Panorama"
  security_group_id = aws_security_group.lambda_sg.id
  from_port         = 443
  to_port           = 443
  cidr_ipv4         = "0.0.0.0/0"
  ip_protocol       = "tcp"
}