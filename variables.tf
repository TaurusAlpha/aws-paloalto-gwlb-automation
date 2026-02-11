# ---------------------------------------------------------------------------------------------------------------------
# GENERAL PARAMETERS
# ---------------------------------------------------------------------------------------------------------------------

# Terraform profile name for the provider
variable "profile_name" {
  type = string
}

# Region for the provider
variable "region" {
  description = "AWS Region"
  type        = string
}

variable "name_prefix" {
  description = "Name prefix for all provisioned resources"
  type        = string
  default     = ""
}

variable "name_suffix" {
  description = "Deployment ID suffix"
  type        = string
  default     = "PANW"
}

variable "default_tag" {
  description = "Default tag to apply to all resources (i.e map-migrated)"
  type        = map(string)
  default     = {}
}

# ---------------------------------------------------------------------------------------------------------------------
# PALO-ALTO PARAMETERS
# ---------------------------------------------------------------------------------------------------------------------

# VM-Series version setup
variable "vmseries_ami_id" {
  description = <<-EOF
  Specific AMI ID to use for VM-Series instance.
  If `null` (the default), `vmseries_version` and `vmseries_product_code` vars are used to determine a public image to use.
  To list all available VM-Series versions, run the command provided below. 
  Please have in mind that the `product-code` may need to be updated - check the `vmseries_product_code` variable for more information.
  In below example query change REGION and PRODUCT-CODE to get relevant AMI-ID
  ```
  aws ec2 describe-images --region us-west-1 --filters "Name=product-code,Values=6njl1pau431dv1qxipg63mvah" "Name=name,Values=PA-VM-AWS*" --output json --query "Images[].Description" \| grep -o 'PA-VM-AWS-.*' \| sort
  ```
  EOF
  default     = null
  type        = string
}

variable "vmseries_version" {
  description = <<-EOF
  VM-Series Firewall version to deploy.
  EOF
  default     = "10.2.0"
  type        = string
}

