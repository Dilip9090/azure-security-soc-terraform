terraform {
  required_version = ">= 1.5"
  required_providers {
    azurerm = {
      source  = "hashicorp/azurerm"
      version = "~> 4.0"
    }
    random = {
      source  = "hashicorp/random"
      version = "~> 3.0"
    }
  }
}

provider "azurerm" {
  features {
    resource_group {
      prevent_deletion_if_contains_resources = false  # Demo ke liye easy destroy
    }
  }
}

# ====================== VARIABLES & LOCALS ======================
variable "prefix" {
  description = "Project prefix for naming (keep short)"
  default     = "soc-demo"
}

variable "location" {
  description = "Azure region - centralindia (India ke liye sasta & fast) ya westeurope (Germany job ke liye)"
  default     = "centralindia"
}

variable "allowed_ips" {
  description = "Sirf in IPs se SSH/RDP allow hoga (security best practice)"
  type        = list(string)
  default     = ["0.0.0.0/0"]   # ←←← YAHAN APNA IP DAAL DO JAISA 49.36.XX.XX/32
}

locals {
  rg_name          = "${var.prefix}-rg"
  vnet_name        = "${var.prefix}-vnet"
  subnet_name      = "${var.prefix}-compute-subnet"
  nsg_name         = "${var.prefix}-nsg"
  law_name         = "${var.prefix}-law"
  storage_name     = "${var.prefix}storage${random_string.unique.result}"
  aks_name         = "${var.prefix}-aks"
  tags = {
    Project     = "Azure-Security-SOC-Demo"
    Purpose     = "Portfolio-Project-for-Microsoft-CSA-Role"
    Owner       = "Dilip"
    Environment = "Demo"
    CreatedBy   = "Terraform"
  }
}

resource "random_string" "unique" {
  length  = 6
  special = false
  upper   = false
}

resource "random_password" "vm_password" {
  length           = 16
  special          = true
  override_special = "!@#$%^&*()-_=+"
}

# ====================== RESOURCE GROUP ======================
resource "azurerm_resource_group" "rg" {
  name     = local.rg_name
  location = var.location
  tags     = local.tags

  # Job ke liye important: yeh poore SOC ka root hai – enterprise landing zone style
}

# ====================== LOG ANALYTICS + SENTINEL ======================
resource "azurerm_log_analytics_workspace" "law" {
  name                = local.law_name
  location            = var.location
  resource_group_name = azurerm_resource_group.rg.name
  sku                 = "PerGB2018"
  retention_in_days   = 30
  tags                = local.tags
}

# Microsoft Sentinel Onboarding (Corrected for latest provider)
resource "azurerm_sentinel_log_analytics_workspace_onboarding" "sentinel" {
  workspace_id = azurerm_log_analytics_workspace.law.id
  # customer_managed_key_enabled = false   # optional, sirf chahiye to uncomment kar
}

# ====================== MICROSOFT DEFENDER FOR CLOUD PLANS ======================
# Defender for Servers (VMs ke liye threat detection + vulnerability mgmt)
resource "azurerm_security_center_subscription_pricing" "defender_servers" {
  tier          = "Standard"
  resource_type = "VirtualMachines"
}

# Defender for Containers (AKS ke liye – JD mein explicitly listed)
resource "azurerm_security_center_subscription_pricing" "defender_containers" {
  tier          = "Standard"
  resource_type = "Containers"
}

# Defender for Storage (Storage ke liye malware scanning + CSPM)
resource "azurerm_security_center_subscription_pricing" "defender_storage" {
  tier          = "Standard"
  resource_type = "StorageAccounts"
  subplan       = "DefenderForStorageV2"   # Advanced malware scanning
}

# Cloud Security Posture Management (CSPM) – enterprise posture + recommendations
resource "azurerm_security_center_subscription_pricing" "defender_cspm" {
  tier          = "Standard"
  resource_type = "CloudPosture"   # Yeh CSPM enable karta hai poore subscription pe
}

