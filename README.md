# gcp-gateway-vm
GCP Multi-NIC VM's with Terraform
Introduction:
In modern cloud architecture, isolating workloads across different Virtual Private Clouds (VPCs) is crucial for security, flexibility, and traffic control. Google Cloud Platform (GCP) offers multiple ways to achieve this, including VPC peering and Shared VPCs. However, there are scenarios where creating a dedicated gateway VM to forward traffic between VPCs can provide more granular control, especially for advanced routing and network segmentation.

In this blog, we will walk through a Terraform configuration that creates two VPCs, each with two subnets, and a gateway VM that forwards traffic between them using IP forwarding. We’ll also set up firewall rules to manage traffic between the VMs and the gateway VM, allowing secure communication and testing the inter-VPC connectivity. This setup is particularly useful for organizations looking to control traffic flow between isolated environments without the complexity of VPC peering.

Architecture:
Minimize image
Edit image
Delete image


Some use-cases and advantages:
1. VPC Segmentation for Security and Isolation
Advantage: The use of separate Virtual Private Clouds (VPCs) allows for network segmentation, which improves security by isolating workloads. Each VPC can host services or applications that should not directly interact with each other, providing a layer of security.

Use Case: For example, one VPC might contain front-end services while the other hosts sensitive back-end systems. By isolating the environments, you reduce the risk of lateral movement in case of a security breach.

2. Traffic Control via a Gateway VM
Advantage: The gateway VM with two network interfaces acts as a bridge between the two VPCs. It allows you to control the flow of traffic between the VPCs, giving you more granular control over network traffic.

Use Case: If you have strict compliance or security requirements, using a gateway VM allows you to inspect, log, and control traffic between the VPCs in ways that wouldn't be possible with direct VPC peering.

3. Flexibility in Routing and Traffic Management
Advantage: By using the gateway VM and custom routing, you have full control over how traffic moves between the two VPCs. This is useful for routing traffic through middleboxes, such as firewalls, logging systems, or other security appliances.

Use Case: The gateway VM could run services such as VPN, Network Address Translation (NAT), or packet inspection tools to inspect traffic flowing between the VPCs.

4. No Need for VPC Peering (or Avoid Peering Limits)
Advantage: GCP VPC peering allows direct connections between VPCs, but it has some limitations, like restrictions on transitive peering. By using a gateway VM, you avoid those limitations and have more flexibility in how traffic is forwarded between multiple VPCs.

Use Case: If you need a complex networking setup, where you need more advanced routing or want to avoid potential future peering limits, a gateway VM is a scalable solution.

5. Cost Management
Advantage: By avoiding VPC Network Peering, which incurs egress charges when data is transferred between peered VPCs, you can control the costs of network traffic by handling it through your gateway VM.

Use Case: For projects where network traffic between VPCs is expected to grow, managing that traffic through a single gateway VM can help optimize and predict costs, while also giving the flexibility to deploy cost-saving measures like caching or compression.

6. Granular Firewall Rules
Advantage: The configuration includes specific firewall rules, allowing you to control access only to SSH traffic between the VMs and the gateway VM. This adds a layer of security by restricting access between the environments.

Use Case: You can apply strict access control policies at each network interface, ensuring that only authorized traffic can traverse between the two VPCs or reach the gateway VM.

7. Easier Debugging and Traffic Monitoring
Advantage: Since all traffic between the VPCs passes through the gateway VM, you can monitor, log, and debug inter-VPC traffic more easily. This can help in troubleshooting network issues or detecting malicious activity.

Use Case: For scenarios where network traffic needs to be analyzed or logged for compliance, using the gateway VM allows you to capture the traffic in one central place.

8. Internal VPC Communication (Private IP Addresses)
Advantage: The gateway VM can forward traffic between VPCs using internal (private) IP addresses, reducing the reliance on external IPs and avoiding the exposure of traffic to the public internet.

Use Case: For security-conscious environments, internal communication using private IP addresses minimizes the attack surface and enhances internal security.

9. Test Connectivity Between Isolated Networks
Advantage: By placing test VMs in each VPC and using the gateway VM, you can simulate and test inter-VPC connectivity in an isolated environment before moving to production. This ensures your network design is sound before deploying real services.

