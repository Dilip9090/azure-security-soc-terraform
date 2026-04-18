# azure-security-soc-terraform
End-to-End Azure Security SOC built with Terraform | Microsoft Sentinel + Defender for Cloud (CSPM + Containers) + Automated Threat Detection | Portfolio Project for Cloud Solution Architect (Security)


# Azure Security SOC - Terraform Implementation

**Enterprise-Grade Cloud Security Operations Center (SOC) on Microsoft Azure**

End-to-end Terraform project demonstrating real-world Azure Security architecture using **Microsoft Defender Suite + Sentinel**. Built as a portfolio project for **Cloud Solution Architect (Security)** roles at Microsoft.

![Secure Score Improvement](screenshots/secure-score-before-after.png)

## ✨ Key Features

- **IaC with Terraform** – Fully reproducible enterprise landing zone
- **Microsoft Sentinel** – SIEM + SOAR with custom Analytics Rules (MITRE ATT&CK mapped)
- **Microsoft Defender for Cloud** – Full CSPM (CloudPosture) + Defender for Servers
- **Defender for Containers** – AKS cluster with built-in threat protection
- **Defender for Storage** – Private Endpoint + malware scanning
- **Automated Threat Detection & Response** – KQL rules + simulated incident response
- **Secure by Design** – Private networking, NSG hardening, least privilege

## 🛠️ Tech Stack

- **IaC**: Terraform (azurerm ~>4.0)
- **Azure Services**: Microsoft Sentinel, Defender for Cloud (CSPM), Defender for Containers, Log Analytics, AKS, Private Endpoints
- **Security**: KQL, MITRE ATT&CK, Cloud Security Posture Management
- **Networking**: VNet, Subnet, NSG, Private DNS

## 📊 What This Demonstrates (Perfect for CSA Role)

- Enterprise-scale security architecture design
- Hands-on implementation of Microsoft Security tools listed in JD
- Threat detection, posture management & automated response
- Customer-facing POC / production-ready patterns
- Secure Score improvement & compliance best practices

## 🚀 Quick Start

```bash
1. Clone & configure
git clone https://github.com/YOURUSERNAME/azure-security-soc-terraform.git
cd azure-security-soc-terraform

2. Update variables.tf (your IP for SSH/RDP)
3. Login to Azure
az login

4. Deploy
terraform init
terraform validate
terraform plan
terraform apply -auto-approve
