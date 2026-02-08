packer {
  required_plugins {
    proxmox = {
      version = ">= 1.2.1"
      source  = "github.com/hashicorp/proxmox"
    }
  }
}

source "proxmox-iso" "ubuntu-2404" {
  proxmox_url              = var.proxmox_url
  username                 = var.proxmox_token_id
  token                    = var.proxmox_token_secret
  insecure_skip_tls_verify = true
  node                     = var.proxmox_node

  vm_id                = var.vm_id
  vm_name              = var.template_name
  template_description = "Ubuntu 24.04 LTS template - built with Packer"

  iso_file    = var.iso_file
  unmount_iso = true

  qemu_agent = true
  os         = "l26"

  cpu_type = "host"
  cores    = 2
  sockets  = 1
  memory   = 2048

  scsi_controller = "virtio-scsi-single"

  disks {
    disk_size    = "30G"
    storage_pool = var.storage_pool
    type         = "scsi"
    iothread     = true
    discard      = true
  }

  network_adapters {
    model  = "virtio"
    bridge = "vmbr0"
  }

  cloud_init              = true
  cloud_init_storage_pool = var.storage_pool

  http_directory = "http"

  boot_command = [
    "<esc><wait>",
    "e<wait>",
    "<down><down><down><end>",
    " autoinstall ds='nocloud-net;s=http://{{ .HTTPIP }}:{{ .HTTPPort }}/'",
    "<f10>"
  ]

  boot_wait = "10s"

  ssh_username = var.ssh_username
  ssh_password = var.ssh_password
  ssh_timeout  = "30m"
}

build {
  sources = ["source.proxmox-iso.ubuntu-2404"]

  provisioner "shell" {
    inline = [
      "sudo apt-get update",
      "sudo apt-get install -y qemu-guest-agent cloud-init",
      "sudo systemctl enable qemu-guest-agent",
      "sudo cloud-init clean",
      "sudo truncate -s 0 /etc/machine-id",
      "sudo rm -f /var/lib/dbus/machine-id",
      "sudo ln -s /etc/machine-id /var/lib/dbus/machine-id",
      "sudo sync"
    ]
  }
}
