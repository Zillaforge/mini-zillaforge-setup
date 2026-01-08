variable "name" {
  description = "Server name"
  type        = string
}

# Users can pass either an id or a name; module will prefer id when provided
variable "flavor_id" {
  description = "(Optional) Flavor id to use for the server"
  type        = string
  default     = ""
}

variable "flavor_name" {
  description = "(Optional) Flavor name to lookup when flavor_id is not provided"
  type        = string
  default     = "Basic.large"
}

variable "image_id" {
  description = "(Optional) Image id to use for the server"
  type        = string
  default     = ""
}

variable "image_repository" {
  description = "(Optional) Image repository name to lookup when image_id is not provided"
  type        = string
  default     = "ubuntu"
}

variable "image_tag" {
  description = "(Optional) Image tag to lookup when image_id is not provided"
  type        = string
  default     = "2404"
}

variable "keypair_id" {
  description = "(Optional) Keypair id to use for the server"
  type        = string
  default     = ""
}

variable "keypair_name" {
  description = "(Optional) Keypair name to lookup when keypair_id is not provided"
  type        = string
  default     = "ogre0403"
}

variable "network_id" {
  description = "(Optional) Network id to attach the server to"
  type        = string
  default     = ""
}

variable "network_name" {
  description = "(Optional) Network name to lookup when network_id is not provided"
  type        = string
  default     = "default"
}

variable "security_group_ids" {
  description = "Optional list of security group ids to attach. When empty, module will lookup sg_name and use its id"
  type        = list(string)
  default     = []
}

variable "sg_id" {
  description = "(Optional) Security group id to use"
  type        = string
  default     = ""
}

variable "sg_name" {
  description = "(Optional) Security group name to lookup when sg_id is not provided"
  type        = string
  default     = "allow-all"
}

variable "user_data" {
  description = "User data for the server (string). If non-empty, it takes precedence over `pre_install`."
  type        = string
  default     = ""
}

variable "pre_install" {
  description = "Select a pre-install script by name (e.g., \"devstack\" or \"zillaforge\"). Empty string means no pre-install script. If non-empty, the module will use the file at `setup_scripts/<name>_setup.sh`."
  type        = string
  default     = ""

  validation {
    condition     = var.pre_install == "" || fileexists("${path.module}/setup_scripts/${var.pre_install}_setup.sh")
    error_message = "Invalid pre_install: must be empty or match an existing script under modules/sandbox/setup_scripts (e.g., \"devstack\" or \"zillaforge\")."
  }
}

variable "floating_ip_name" {
  description = "Name for the floating IP"
  type        = string
  default     = ""
}

variable "reserved_fip" {
  description = "(Optional) IP address of an already-reserved floating IP to use for this sandbox. When provided and found, the module will use the existing floating IP; if not provided or not found, the module will create a new floating IP."
  type        = string
  default     = ""
}
