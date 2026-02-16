terraform {
  required_providers {
    proxmox = {
      source  = "bpg/proxmox"
      version = ">= 0.66.0"
    }
  }
}

resource "proxmox_virtual_environment_vm" "vm" {
  name      = var.name
  node_name = var.target_node
  vm_id     = var.vm_id

  description = var.description
  tags        = var.tags
  machine     = var.machine

  clone {
    vm_id = var.clone_template_id
    full  = true
  }

  cpu {
    cores   = var.cores
    sockets = var.sockets
    type    = "host"
  }

  memory {
    dedicated = var.memory
  }

  disk {
    datastore_id = var.storage_pool
    size          = var.disk_size
    interface     = "scsi0"
    iothread      = true
    discard       = "on"
  }

  network_device {
    bridge  = "vmbr0"
    model   = "virtio"
    vlan_id = var.vlan_id
  }

  dynamic "hostpci" {
    for_each = var.hostpci
    content {
      device  = hostpci.value.device
      mapping = hostpci.value.mapping
      pcie    = hostpci.value.pcie
      rombar  = hostpci.value.rombar
      xvga    = hostpci.value.xvga
    }
  }

  agent {
    enabled = true
  }

  initialization {
    ip_config {
      ipv4 {
        address = var.ip_address
        gateway = var.gateway
      }
    }

    dns {
      servers = var.dns_servers
      domain  = var.dns_domain
    }

    user_account {
      username = var.ssh_username
      keys     = var.ssh_public_keys
    }

    user_data_file_id = var.cloud_init_file_id
  }

  on_boot = var.on_boot

  lifecycle {
    ignore_changes = [
      initialization[0].user_data_file_id,
      initialization[0].dns,
    ]
  }
}
