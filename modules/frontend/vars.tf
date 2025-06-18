variable "location" {
  type = string
}

variable "resource_group_name" {
  type = string
}

variable "subnet_id" {
  type = string
}

variable "ssh_pubkey" {
  type        = string
  description = "SSH public key for the Frontend VMs"
}

variable "enable_https" {
  type        = bool
  description = "Enable HTTPS for the Frontend VMs"
}
