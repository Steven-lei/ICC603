
output "bastionip" {
  description = "ipaddress of bastion server" 
  value = azurerm_windows_virtual_machine.bastion.public_ip_address
}
output "bastionprivateip" {
  description = "private ipaddress of bastion server" 
  value = azurerm_windows_virtual_machine.bastion.private_ip_address
}

output "webserverip" {
  description = "ipaddress of web server" 
  value = azurerm_windows_virtual_machine.webserver.public_ip_address
}

output "mySQL" {
  description = "private dns zone of flexible server" 
  value = azurerm_private_dns_zone.default.name
}