terraform {
  backend "azurerm" {
  }
}

provider "azurerm" {
  features {}
}

module "naming" {
  source  = "Azure/naming/azurerm"
  suffix = [ "prod" ]
}

module "naming_bastion" {
  source  = "Azure/naming/azurerm"
  suffix = [ "prod-bastion" ]
}

resource "azurerm_resource_group" "baserg" {
  name     = module.naming.resource_group.name
  location = "UK West"
}

resource "azurerm_virtual_network" "basevnet" {
  name                = module.naming.virtual_network.name
  location            = azurerm_resource_group.baserg.location
  resource_group_name = azurerm_resource_group.baserg.name
  address_space       = ["192.168.128.0/17"]
}

resource "azurerm_subnet" "basesubnet" {
  name                 = module.naming.subnet.name
  resource_group_name  = azurerm_resource_group.baserg.name
  virtual_network_name = azurerm_virtual_network.basevnet.name
  address_prefixes     = ["192.168.128.0/24"]
}


## Coder VM ##

resource "azurerm_public_ip" "bastion" {
  count = var.global_settings.bastion.enabled ? 1 : 0
  name                = module.naming_bastion.public_ip.name
  resource_group_name = azurerm_resource_group.baserg.name
  location            = azurerm_resource_group.baserg.location
  allocation_method   = "Static"

  tags = {
    environment = "prod"
  }
}

resource "azurerm_network_interface" "bastion" {
  count = var.global_settings.bastion.enabled ? 1 : 0
  name                = module.naming_bastion.network_interface.name
  location            = azurerm_resource_group.baserg.location
  resource_group_name = azurerm_resource_group.baserg.name

  ip_configuration {
    name                          = "internal"
    subnet_id                     = azurerm_subnet.basesubnet.id
    private_ip_address_allocation = "Dynamic"
    public_ip_address_id = azurerm_public_ip.bastion[0].id
  }
}

resource "azurerm_network_security_group" "bastion" {
  count = var.global_settings.bastion.enabled ? 1 : 0
  name                = module.naming_bastion.network_security_group[0].name
  location            = azurerm_resource_group.baserg.location
  resource_group_name = azurerm_resource_group.baserg.name
  security_rule {
      name                        = "Allow SSH"
      priority                    = 100
      direction                   = "Inbound"
      access                      = "Allow"
      protocol                    = "Tcp"
      source_port_range           = "*"
      destination_port_range      = "22"
      source_address_prefixes       = ["217.155.15.224/32"]
      destination_address_prefix  = "*"
    }
  
  security_rule {
      name                        = "Allow All"
      priority                    = 101
      direction                   = "Inbound"
      access                      = "Allow"
      protocol                    = "*"
      source_port_range           = "*"
      destination_port_range  = "*"
      source_address_prefixes       = ["217.155.15.224/32" ]
      destination_address_prefix  = "*"
    }
  tags = {
    environment = "prod"
  }
}

resource "azurerm_subnet_network_security_group_association" "bastion" {
  count = var.global_settings.bastion.enabled ? 1 : 0
  subnet_id                 = azurerm_subnet.basesubnet.id
  network_security_group_id = azurerm_network_security_group.bastion[0].id
}

resource "azurerm_linux_virtual_machine" "bastion" {
    count = var.global_settings.bastion.enabled ? 1 : 0
  name                = module.naming_kube.linux_virtual_machine.name
  resource_group_name = azurerm_resource_group.baserg.name
  location            = azurerm_resource_group.baserg.location
  size                = "Standard_B1ls"
  admin_username      = "adminuser"
  network_interface_ids = [
    azurerm_network_interface.bastion[0].id,
  ]
  # eviction_policy = "Delete"
  # max_bid_price = "0.1"

  admin_ssh_key {
    username   = "adminuser"
    public_key = file("~/.ssh/id_rsa.pub")
  }

  os_disk {
    caching              = "ReadWrite"
    storage_account_type = "Standard_LRS"
  }

  source_image_reference {
    publisher = "Canonical"
    offer     = "UbuntuServer"
    sku       = "18.04-LTS"
    version   = "latest"
  }
}

resource "azurerm_dns_a_record" "bastion" {
  count = var.global_settings.bastion.enabled ? 1 : 0
  name                = "bastion"
  zone_name           = "megah3rtz.net"
  resource_group_name = "dns-zones"
  ttl                 = 60
  records = [ azurerm_public_ip.bastion[0].ip_address ]

}
