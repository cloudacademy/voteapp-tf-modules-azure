output "loadbalancer_frontend" {
  value = module.frontend.loadbalancer
}

output "bastion_public_ip" {
  value = module.bastion.bastion_public_ip
}

output "ssh_private_key" {
  value     = try(tls_private_key.skynetcorp[0].private_key_pem, null)
  sensitive = true
}

output "ssh_public_key" {
  value     = try(regexall("(?m)^ssh-rsa.*", tls_private_key.skynetcorp[0].public_key_openssh)[0], null)
  sensitive = true
}
