variable "api_endpoint" {
  description = "API endpoint to use with the provider"
  type        = string
  default     = "https://api.trusted-cloud.nchc.org.tw"
}

variable "api_key" {
  description = "API key for zillaforge provider"
  type        = string
  default     = ""
}

variable "project_sys_code" {
  description = "Project system code to use with the provider"
  type        = string
  default     = ""
}

variable "flavor_name" {
  description = "The name of the flavor to use for servers"
  type        = string
  default     = "Basic.large"
}

variable "network_name" {
  description = "The name of the network to attach servers to"
  type        = string
  default     = "default"
}

variable "keypair_name" {
  description = "The name of the keypair to use for servers"
  type        = string
  default     = "mykey"
}

variable "image_repository" {
  description = "The repository name for the image"
  type        = string
  default     = "ubuntu"
}

variable "image_tag" {
  description = "The tag for the image repository"
  type        = string
  default     = "2404"
}

variable "pre_install" {
  description = "Name of pre-install script to run on server creation (e.g., \"devstack\" or \"zillaforge\"). Empty string means none."
  type        = string
  default     = ""
}

variable "total" {
  description = "Number of sandbox instances to create"
  type        = number
  default     = 1
}

variable "name" {
  description = "Base name for sandbox servers; when creating multiple instances, `-<index>` will be appended"
  type        = string
  default     = "sandbox-by-terraform"
}

variable "sg_name" {
  description = "The name of the security group to use"
  type        = string
  default     = "my-sg"
}

variable "existing_ip" {
  description = "(Optional) Existing floating IP address to pass to sandbox module's reserved_fip"
  type        = string
  default     = ""
}