Use Case: This is ideal for validating hybrid cloud architectures where you have complex networking requirements that need to be tested before implementation.

10. Avoid Shared VPC Setup in Simple Environments
Advantage: In cases where Shared VPCs might add unnecessary complexity (such as needing permissions and admin control at the host project level), this setup is simpler for smaller or isolated environments while still allowing inter-VPC communication.

Use Case: For smaller projects or those with more specific networking requirements, using a gateway VM to connect VPCs can be a lighter-weight alternative to Shared VPCs, which require more configuration and management.

Requirements:
Before running this Terraform configuration, ensure you have the following prerequisites set up:

Terraform Installed: Install Terraform on your local machine. You can download it from the Terraform website.

VSCode Installed: Use Visual Studio Code (VSCode) as your text editor to work with your Terraform files efficiently. You may also want to install the Terraform extension for better syntax highlighting and formatting.

Google Cloud Platform (GCP) Account: You need a GCP account with permissions to create projects and manage resources. Ensure billing is enabled for the account.

gcloud CLI Installed: Install the gcloud SDK to interact with Google Cloud from your command line.

For gcloud login, run:

gcloud auth application-default login
6.  If you prefer using a key file, set the following environment variable:

export GOOGLE_APPLICATION_CREDENTIALS="/path/to/your/key-file.json"
Git Bash (Optional): If you’re working on Windows, use Git Bash to run the commands in a Unix-like environment, which makes it easier to manage Terraform and gcloud operations.

Steps to Accomplish This Setup
1. Set Up Two VPCs and Subnets
First, define two VPCs in your Terraform configuration, each with two subnets. This provides a segregated network environment where each VPC can host different workloads.

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

2. Create the Gateway VM with Two Network Interfaces
The gateway VM needs two network interfaces, one in each VPC, to route traffic between them. Enable IP forwarding to allow the VM to forward traffic.

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


3. Create VMs for Testing Connectivity
Next, create a VM in each VPC. These VMs will be used to test the connectivity between the two VPCs by routing traffic through the gateway VM.

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

4. Create Firewall Rules
To allow traffic between the VMs and the gateway VM, and to permit SSH access from Google’s Identity-Aware Proxy (IAP), define firewall rules for SSH and other necessary traffic.

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
5. Create Routes for Inter-VPC Communication
Define custom routes to direct traffic between the two VPCs via the gateway VM. These routes will forward traffic between the subnets in VPC1 and VPC2 through the gateway VM. These routes ensure that traffic between two VPCs is forwarded through the gateway VM, which has two network interfaces (one for each VPC) and IP forwarding enabled. By configuring these routes, traffic from each VPC is routed through the gateway VM, allowing the two isolated networks to communicate with each other securely.

Understanding Custom Routes in GCP
In Google Cloud, a route specifies how packets leaving a particular subnet or VPC should be directed. In this case, when traffic from VPC1 needs to reach VPC2, or vice versa, you need to create custom routes to explicitly define that traffic should be forwarded to the gateway VM. The next_hop_instance in each route configuration specifies that the traffic should go through the gateway VM.

Without these routes, traffic between the two VPCs would not flow because by default, VPCs in Google Cloud are isolated from one another. The routes we're defining tell Google Cloud to use the gateway VM as a bridge between the two VPCs.

Key Components of a Custom Route in Terraform
network: Specifies the VPC for which this route is being defined. In this case, we’ll create one route for VPC1 and one for VPC2.

dest_range: Defines the destination CIDR block that this route applies to. For traffic from VPC1 to reach VPC2, the destination range will be the IP range of the subnet in VPC2, and vice versa.

next_hop_instance: Specifies the gateway VM that will forward the traffic.

next_hop_instance_zone: This indicates the zone where the gateway VM is deployed.

Route from VPC1 to VPC2 via Gateway
This route allows traffic from VPC1 to reach VPC2 by directing packets to the gateway VM. The next_hop_instance defines the gateway VM as the intermediary that forwards packets to their final destination.

