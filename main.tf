# Description
# This Terraform configuration file creates two VPCs with two subnets each. 
# It also creates a gateway VM that forwards traffic between the two VPCs. 
# The gateway VM has two network interfaces, one in each VPC. 
# The configuration also creates two VMs, one in each VPC, that can be used to test 
# the connectivity between the two VPCs. The gateway VM is configured to forward 
# traffic between the two VPCs using IP forwarding. The configuration also creates 
# firewall rules that allow SSH traffic between the VMs in the same VPC and between
# the VMs and the gateway VM. The configuration also creates firewall rules that
# allow SSH traffic from the IAP service to the VMs in each VPC. The configuration 
# also creates routes that forward traffic between the two VPCs through the gateway VM.
#
# Additional troubleshooting steps:
# On vm1vpc1inter (10.0.1.0/24) - ping/ssh <vm1vpc2inter_ip>
# On vm1vpc2inter (10.0.2.0/24) - ping/ssh <vm1vpc1inter_ip>

provider "google" {
  project = var.gcp_project
  region  = var.region
  zone    = var.zone
}

# VPC and Subnets
# Create VPC1
resource "google_compute_network" "my_vpc1" {
  name                    = "vpn-vpc1"
  project                 = var.gcp_project
  auto_create_subnetworks = false
}

# Create Subnet for VM1 in VPC1
resource "google_compute_subnetwork" "subnet_vm1" {
  name          = "subnet-vm1"
  network       = google_compute_network.my_vpc1.name
  ip_cidr_range = var.subnet_cidr_vpc1_sub1
  region        = var.region
}

# Create VPC2
resource "google_compute_network" "my_vpc2" {
  name                    = "vpn-vpc2"
  project                 = var.gcp_project
  auto_create_subnetworks = false
}

# Create Subnet for VM2 in VPC2
resource "google_compute_subnetwork" "subnet_vm2" {
  name          = "subnet-vm2"
  network       = google_compute_network.my_vpc2.name
  ip_cidr_range = var.subnet_cidr_vpc2_sub1
  region        = var.region
}

# Firewall rules for SSH inside VPC1
# Allow SSH and ICMP traffic within VPC1
resource "google_compute_firewall" "ssh-vpc1" {
  name    = "ssh-vpc1"
  network = google_compute_network.my_vpc1.name

  allow {
    protocol = "icmp"
  }
  
  allow {
    protocol = "tcp"
    ports    = ["22"]
  }

  source_ranges = [var.subnet_cidr_vpc1_sub1, var.subnet_cidr_vpc2_sub1]
}

# Firewall rules for SSH inside VPC2
# Allow SSH and ICMP traffic within VPC2
resource "google_compute_firewall" "ssh-vpc2" {
  name    = "ssh-vpc2"
  network = google_compute_network.my_vpc2.name

  allow {
    protocol = "icmp"
  }

  allow {
    protocol = "tcp"
    ports    = ["22"]
  }

  source_ranges = [var.subnet_cidr_vpc2_sub1, var.subnet_cidr_vpc1_sub1]
}

# IAP SSH Firewall Rules
# Allow SSH traffic from IAP to VPC1
resource "google_compute_firewall" "iap_ssh-vpc1" {
  name    = "iap-ssh-vpc1"
  network = google_compute_network.my_vpc1.name

  allow {
    protocol = "tcp"
    ports    = ["22"]
  }

  source_ranges = ["35.235.240.0/20"]  # Replace with your desired source IP range

  target_tags = ["iap-ssh-vpc1"]
}

# Allow SSH traffic from IAP to VPC2
resource "google_compute_firewall" "iap_ssh-vpc2" {
  name    = "iap-ssh-vpc2"
  network = google_compute_network.my_vpc2.name

  allow {
    protocol = "tcp"
    ports    = ["22"]
  }

  source_ranges = ["35.235.240.0/20"]  # Replace with your desired source IP range

  target_tags = ["iap-ssh-vpc2"]
}

# Gateway VM  - VPC1  - VPC2
# Create Gateway VM with IP forwarding enabled
resource "google_compute_instance" "gateway" {
  name         = "gateway"
  machine_type = "e2-medium"
  zone         = var.zone
  
  metadata_startup_script = <<-EOT
    #!/bin/bash
    sysctl -w net.ipv4.ip_forward=1
    echo "net.ipv4.ip_forward=1" >> /etc/sysctl.conf
    useradd -m -s /bin/bash ${var.userid}
    # Add the user's public key to ${var.userid}
    mkdir -p /home/${var.userid}/.ssh
    echo "${var.ssh_public_key}" >> /home/${var.userid}/.ssh/authorized_keys
    chown -R ${var.userid}:${var.userid} /home/${var.userid}/.ssh
    chmod 700 /home/${var.userid}/.ssh
    chmod 600 /home/${var.userid}/.ssh/authorized_keys

    # Set an easy initial password and force change on first login
    echo "${var.userid}:TempUser123!" | chpasswd
    chage -d 0 ${var.userid}

    # Add user to wheel group
    usermod -aG wheel ${var.userid}
    EOT
  
  boot_disk {
    initialize_params {
      image = "rocky-linux-cloud/rocky-linux-8"
    }
  }

  network_interface {
    network = google_compute_network.my_vpc1.self_link
    subnetwork = google_compute_subnetwork.subnet_vm1.self_link
  }

  network_interface {
    network = google_compute_network.my_vpc2.self_link
    subnetwork = google_compute_subnetwork.subnet_vm2.self_link
  }

  can_ip_forward = true

  tags = ["iap-ssh-vpc1"]
  
}

