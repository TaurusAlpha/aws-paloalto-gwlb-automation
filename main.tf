# ~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~
# CREATE ALL THE RESOURCES IN EXISTING SECURITY VPC
# This template creates a Firewall Stack behind Gateway Load Balancer. Route Tables for GWLBe for each AZ
# ~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~

# Random ID to prevent naming overlaping
resource "random_id" "deployment_id" {
  byte_length = 2
  prefix      = "${var.name_suffix}-"
}
