data "aws_kms_alias" "ebs_kms" {
  name = var.ebs_kms_id
}

# PA VM AMI ID lookup based on version and license type (determined by product code)
data "aws_ami" "ami_id" {
  count = var.vmseries_ami_id != null ? 0 : 1

  most_recent = true
  owners      = ["aws-marketplace"]

  filter {
    name   = "name"
    values = ["PA-VM-AWS-${var.vmseries_version}*"]
  }
  filter {
    name   = "product-code"
    values = [var.vmseries_product_code]
  }

  name_regex = "^PA-VM-AWS-${var.vmseries_version}-[[:alnum:]]{8}-([[:alnum:]]{4}-){3}[[:alnum:]]{12}$"
}

data "aws_caller_identity" "pa_caller" {}

data "aws_subnet" "mgmt_subnet_data" {
  for_each = toset(var.mgmt_subnets)
  id       = each.value
}

data "aws_subnet" "data_subnet_data" {
  for_each = toset(var.data_subnets)
  id       = each.value
}

data "aws_subnet" "tgwa_subnet_data" {
  for_each = toset(var.tgwa_subnets)
  id       = each.value
}

data "aws_subnet" "gwlbe_subnet_data" {
  for_each = toset(var.gwlbe_subnets)
  id       = each.value
}
