terraform {
  required_providers {
    openstack = {
      source  = "terraform-provider-openstack/openstack"
      version = "~> 1.54.1"
    }
  }
}

provider "openstack" {
  auth_url    = var.openstack_auth_url
  region      = "RegionOne"
  tenant_id   = var.openstack_tenant_id
  domain_name = var.openstack_domain_name

  application_credential_id     = var.openstack_application_credential_id
  application_credential_secret = var.openstack_application_credential_secret
}

# 建立 VM
resource "openstack_compute_instance_v2" "test_vm" {
  name            = "tf-cirros-test"
  flavor_id       = var.flavor_id
  image_id        = var.image_id
  key_pair        = var.ssh_key_pair
  security_groups = ["default"]

  network {
    uuid = var.network_id
  }
}
