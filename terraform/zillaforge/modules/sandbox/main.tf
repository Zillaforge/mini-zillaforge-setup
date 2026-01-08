# Data sources: module performs lookups when ids are not provided
data "zillaforge_flavors" "this" {
  name = var.flavor_name
}

data "zillaforge_images" "this" {
  repository = var.image_repository
  tag        = var.image_tag
}

data "zillaforge_keypairs" "this" {
  name = var.keypair_name
}

data "zillaforge_networks" "this" {
  name = var.network_name
}

data "zillaforge_security_groups" "this" {
  name = var.sg_name
}

locals {
  flavor_id  = var.flavor_id  != "" ? var.flavor_id  : data.zillaforge_flavors.this.flavors[0].id
  image_id   = var.image_id   != "" ? var.image_id   : data.zillaforge_images.this.images[0].id
  keypair_id = var.keypair_id != "" ? var.keypair_id : data.zillaforge_keypairs.this.keypairs[0].id
  network_id = var.network_id != "" ? var.network_id : data.zillaforge_networks.this.networks[0].id
  sg_id      = var.sg_id      != "" ? var.sg_id      : data.zillaforge_security_groups.this.security_groups[0].id

  security_group_ids = length(var.security_group_ids) > 0 ? var.security_group_ids : [local.sg_id]
}

# If a reserved_fip IP address is provided, attempt to look it up and use it.
# Data source uses count to avoid evaluating when var.reserved_fip is empty.
data "zillaforge_floating_ips" "by_ip" {
  count      = var.reserved_fip != "" ? 1 : 0
  ip_address = var.reserved_fip
}

locals {
  # Try to extract an id/address from the data source; try() returns null if not present.
  reserved_fip_id      = try(data.zillaforge_floating_ips.by_ip[0].floating_ips[0].id, null)
  reserved_fip_address = try(data.zillaforge_floating_ips.by_ip[0].floating_ips[0].ip_address, null)
  use_reserved_fip     = var.reserved_fip != "" && local.reserved_fip_id != null

  # final values used when attaching the floating IP to the server
  floating_ip_id      = local.use_reserved_fip ? local.reserved_fip_id : try(zillaforge_floating_ip.this[0].id, null)
  floating_ip_address = local.use_reserved_fip ? local.reserved_fip_address : try(zillaforge_floating_ip.this[0].ip_address, null)
}

resource "zillaforge_floating_ip" "this" {
  count = local.use_reserved_fip ? 0 : 1
  name  = var.floating_ip_name != "" ? var.floating_ip_name : "${var.name}-floating-ip"
}

resource "zillaforge_server" "this" {
  name      = var.name
  flavor_id = local.flavor_id
  image_id  = local.image_id
  keypair   = local.keypair_id
  user_data = var.user_data != "" ? var.user_data : (var.pre_install == "" ? null : file("${path.module}/setup_scripts/${var.pre_install}_setup.sh"))

  network_attachment {
    network_id     = local.network_id
    floating_ip_id = local.floating_ip_id
    security_group_ids = local.security_group_ids
  }
}
