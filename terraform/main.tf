#create resource group for all resources
resource "azurerm_resource_group" "resource_group" {
  name     = "stevenICC-rg"
  location = "australiaeast"
}
#create network using specified vnet range
resource "azurerm_virtual_network" "vnet" {
  name                = "${var.prefix}ICC.vnet"
  location            = azurerm_resource_group.resource_group.location
  resource_group_name = azurerm_resource_group.resource_group.name
  address_space       = ["10.10.0.0/16"]
}

#bastion servers will have ipaddresses like 10.10.100.*
resource "azurerm_subnet" "bastion-subnet" {
  name                 = "${var.prefix}ICC-bastion-subnet"
  resource_group_name = azurerm_resource_group.resource_group.name
  virtual_network_name = azurerm_virtual_network.vnet.name
  address_prefixes     = ["10.10.100.0/24"]
}
#webservers will have ipaddresses like 10.10.1.*
resource "azurerm_subnet" "public-subnet" {
  name                 = "${var.prefix}ICC-public-subnet"
  resource_group_name = azurerm_resource_group.resource_group.name
  virtual_network_name = azurerm_virtual_network.vnet.name
  address_prefixes     = ["10.10.1.0/24"]
}

#create net security group for bastion server and allow RDP connection 
resource "azurerm_network_security_group" "bastion-nsg" {
  name                = "${var.prefix}ICC-bastion-nsg"
  location            = azurerm_resource_group.resource_group.location
  resource_group_name = azurerm_resource_group.resource_group.name
  security_rule {
    name                       = "RDP"
    priority                   = 1000
    direction                  = "Inbound"
    access                     = "Allow"
    protocol                   = "*"
    source_port_range          = "*"
    destination_port_range     = "3389"
    source_address_prefix      = var.controllerip
    destination_address_prefix = "*"
  }
}
#create net security group and allow RDP connection 
resource "azurerm_network_security_group" "webserver-nsg" {
  name                = "${var.prefix}ICC-webserver-nsg"
  location            = azurerm_resource_group.resource_group.location
  resource_group_name = azurerm_resource_group.resource_group.name
  #allow HTTP from everywhere
  security_rule {
    name                       = "HTTP"
    priority                   = 1010
    direction                  = "Inbound"
    access                     = "Allow"
    protocol                   = "*"
    source_port_range          = "*"
    destination_port_range     = "80"
    source_address_prefix      = "*"
    destination_address_prefix = "*"
  }
  #allow RDP from bastion only allow accessing with private ip address
  security_rule {
    name                       = "RDP-Bastion"
    priority                   = 1000
    direction                  = "Inbound"
    access                     = "Allow"
    protocol                   = "Tcp"
    source_port_range          = "*"
    destination_port_range     = "3389"
    source_address_prefix      = azurerm_subnet.bastion-subnet.address_prefixes[0]
    destination_address_prefix = azurerm_subnet.public-subnet.address_prefixes[0]
  }
}
#apply network security policy to each subnet
resource "azurerm_subnet_network_security_group_association" "bastion_association" {
  subnet_id                 = azurerm_subnet.bastion-subnet.id
  network_security_group_id = azurerm_network_security_group.bastion-nsg.id
}

#apply network security policy to each subnet
resource "azurerm_subnet_network_security_group_association" "public_association" {
  subnet_id                 = azurerm_subnet.public-subnet.id
  network_security_group_id = azurerm_network_security_group.webserver-nsg.id
}


#create bastion server
#public ip for bastion server
resource "azurerm_public_ip" "bastionserver_public_ip" {
  name                = "${var.prefix}ICC-bastionserver-public-ip"
  location            = azurerm_resource_group.resource_group.location
  resource_group_name = azurerm_resource_group.resource_group.name
  allocation_method   = "Dynamic"
}
#create a nic for our bastion server
resource "azurerm_network_interface" "bastion-nic" {
  name                = "${var.prefix}ICC-bastion-nic"
  location            = azurerm_resource_group.resource_group.location
  resource_group_name = azurerm_resource_group.resource_group.name

  ip_configuration {
    name                          = "${var.prefix}ICC-bastion-configuration"
    subnet_id = azurerm_subnet.bastion-subnet.id
    private_ip_address_allocation = "Dynamic"
    
    public_ip_address_id          = azurerm_public_ip.bastionserver_public_ip.id
  }
}
# Create virtual machine
resource "azurerm_windows_virtual_machine" "bastion" {
  name                  = "${var.prefix}ICC.bastion.vm"
  admin_username        = "steven"   
  computer_name         = "ICC-bastion-vm"
  admin_password        = "Password@123!"
  location            = azurerm_resource_group.resource_group.location
  resource_group_name = azurerm_resource_group.resource_group.name
  network_interface_ids = [azurerm_network_interface.bastion-nic.id]
  size                  = "Standard_B2s"

  os_disk {
    name                 = "${var.prefix}-bastion-osdisk"
    caching              = "ReadWrite"
    storage_account_type = "Standard_LRS" 
  }

  source_image_reference {
    publisher = "MicrosoftWindowsServer"
    offer     = "WindowsServer"
    sku       = "2022-datacenter-azure-edition"
    version   = "latest"
  }
}

