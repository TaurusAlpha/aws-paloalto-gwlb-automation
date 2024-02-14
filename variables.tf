# ---------------------------------------------------------------------------------------------------------------------
# MANDATORY PARAMETERS
# ---------------------------------------------------------------------------------------------------------------------

variable "profile_name" {
  type = string
}

variable "region" {
  description = "AWS Region"
  type        = string
}

variable "availability_zones" {
  description = "Availability zones in a region to deploy instances on"
  type        = list(string)
}

variable "firewall_ami_id" {
  description = "VM-Series AMI ID BYOL/Bundle1/Bundle2 for the specified region"
  type        = string
}

variable "public_key" {
  description = "Public key string for AWS SSH Key Pair"
  type        = string
}

variable "sec_vpc_id" {
  description = "Security VPC ID to deploy solution to"
  type        = string
}

variable "sec_mgmt_subnet_ids_map" {
  description = "Management subnet IDs"
  type        = map(string)
  default = {
    "region" = "subnet_id"
  }
}

variable "sec_data_subnet_ids_map" {
  description = "Inbound subnet IDs"
  type        = map(string)
  default = {
    "region" = "subnet_id"
  }
}

variable "sec_tgwa_subnet_ids_map" {
  description = "Transit Gateway attachemnt subnets"
  type        = map(string)
  default = {
    "region" = "subnet_id"
  }
}

variable "sec_gwlbe_subnet_ids_map" {
  description = "GWLBe subnets"
  type        = map(string)
  default = {
    "region" = "subnet_id"
  }
}

# ---------------------------------------------------------------------------------------------------------------------
# OPTIONAL PARAMETERS
# ---------------------------------------------------------------------------------------------------------------------

variable "lifecycle_hook_timeout" {
  description = "How long should we wait for lambda to finish"
  type        = number
  default     = 300
}

variable "deployment_suffix" {
  description = "Deployment ID suffix"
  type        = string
  default     = "PANW"
}

variable "fw_mgmt_sg_list" {
  description = "List of IP CIDRs that are allowed to access firewall management interface"
  type        = list(string)
  default     = ["0.0.0.0/0"]
}

variable "instance_type" {
  description = "Instance type of the web server instances in ASG"
  type        = string
  default     = "c5d.large"
}

variable "default_tag" {
  description = "Default tag to apply to all resources"
  type        = map(string)
  default = {
    key : ""
  }
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

variable "ebs_kms_id" {
  description = "Alias for AWS KMS used for EBS encryption in VM-Series"
  type        = string
  default     = "alias/aws/ebs"
}

variable "delicense_enabled" {
  description = "Enable automatic delicense of instances on Panorama server"
  type        = bool
  default     = true
}

variable "name_prefix" {
  description = "Name prefic for all provisioned resources"
  type        = string
  default     = ""
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
  default     = true
}

variable "panorama_config" {
  description = <<-EOF
  Secure string in Parameter Store with value in below format:
  ```
  {"username":"ACCOUNT","password":"PASSWORD","panorama1":"IP_ADDRESS1","panorama2":"IP_ADDRESS2","license_manager":"LICENSE_MANAGER_NAME"}"
  ```
  EOF
  type        = map(string)
  default     = null
  sensitive   = true
}

variable "bootstrap_config" {
  type      = map(string)
  sensitive = true
  default   = null
}