# Create route from VPC1 to VPC2 via gateway
resource "google_compute_route" "route_vpc1_to_vpc2" {
  name               = "vpc1-to-vpc2"
  network            = google_compute_network.my_vpc1.name
  dest_range         = var.subnet_cidr_vpc2_sub1
  next_hop_instance  = google_compute_instance.gateway.self_link
  next_hop_instance_zone = google_compute_instance.gateway.zone
}
dest_range: This is the CIDR block of the subnet in VPC2 (e.g., 10.0.2.0/24).

next_hop_instance: The gateway VM will forward traffic from VPC1 to VPC2.

next_hop_instance_zone: The zone where the gateway VM resides, ensuring that the route is aware of the VM's location.

Route from VPC2 to VPC1 via Gateway
Similarly, we need to define the reverse route, where traffic from VPC2 can reach VPC1. Again, the next_hop_instance is set to the gateway VM, but this time, the destination range is the CIDR block of VPC1.

# Create route from VPC2 to VPC1 via gateway
resource "google_compute_route" "route_vpc2_to_vpc1" {
  name               = "vpc2-to-vpc1"
  network            = google_compute_network.my_vpc2.name
  dest_range         = var.subnet_cidr_vpc1_sub1
  next_hop_instance  = google_compute_instance.gateway.self_link
  next_hop_instance_zone = google_compute_instance.gateway.zone
}
dest_range: This is the CIDR block of the subnet in VPC1 (e.g., 10.0.1.0/24).

next_hop_instance: The gateway VM will forward traffic from VPC2 to VPC1.

next_hop_instance_zone: Specifies the zone of the gateway VM.

Why Are These Routes Necessary?
Isolated VPCs by Default: VPCs in GCP are isolated by default. Without these routes, the traffic between VPC1 and VPC2 wouldn’t be possible. By specifying custom routes, you're telling GCP how to direct traffic between the two networks through a specific VM that handles the forwarding.

Granular Traffic Control: Unlike VPC Peering, using a gateway VM with custom routes gives you granular control over how traffic flows between the two VPCs. You can inspect, modify, or log traffic as it passes through the gateway VM, making it ideal for scenarios requiring tight control over inter-VPC communication.

Simple IP Forwarding: The gateway VM acts as a middleman, and by enabling IP forwarding on the VM, you ensure that it can pass traffic from one network interface to another.

6. Testing Connectivity
Once the Terraform configuration is applied, SSH into vm1 and test the connectivity to vm2 using ping or ssh. The traffic will flow through the gateway VM, allowing communication between the two VPCs.

Clone repo and run the code:
Open a "cmd" prompt, create a new directory on your laptop where you want to clone the code. 

cd <code_path>
git clone https://github.com/wvandergryp/gcp-gateway-vm.git
code .
Then run vs code from there and got to Terminal -> "New Terminal" and go to the gitbash.

Here’s how you can run your Terraform commands with the -var-file option to use the terraform.tfvars file:

1. Change the terraform.tfvars file
Your terraform.tfvars file might look like this:

# The GCP project ID
gcp_project = "<project_id>"

# CIDR block for the first subnet in VPC1
subnet_cidr_vpc1_sub1 = "10.0.1.0/24"

# CIDR block for the first subnet in VPC2
subnet_cidr_vpc2_sub1 = "10.0.2.0/24"

# SSH public key for accessing instances
ssh_public_key = "ssh-rsa ........a9gVlyGBBKuWk4BxB7ca2Ku........."

# User ID for SSH access
userid = "ssh-rocky"

# GCP zone where resources will be deployed
zone = "us-central1-c"

# GCP region where resources will be deployed
region = "us-central1"
This file assigns specific values to each of the variables that you defined in your Terraform configuration.

2. Initialize Terraform
First, initialize the Terraform configuration by running:

terraform init
This command downloads all necessary plugins and modules.

3. Plan the Infrastructure
To generate an execution plan and see the changes Terraform will make, you can use the terraform plan command and pass the terraform.tfvars file with the -var-file option:

terraform plan -var-file="terraform.tfvars"
This will use the variables from the terraform.tfvars file to populate the configuration.

4. Apply the Configuration
Once you're satisfied with the plan, you can apply the Terraform configuration to deploy the resources:

terraform apply -var-file="terraform.tfvars"
This command will use the values from your terraform.tfvars file to create the infrastructure as defined in your configuration.

Testing the Network:
To test this setup and ensure that the custom routes and gateway VM are working as expected, follow these steps:

1. Test Connectivity Through the Gateway VM
SSH into VM1:

gcloud compute ssh vm1vpc1inter --zone <zone-name>
Test Ping from VM1 to VM2 via the Gateway:

ping <vm2-internal-ip>
2. Test Reverse Traffic from VM2 to VM1
SSH into VM2:

gcloud compute ssh vm2vpc2inter --zone <zone-name>
Ping VM1 from VM2:

ping <vm1-internal-ip>
Expected Result: You should receive a response, verifying that traffic can flow from VM2 to VM1 via the gateway VM.

Testing Connectivity Between VM1 and VM2:
In this configuration, you are creating accounts for both test VMs in each VPC using a startup script. The script adds a new user, sets up SSH access, and configures the system for that user. Here’s how this process works and how you can test the connection between VM1 and VM2 using the user accounts created through the Terraform script:

1. User Account Setup During VM Creation
In your Terraform configuration, the following script runs automatically on each VM as part of its startup process:

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
This script creates a user on the VM (defined by ${var.userid}), configures SSH access using the public key ${var.ssh_public_key}, and adds the user to the wheel group for administrative privileges.

The startup script also forces a password change on first login using chage -d 0, ensuring the user sets their own password after first use.

The SSH public key is added to the user's ~/.ssh/authorized_keys file, enabling key-based authentication.

Now let's test Connectivity Between VM1 and VM2
Now that both VMs are set up with user accounts and SSH access, here’s how you can test connectivity:

1. SSH into VM1:
First, SSH into VM1 using the IAP (Identity-Aware Proxy) or your local machine:

gcloud compute ssh ${var.userid}@vm1vpc1inter --zone <zone-name>
This command logs you into VM1 using the public key defined in your Terraform variables.

2. SSH from VM1 to VM2:
To establish SSH connectivity between VM1 and VM2 in separate VPCs via a gateway VM, you need to ensure the private key associated with the public key (${var.ssh_public_key}) is available on VM1.

Here's how to set it up:
Transfer Your Private Key to VM1 Before connecting from VM1 to VM2, you’ll need to place your private key on VM1. There are two options: 

Option 1: Using SCP to Transfer the Key
You can securely transfer the private key from your local machine to VM1 using the following 

gcloud compute scp ~/.ssh/id_rsa ${var.userid}@vm1vpc1inter:~/.ssh/id_rsa --zone <zone-name> 
This command copies the private key to the ~/.ssh/ directory on VM1.

Option 2: Manually Pasting the Private Key
If you'd prefer, you can manually paste the private key directly on VM1. First, SSH into VM1: 

gcloud compute ssh ${var.userid}@vm1vpc1inter --zone <zone-name> 
Once inside, create or edit the ~/.ssh/id_rsa file: 

nano ~/.ssh/id_rsa 
Paste your private key into the file, then save it and set the correct permissions:

chmod 600 ~/.ssh/id_rsa
SSH from VM1 to VM2 With the private key in place on VM1, you can now SSH into VM2 using its internal IP address: 

ssh -i ~/.ssh/id_rsa ${var.userid}@<vm2-internal-ip> 
This allows password less access to VM2, assuming the public key has been correctly configured in VM2’s authorized_keys file.

Verify Connectivity Once the connection is successful, you've successfully tested SSH access between VMs across different VPCs using a gateway VM to route traffic.

Destroy the Infrastructure
When you're ready to destroy the resources, run the terraform destroy command and pass the -var-file to ensure Terraform uses the correct variables:

terraform destroy -var-file="terraform.tfvars"
This will destroy all the infrastructure that was created based on the current Terraform state file. Sometimes you have to run this twice if you get an error.

Conclusion:
By configuring two VPCs with a gateway VM that forwards traffic between them, you gain fine-grained control over inter-VPC communication while maintaining security and isolation. This setup is ideal for environments where traffic needs to be routed through specific points for inspection or policy enforcement. With this Terraform configuration, you can easily deploy such an architecture and test its functionality.