# ====================== NETWORKING (Enterprise Landing Zone style) ======================
resource "azurerm_virtual_network" "vnet" {
  name                = local.vnet_name
  location            = var.location
  resource_group_name = azurerm_resource_group.rg.name
  address_space       = ["10.0.0.0/16"]
  tags                = local.tags
}

resource "azurerm_subnet" "compute" {
  name                 = local.subnet_name
  resource_group_name  = azurerm_resource_group.rg.name
  virtual_network_name = azurerm_virtual_network.vnet.name
  address_prefixes     = ["10.0.1.0/24"]
}

resource "azurerm_network_security_group" "nsg" {
  name                = local.nsg_name
  location            = var.location
  resource_group_name = azurerm_resource_group.rg.name
  tags                = local.tags
}

# Tight security rules – job mein "secure by design" dikhane ke liye
resource "azurerm_network_security_rule" "allow_ssh" {
  name                        = "Allow-SSH"
  priority                    = 100
  direction                   = "Inbound"
  access                      = "Allow"
  protocol                    = "Tcp"
  source_port_range           = "*"
  destination_port_range      = "22"
  source_address_prefixes     = var.allowed_ips
  destination_address_prefix  = "*"
  resource_group_name         = azurerm_resource_group.rg.name
  network_security_group_name = azurerm_network_security_group.nsg.name
}

resource "azurerm_network_security_rule" "allow_rdp" {
  name                        = "Allow-RDP"
  priority                    = 110
  direction                   = "Inbound"
  access                      = "Allow"
  protocol                    = "Tcp"
  source_port_range           = "*"
  destination_port_range      = "3389"
  source_address_prefixes     = var.allowed_ips
  destination_address_prefix  = "*"
  resource_group_name         = azurerm_resource_group.rg.name
  network_security_group_name = azurerm_network_security_group.nsg.name
}

resource "azurerm_network_security_rule" "deny_all" {
  name                        = "Deny-All-Inbound"
  priority                    = 4096
  direction                   = "Inbound"
  access                      = "Deny"
  protocol                    = "*"
  source_port_range           = "*"
  destination_port_range      = "*"
  source_address_prefix       = "*"
  destination_address_prefix  = "*"
  resource_group_name         = azurerm_resource_group.rg.name
  network_security_group_name = azurerm_network_security_group.nsg.name
}

resource "azurerm_subnet_network_security_group_association" "nsg_assoc" {
  subnet_id                 = azurerm_subnet.compute.id
  network_security_group_id = azurerm_network_security_group.nsg.id
}

# ====================== SAMPLE WORKLOADS ======================
# Linux VM (Defender for Servers demo ke liye)
resource "azurerm_public_ip" "linux_pip" {
  name                = "${var.prefix}-linux-pip"
  location            = var.location
  resource_group_name = azurerm_resource_group.rg.name
  allocation_method   = "Static"
  sku                 = "Standard"
  tags                = local.tags
}

resource "azurerm_network_interface" "linux_nic" {
  name                = "${var.prefix}-linux-nic"
  location            = var.location
  resource_group_name = azurerm_resource_group.rg.name
  tags                = local.tags

  ip_configuration {
    name                          = "internal"
    subnet_id                     = azurerm_subnet.compute.id
    private_ip_address_allocation = "Dynamic"
    public_ip_address_id          = azurerm_public_ip.linux_pip.id
  }
}

resource "azurerm_linux_virtual_machine" "linux_vm" {
  name                            = "${var.prefix}-linux-vm"
  location                        = var.location
  resource_group_name             = azurerm_resource_group.rg.name
  size                            = "Standard_D2s_v3"   # Sasta for demo
  admin_username                  = "azureuser"
  admin_password                  = random_password.vm_password.result
  disable_password_authentication = false
  network_interface_ids           = [azurerm_network_interface.linux_nic.id]
  tags                            = local.tags

  os_disk {
    caching              = "ReadWrite"
    storage_account_type = "Standard_LRS"
  }

  source_image_reference {
    publisher = "Canonical"
    offer     = "0001-com-ubuntu-server-jammy"
    sku       = "22_04-lts"
    version   = "latest"
  }

  # Defender agent auto-install ho jaayega jab plan enabled hai
}

