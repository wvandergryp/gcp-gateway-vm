variable "gcp_project" {
   description = "The ID of the project in which resources will be managed."
   type        = string
   default = "<GCP project id>"
}

variable "subnet_cidr_vpc1_sub1" {
  description = "CIDR range for the subnet"
  default     = "10.0.1.0/24"
}

variable "subnet_cidr_vpc2_sub1" {
  description = "CIDR range for the subnet"
  default     = "10.0.2.0/24"
}

variable "ssh_public_key" {
  description = "SSH public key"
  default     = ""
}

variable "userid" {
  description = "OS user id to be created"
  default     = "ssh-rocky"
}

variable "region" {
  description = "The region where resources will be created."
  default     = "us-central1"
}

  variable "zone" {
    description = "The zone where resources will be created."
    default     = "us-central1-c"
  }