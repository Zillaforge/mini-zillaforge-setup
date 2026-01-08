####################################################################################################
# Block 1: Terraform configuration                                                                 #
# Description:                                                                                     #
# Defines required providers and version constraints. Ensures the correct provider source and      #
# version are used for stable resource management.                                                 #
####################################################################################################
terraform {
  required_providers {
    zillaforge = {
      source  = "hashicorp/zillaforge"
      version = "0.0.1-alpha"
    }
  }
}

####################################################################################################
# Block 2: Zilaforge Provider configuration                                                        #
#                                                                                                  #
# Description:                                                                                     #
# Configures the Zillaforge provider connection and credentials, including API endpoint, API key,  # 
# and project system code.                                                                         #
####################################################################################################
provider "zillaforge" {
  api_endpoint     = var.api_endpoint
  api_key          = var.api_key
  project_sys_code = var.project_sys_code
}

####################################################################################################
# Block 3: Sandbox module (create sandbox instances)                                               #
#                                                                                                  #
# Description:                                                                                     #
# Uses the local `modules/sandbox` module to create one or more sandbox instances.                 #
# Passes name(s), image, network, keypair, and other parameters; the module resolves resource IDs  #
# internally.                                                                                      #
####################################################################################################
module "sandbox" {
  source = "./modules/sandbox"

  count = var.total
  name  = var.total > 1 ? format("%s-%02d", var.name, count.index + 1) : var.name

  flavor_name      = var.flavor_name
  image_repository = var.image_repository
  image_tag        = var.image_tag
  keypair_name     = var.keypair_name
  network_name     = var.network_name
  sg_name          = var.sg_name

  pre_install  = var.pre_install
  reserved_fip = var.existing_ip
}

####################################################################################################
# Block 4: Output                                                                                  #
#                                                                                                  #
# Description:                                                                                     #
# Outputs the list of floating IP addresses for the sandbox instances. If only one instance is     #
# created, the output will be a single-element list.                                               #
####################################################################################################
output "floating_ip_addresses" {
  description = "List of floating IP addresses for all sandbox instances (single element if total = 1)"
  value       = module.sandbox[*].floating_ip_address
}