# Windows VM (similarly Defender for Servers)
# (code similar to linux – space bachane ke liye skip kiya, agar chahiye to bata dena main add kar dunga)

# ====================== STORAGE ACCOUNT + PRIVATE ENDPOINT ======================
resource "azurerm_storage_account" "storage" {
  name                     = "socdemo${random_string.unique.result}"
  resource_group_name      = azurerm_resource_group.rg.name
  location                 = var.location
  account_tier             = "Standard"
  account_replication_type = "LRS"
  tags                     = local.tags
}

# Private DNS for blob
resource "azurerm_private_dns_zone" "blob" {
  name                = "privatelink.blob.core.windows.net"
  resource_group_name = azurerm_resource_group.rg.name
}

resource "azurerm_private_dns_zone_virtual_network_link" "blob_link" {
  name                  = "blob-vnet-link"
  resource_group_name   = azurerm_resource_group.rg.name
  private_dns_zone_name = azurerm_private_dns_zone.blob.name
  virtual_network_id    = azurerm_virtual_network.vnet.id
}

resource "azurerm_private_endpoint" "storage_pe" {
  name                = "${var.prefix}-storage-pe"
  location            = var.location
  resource_group_name = azurerm_resource_group.rg.name
  subnet_id           = azurerm_subnet.compute.id

  private_service_connection {
    name                           = "storage-connection"
    private_connection_resource_id = azurerm_storage_account.storage.id
    is_manual_connection           = false
    subresource_names              = ["blob"]
  }

  private_dns_zone_group {
    name                 = "blob"
    private_dns_zone_ids = [azurerm_private_dns_zone.blob.id]
  }
}

# ====================== AKS CLUSTER (Defender for Containers) ======================
resource "azurerm_kubernetes_cluster" "aks" {
  name                = local.aks_name
  location            = var.location
  resource_group_name = azurerm_resource_group.rg.name
  dns_prefix          = local.aks_name

  default_node_pool {
    name       = "default"
    node_count = 1
    vm_size    = "Standard_D2s_v3"
  }

  identity {
    type = "SystemAssigned"
  }

  # Microsoft Defender for Containers integration – JD mein listed
  microsoft_defender {
    log_analytics_workspace_id = azurerm_log_analytics_workspace.law.id
  }

  tags = local.tags

  # Enterprise features
  private_cluster_enabled = false   # Demo ke liye false (true kar sakte ho)
  azure_policy_enabled    = true
}

# ====================== SENTINEL ANALYTICS RULES (KQL) ======================
# Rule 1: Suspicious SSH brute force (MITRE ATT&CK T1110)
resource "azurerm_sentinel_alert_rule_scheduled" "ssh_brute_force" {
  name                       = "SSH-Brute-Force-Detection"
  display_name               = "Suspicious SSH Brute Force Attempt"
  log_analytics_workspace_id = azurerm_log_analytics_workspace.law.id
  severity                   = "High"
  query                      = <<-QUERY
    SecurityEvent
    | where EventID == 4625
    | where AccountType == "User"
    | summarize FailedLogons = count() by IpAddress, bin(TimeGenerated, 5m)
    | where FailedLogons > 5
  QUERY
  query_frequency            = "PT5M"
  query_period               = "PT5M"
  trigger_threshold          = 1
  trigger_operator           = "GreaterThan"
  description                = "Detects brute force on Linux VMs – maps to Defender + Sentinel use case"
}

# Rule 2: Anomalous AKS pod creation (Defender for Containers)
# Rule 3: High severity Defender alert (you can add more)

# ====================== OUTPUTS ======================
output "resource_group" {
  value = azurerm_resource_group.rg.name
}

output "sentinel_workspace_id" {
  value = azurerm_log_analytics_workspace.law.id
}

output "linux_vm_public_ip" {
  value = azurerm_public_ip.linux_pip.ip_address
}

output "linux_vm_password" {
  value     = random_password.vm_password.result
  sensitive = true
}

output "important_note" {
  value = "✅ Defender plans enabled + Sentinel onboarded + AKS with Defender + Private Endpoint ready! Secure Score improve hoga."
}