#create webserver
#public ip for webserver
resource "azurerm_public_ip" "webserver_public_ip" {
  name                = "${var.prefix}ICC-webserver-public-ip"
  location            = azurerm_resource_group.resource_group.location
  resource_group_name = azurerm_resource_group.resource_group.name
  allocation_method   = "Dynamic"
}
#create a nic for our web server
resource "azurerm_network_interface" "webserver-nic" {
  name                = "${var.prefix}ICC-webserver-nic"
  location            = azurerm_resource_group.resource_group.location
  resource_group_name = azurerm_resource_group.resource_group.name

  ip_configuration {
    name                          = "${var.prefix}ICC-webserver-configuration"
    subnet_id = azurerm_subnet.public-subnet.id
    private_ip_address_allocation = "Dynamic"
    
    public_ip_address_id          = azurerm_public_ip.webserver_public_ip.id
  }
}
# Create virtual machine
resource "azurerm_windows_virtual_machine" "webserver" {
  name                  = "${var.prefix}ICC.webserver.vm"
  admin_username        = "steven"   
  computer_name         = "ICC-web-vm"
  admin_password        = "Password@123!"
  location            = azurerm_resource_group.resource_group.location
  resource_group_name = azurerm_resource_group.resource_group.name
  network_interface_ids = [azurerm_network_interface.webserver-nic.id]
  size                  = "Standard_B2s"

  os_disk {
    name                 = "${var.prefix}ICC-webserver-osdisk"
    caching              = "ReadWrite"
    storage_account_type = "Standard_LRS" 
  }

  source_image_reference {
    publisher = "MicrosoftWindowsServer"
    offer     = "WindowsServer"
    sku       = "2022-datacenter-azure-edition"
    version   = "latest"
  }
}

#create a delegated subnet for flexible server
resource "azurerm_subnet" "delegated" {
  name                 = "${var.prefix}ICC-delegated-subnet"
  resource_group_name = azurerm_resource_group.resource_group.name
  virtual_network_name = azurerm_virtual_network.vnet.name
  address_prefixes     = ["10.10.10.0/24"]
  service_endpoints    = ["Microsoft.Storage"]
  delegation {
    name = "fs"
    service_delegation {
      name = "Microsoft.DBforMySQL/flexibleServers"
      actions = [
        "Microsoft.Network/virtualNetworks/subnets/join/action",
      ]
    }
  }
}

#create dns zone
resource "azurerm_private_dns_zone" "default" {
  name                = "${var.prefix}ICC.mysql.database.azure.com"
  resource_group_name = azurerm_resource_group.resource_group.name
}
#link the dns zone link 
resource "azurerm_private_dns_zone_virtual_network_link" "default" {
  name                  = "${var.prefix}ICC.VnetZone.com"
  private_dns_zone_name = azurerm_private_dns_zone.default.name
  virtual_network_id    = azurerm_virtual_network.vnet.id
  resource_group_name = azurerm_resource_group.resource_group.name
}

#create a flexible server with 
resource "azurerm_mysql_flexible_server" "mysqlfs" {
  name                   = "${var.prefix}-mysqlfs-icc603"
  resource_group_name = azurerm_resource_group.resource_group.name
  location            = azurerm_resource_group.resource_group.location
  administrator_login    = "psqladmin"
  administrator_password = "H@Sh1CoR3!"
  backup_retention_days  = 7
  delegated_subnet_id    = azurerm_subnet.delegated.id
  private_dns_zone_id    = azurerm_private_dns_zone.default.id
  sku_name               = "GP_Standard_D2ds_v4"
  version = "8.0.21"
  depends_on = [azurerm_private_dns_zone_virtual_network_link.default]
}