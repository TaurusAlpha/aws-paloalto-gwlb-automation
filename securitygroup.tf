# ---------------------------------------------------------------------------------------------------------------------
# CREATE SECURITY GROUPS
# 2 SG (FW MGMT, FW DATA)
# ---------------------------------------------------------------------------------------------------------------------

resource "aws_security_group" "fw_mgmt_sg" {
  name        = "${var.name_prefix}-sgr-fw-mgmt-${random_id.deployment_id.hex}"
  description = "Allow inbound traffic only from Palo Alto Networks"
  vpc_id      = var.vpc_id

  ingress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = concat(var.mgmt_ip_list, flatten([for subnet in data.aws_subnet.mgmt_subnet_data : subnet.cidr_block]))
  }

  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }

  tags = {
    Name = "${var.name_prefix}-sgr-fw-mgmt-${random_id.deployment_id.hex}"
  }
}

resource "aws_security_group" "fw_data_sg" {
  name        = "${var.name_prefix}-sgr-fw-data-${random_id.deployment_id.hex}"
  description = "Allow inbound traffic only from GWLB"
  vpc_id      = var.vpc_id

  ingress {
    from_port   = 6081
    to_port     = 6081
    protocol    = "udp"
    cidr_blocks = ["0.0.0.0/0"]
  }

  ingress {
    from_port   = 80
    to_port     = 80
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }

  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }

  tags = {
    Name = "${var.name_prefix}-sgr-fw-data-${random_id.deployment_id.hex}"
  }
}

resource "aws_security_group" "lambda_sg" {
  name = "${var.name_prefix}-sgr-asg-lambda-${random_id.deployment_id.hex}"
  description = "Allow lambda HTTPS outbound access only"
  egress {
    from_port   = 443
    to_port     = 443
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }

  tags = {
    Name = "${var.name_prefix}-sgr-asg-lambda-${random_id.deployment_id.hex}"
  }
}