# AWS-PaloAlto-GWLB-VMSeries

Code taken from multiple Palo-Alto repos and customized to support specific project needs.
[Palo-Alto Networks GitHub](https://github.com/PaloAltoNetworks/AWS-GWLB-VMSeries/tree/main)

General Solution documentation
[VM-Series with AWS Gateway Load Balancer Documentation](https://docs.paloaltonetworks.com/vm-series/10-0/vm-series-deployment/set-up-the-vm-series-firewall-on-aws/vm-series-integration-with-gateway-load-balancer.html)

---

**Note:** This project was copied and adjusted from multiple Palo-Alto repositories to support specific project needs. See original sources:

- [Palo-Alto Networks GitHub](https://github.com/PaloAltoNetworks/AWS-GWLB-VMSeries/tree/main)
- [VM-Series with AWS Gateway Load Balancer Documentation](https://docs.paloaltonetworks.com/vm-series/10-0/vm-series-deployment/set-up-the-vm-series-firewall-on-aws/vm-series-integration-with-gateway-load-balancer.html)

## Overview

This project automates the deployment of Palo Alto VM-Series firewalls behind an AWS Gateway Load Balancer (GWLB) using Terraform. It includes:

- Terraform code for VPC, GWLB, ASG, security groups, IAM, Lambda, and secrets
- Python Lambda for interface scaling and Panorama license management

## Architecture

**Key AWS Resources:**

- Gateway Load Balancer (GWLB) and target groups
- Autoscaling Group (ASG) for VM-Series firewalls
- Security Groups for management, data, and Lambda
- Lambda function for lifecycle automation and Panorama integration
- AWS Secrets Manager for sensitive configuration

**Flow:**

1. GWLB steers traffic to firewall ASG
2. Lambda manages ENIs and Panorama licensing on instance lifecycle events
3. Secrets Manager stores bootstrap and Panorama config

## Prerequisites

- AWS account with sufficient permissions
- Terraform >= 0.14
- Python 3.12+ (for Lambda)
- [pan-os-python](https://github.com/PaloAltoNetworks/pan-os-python), boto3

## Setup & Usage

1. **Clone this repository**
2. **Configure AWS credentials** (profile or environment variables)
3. **Edit variables** in `variables.tf` or provide a `terraform.tfvars` file with your environment-specific values
4. **Install Python dependencies** for Lambda:

- `cd scripts && pip3 install --upgrade --target . -r requirements.txt`

1. **Initialize Terraform**

- `terraform init`

1. **Plan and apply**

- `terraform plan`
- `terraform apply`

## Variables

See `variables.tf` for all configurable options, including:

- AWS region, VPC/subnet IDs, instance type, AMI/product code, SSH keys
- Management/data subnet lists, Panorama config, bootstrap config

## Outputs

Key outputs include:

- GWLB endpoint service name
- Panorama and bootstrap secret names
- Deployment ID suffix

## Example terraform.tfvars

Create a `terraform.tfvars` (or pass via CLI) with environment-specific values. Minimal example:

```
profile_name = "default"
region       = "us-west-2"
name_prefix  = "example"
vpc_id       = "vpc-0123456789abcdef0"
availability_zone_ids = ["use1-az1","use1-az2"]
mgmt_subnets  = ["subnet-aaa","subnet-bbb"]
data_subnets  = ["subnet-ccc","subnet-ddd"]
gwlbe_subnets = ["subnet-eee","subnet-fff"]
tgwa_subnets  = ["subnet-ggg","subnet-hhh"]
tgwa_route_tables = ["rtb-111","rtb-222"]
# Provide either vmseries_ami_id or vmseries_version/product code
# vmseries_ami_id = "ami-0123456789abcdef0"
vmseries_version = "10.2.0"
# Optional: provide existing keypair name or public_key
ssh_key_pair = "my-keypair"
# Panorama and bootstrap configs should be stored in Secrets Manager in production;
# provide here only for testing (sensitive values).
# panorama_config = { "username"="admin" "password"="pass" "panorama1"="1.2.3.4" }
```

## Security

- Sensitive data is stored in AWS Secrets Manager
- IAM roles follow least privilege where possible (review for your environment)
- EBS volumes are encrypted with KMS

## Customization

- Adjust variables and resource parameters as needed for your environment
- Lambda logic can be extended for additional automation

## Troubleshooting

- Check CloudWatch Logs for Lambda execution errors
- Ensure all required subnets, VPC, and IAM roles exist and are correctly referenced
- Review Terraform plan output for resource changes and errors

## References

- [Palo-Alto Networks GitHub](https://github.com/PaloAltoNetworks/AWS-GWLB-VMSeries/tree/main)
- [VM-Series with AWS Gateway Load Balancer Documentation](https://docs.paloaltonetworks.com/vm-series/10-0/vm-series-deployment/set-up-the-vm-series-firewall-on-aws/vm-series-integration-with-gateway-load-balancer.html)

---

*This project is based on and includes code from Palo Alto Networks repositories, with customizations for specific deployment needs.*