# This file contains the configuration for the VM1vpc1inter resource.
# Create VM1 in VPC1
resource "google_compute_instance" "vm1vpc1inter" {
  name         = "vm1vpc1inter"
  machine_type = "e2-medium"
  zone         = var.zone
  
  metadata_startup_script = <<-EOT
    #!/bin/bash
    useradd -m -s /bin/bash ${var.userid}
    # Add the user's public key to ${var.userid}
    mkdir -p /home/${var.userid}/.ssh
    echo "${var.ssh_public_key}" >> /home/${var.userid}/.ssh/authorized_keys
    chown -R ${var.userid}:${var.userid} /home/${var.userid}/.ssh
    chmod 700 /home/${var.userid}/.ssh
    chmod 600 /home/${var.userid}/.ssh/authorized_keys

    # Set an easy initial password and force change on first login
    echo "${var.userid}:TempUser123!" | chpasswd
    chage -d 0 ${var.userid}

    # Add user to wheel group
    usermod -aG wheel ${var.userid}
  EOT

  boot_disk {
    initialize_params {
      image = "rocky-linux-cloud/rocky-linux-8"
    }
  }

  network_interface {
    network = google_compute_network.my_vpc1.self_link
    subnetwork = google_compute_subnetwork.subnet_vm1.self_link
  }

   tags = ["iap-ssh-vpc1"]
}

# This file contains the configuration for the VM1vpc2inter resource.
# Create VM1 in VPC2
resource "google_compute_instance" "vm1vpc2inter" {
  name         = "vm1vpc2inter"
  machine_type = "e2-medium"
  zone         = var.zone
  
  metadata_startup_script = <<-EOT
    #!/bin/bash
    useradd -m -s /bin/bash ${var.userid}
    # Add the user's public key to ${var.userid}
    mkdir -p /home/${var.userid}/.ssh
    echo "${var.ssh_public_key}" >> /home/${var.userid}/.ssh/authorized_keys
    chown -R ${var.userid}:${var.userid} /home/${var.userid}/.ssh
    chmod 700 /home/${var.userid}/.ssh
    chmod 600 /home/${var.userid}/.ssh/authorized_keys

    # Set an easy initial password and force change on first login
    echo "${var.userid}:TempUser123!" | chpasswd
    chage -d 0 ${var.userid}

    # Add user to wheel group
    usermod -aG wheel ${var.userid}
  EOT

  boot_disk {
    initialize_params {
      image = "rocky-linux-cloud/rocky-linux-8"
    }
  }

  network_interface {
    network = google_compute_network.my_vpc2.self_link
    subnetwork = google_compute_subnetwork.subnet_vm2.self_link
  }

   tags = ["iap-ssh-vpc2"]
}

# Service Account
# Create a service account for VPN
resource "google_service_account" "vpn_service_account" {
  account_id   = "vpn-service-account-gce"
  display_name = "VPN Service Account"
  project      = var.gcp_project
}

# Bind the service account to the project with compute.osLogin role
resource "google_project_iam_binding" "vpn_service_account_binding" {
  project = var.gcp_project
  role    = "roles/compute.osLogin"
  members = [
    "serviceAccount:${google_service_account.vpn_service_account.email}"
  ]
}

# Bind the service account to the gateway instance with compute.osLogin role
resource "google_compute_instance_iam_binding" "gateway_iap_ssh" {
  depends_on = [ google_compute_instance.gateway ]
  project       = var.gcp_project
  instance_name = google_compute_instance.gateway.name
  role          = "roles/compute.osLogin"
  members       = ["serviceAccount:${google_service_account.vpn_service_account.email}"]
}

# Create route from VPC1 to VPC2 via gateway
resource "google_compute_route" "route_vpc1_to_vpc2" {
  name               = "vpc1-to-vpc2"
  network            = google_compute_network.my_vpc1.name
  dest_range         = var.subnet_cidr_vpc2_sub1
  next_hop_instance  = google_compute_instance.gateway.self_link
  next_hop_instance_zone = google_compute_instance.gateway.zone
}

# Create route from VPC2 to VPC1 via gateway
resource "google_compute_route" "route_vpc2_to_vpc1" {
  name               = "vpc2-to-vpc1"
  network            = google_compute_network.my_vpc2.name
  dest_range         = var.subnet_cidr_vpc1_sub1
  next_hop_instance  = google_compute_instance.gateway.self_link
  next_hop_instance_zone = google_compute_instance.gateway.zone
}