variable "vmseries_product_code" {
  description = <<-EOF
  Product code corresponding to a chosen VM-Series license type model - by default - BYOL. 
  To check the available license type models and their codes, please refer to the
  [VM-Series documentation](https://docs.paloaltonetworks.com/vm-series/10-0/vm-series-deployment/set-up-the-vm-series-firewall-on-aws/deploy-the-vm-series-firewall-on-aws/obtain-the-ami/get-amazon-machine-image-ids.html)

  VM-Series Next-Generation Firewall w/ Threat Prevention (PAYG)
  product-code = e9yfvyj3uag5uo5j2hjikv74n

  VM-Series Next-Generation Firewall w/ 5 Core Security Subs (PAYG)
  product-code = hd44w1chf26uv4p52cdynb2o

  VM-Series Virtual Next-Generation Firewall (BYOL)
  product-code = 6njl1pau431dv1qxipg63mvah

  EOF
  default     = "6njl1pau431dv1qxipg63mvah"
  type        = string
}

# !!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!
# PROVIDE ONLY ONE VARIABLE public_key OR ssh_key_pair
# !!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!

variable "public_key" {
  description = <<EOF
  Public key string for AWS SSH Key Pair
  Create a local ssh keypair to access instances deployed by this terraform deployment.

  Private Key: openssl genrsa -out private_key.pem 2048
  Change Permissions: chmod 400 private_key.pem
  Public Key: ssh-keygen -y -f private_key.pem > public_key.pub

  EOF
  type        = string
  default     = ""
}

variable "ssh_key_pair" {
  description = "Name of AWS keypair to associate with instances"
  type        = string
  default     = ""
}

variable "mgmt_ip_list" {
  description = <<EOF
  List of IP CIDRs that are allowed to access firewall management interface
  By default only Management Subnet CIDRs will be allowed
  EOF
  type        = list(string)
  default     = []
}

variable "instance_type" {
  description = "Instance type of the Palo-Alto instances in ASG"
  type        = string
  default     = "c5n.large"
}

variable "ebs_kms_id" {
  description = "Alias for AWS KMS used for EBS encryption in VM-Series"
  type        = string
  default     = "alias/aws/ebs"
}

variable "bootstrap_config" {
  description = <<EOF
  Configuration to bootstrap firewalls so the bootstrapped firewall can register with Panorama and complete the full configuration
  File components documentation: https://docs.paloaltonetworks.com/vm-series/11-0/vm-series-deployment/bootstrap-the-vm-series-firewall/create-the-init-cfgtxt-file/init-cfgtxt-file-components
  Config can be passed as UserData in the LaunchTemplate configuration or as secret using Secrets Manager.
  Due to sensitive data that config can include (i.e. panorama ip, vm-auth-key, auth-key etc) it is advised to use SecretsManager
  
  Configuration enabled by default and doesn't needs to be included:
  mgmt-interface-swap=enable
  plugin-op-commands=aws-gwlb-inspect:enable

  EOF
  type        = map(string)
  sensitive   = true
  default     = {}
}

# ---------------------------------------------------------------------------------------------------------------------
# NETWORK PARAMETERS
# ---------------------------------------------------------------------------------------------------------------------

variable "availability_zone_ids" {
  description = "Availability zone IDs in a region to deploy instances to"
  type        = list(string)
}

variable "vpc_id" {
  description = "VPC ID to deploy solution to"
  type        = string
}

variable "mgmt_subnets" {
  description = "Management subnet ids used for management interface"
  type        = list(string)
}

variable "data_subnets" {
  description = "Data subnet ids used as Palo-Alto incoming/outgoing interface and by GWLB"
  type        = list(string)
}

variable "gwlbe_subnets" {
  description = "GWLBe subnet ids used by GWLB endpoints"
  type        = list(string)
}

variable "tgwa_subnets" {
  description = "TGWa subnet ids used by Transit Gateway attachment"
  type        = list(string)
}

variable "tgwa_route_tables" {
  description = "IDs of rroute tables associated with TGWA subnets"
  type        = list(string)
}

variable "gwlb_allowed_principals_arn" {
  description = <<EOF
  ARNs of additional allowed principals to associate with GWLB
  Terrafrom caller arn is included by default
  i.e. arn:aws:iam::123456789123:root
  EOF
  type        = list(string)
  default     = []
}

# ---------------------------------------------------------------------------------------------------------------------
# AUTOSCALING PARAMETERS
# ---------------------------------------------------------------------------------------------------------------------

variable "lifecycle_hook_timeout" {
  description = "How long should ASG wait for lifecycle hook to finish"
  type        = number
  default     = 300
}

variable "global_asg_timeout" {
  description = <<EOF
  Timeout needed to correctly drain autoscaling group while deleting ASG.

  By default in AWS timeout is set to 10 minutes, which is too low and causes issue:
  Error: waiting for Auto Scaling Group (example-asg) drain: timeout while waiting for state to become '0' (last state: '1', timeout: 10m0s)
  EOF
  type        = string
  default     = "20m"
}

variable "suspended_processes" {
  description = "List of processes to suspend for the Auto Scaling Group. The allowed values are Launch, Terminate, HealthCheck, ReplaceUnhealthy, AZRebalance, AlarmNotification, ScheduledActions, AddToLoadBalancer, InstanceRefresh"
  type        = list(string)
  default     = []
}

# ---------------------------------------------------------------------------------------------------------------------
# LAMBDA PARAMETERS
# ---------------------------------------------------------------------------------------------------------------------

variable "delicense_enabled" {
  description = "Enable automatic delicense of instances on Panorama server"
  type        = bool
  default     = true
}

variable "lambda_execute_pip_install_once" {
  description = <<EOF
  Flag used in local-exec command installing Python packages required by Lambda.

  If set to true, local-exec is executed only once, when all resources are created.
  If you need to have idempotent behaviour for terraform apply every time and you have downloaded
  all required Python packages, set it to true.

  If set to false, every time it's checked if files for package pan_os_python are downloaded.
  If not, it causes execution of local-exec command in two consecutive calls of terraform apply:
  - first time value of installed-pan-os-python is changed from true (or empty) to false
  - second time value of installed-pan-os-python is changed from false to true
  In summary while executing code from scratch, two consecutive calls of terraform apply are not idempotent.
  The third execution of terraform apply show no changes.
  While using modules in CI/CD pipelines, when agents are selected randomly, set this value to false
  in order to check every time, if pan_os_python package is downloaded.
  EOF
  type        = bool
  default     = false
}

variable "panorama_config" {
  description = <<-EOF
  Panorama configuration for the lambda automation
  Secure string in Secrets Manager with key-value pairs:
  ```
  {"username":"ACCOUNT","password":"PASSWORD","panorama1":"IP_ADDRESS1","panorama2":"IP_ADDRESS2","license_manager":"LICENSE_MANAGER_NAME"}"
  ```
  EOF
  type        = map(string)
  default     = null
  sensitive   = true
}