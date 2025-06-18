variable "location" {
  type = string
}

variable "resource_group_name" {
  type = string
}

variable "subnet_id" {
  type = string
}

variable "mongo_db_config" {
  sensitive = true
  type = object({
    connection_string = string
    username          = string
    password          = string
  })
  description = "mongodb connection details"
}

variable "ssh_pubkey" {
  type        = string
  description = "SSH public key for the API VMs"
}
