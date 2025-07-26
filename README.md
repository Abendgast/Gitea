# 🚀 Gitea Infrastructure on AWS

<div align="center">

![AWS](https://img.shields.io/badge/AWS-%23FF9900.svg?style=for-the-badge&logo=amazon-aws&logoColor=white)
![Terraform](https://img.shields.io/badge/terraform-%235835CC.svg?style=for-the-badge&logo=terraform&logoColor=white)
![Docker](https://img.shields.io/badge/docker-%230db7ed.svg?style=for-the-badge&logo=docker&logoColor=white)
![Gitea](https://img.shields.io/badge/Gitea-34495E?style=for-the-badge&logo=gitea&logoColor=5D9425)
![Jenkins](https://img.shields.io/badge/jenkins-%232C5263.svg?style=for-the-badge&logo=jenkins&logoColor=white)

*Production-ready Gitea Git hosting platform deployed on AWS with automated CI/CD*

</div>

---

## 📋 Table of Contents

- [🧩 Infrastructure Components](#-infrastructure-components)
- [🔧 Application Details](#-application-details)
- [✨ Key Features](#-key-features)
- [🚀 Quick Start](#-quick-start)
- [📊 Monitoring](#-monitoring)
- [🔒 Security](#-security)


---

## 🧩 Infrastructure Components

### 🐳 **Container Orchestration**

| Service | Purpose | Key Features |
|---------|---------|--------------|
| **Amazon ECS** | Container orchestration platform | Fargate serverless, auto-scaling, health checks |
| **Amazon ECR** | Private Docker registry | Vulnerability scanning, lifecycle policies, secure access |
| **ECS Service** | Manages container deployment | Rolling updates, desired count management |

### 💾 **Storage & Database**

<table>
<tr>
<td width="50%">

**🗄️ Amazon EFS**
- **Shared persistent storage**
- Multi-AZ availability
- Encryption in transit/rest
- POSIX-compliant file system

</td>
<td width="50%">

**🐘 Amazon RDS PostgreSQL**
- **Managed database service**
- Automated backups
- Multi-AZ deployment
- Performance monitoring

</td>
</tr>
</table>

### 🔐 **Security & Configuration**

> **AWS Systems Manager Parameter Store**
> 
> Centralized, encrypted storage for:
> - Database credentials
> - API keys and secrets
> - Application configuration
> - Environment variables

### 🌐 **Load Balancing & SSL**

```yaml
Traffic Flow:
Internet → Route 53 → Application Load Balancer → ECS Containers
         ↓
    SSL Certificate (ACM) → HTTPS Encryption
```

- **Application Load Balancer**: Health checks, traffic distribution
- **AWS Certificate Manager**: Automated SSL certificate management
- **Route 53**: DNS management with failover capabilities

### ⚙️ **CI/CD Pipeline**

<div align="center">

**Jenkins on EC2**

![Jenkins Flow](https://img.shields.io/badge/Source%20Code-Gitea-green?style=flat-square) → ![Build](https://img.shields.io/badge/Build-Jenkins-blue?style=flat-square) → ![Registry](https://img.shields.io/badge/Push-ECR-orange?style=flat-square) → ![Deploy](https://img.shields.io/badge/Deploy-ECS-red?style=flat-square)

</div>

---

## 🔧 Application Details

### 🦊 **Gitea Configuration**

```yaml
Runtime Environment:
  Platform: ECS Fargate
  Port: 3000 (HTTP)
  Database: PostgreSQL with SSL
  Storage: EFS mounted at /data
  Authentication: Parameter Store secrets
  
Features:
  ✅ Git over HTTPS
  ✅ Web interface
  ✅ Issue tracking
  ✅ Pull requests
  ✅ SSH 
```

### 🔨 **Jenkins Configuration**

```yaml
Infrastructure:
  Instance: EC2 t3.medium (Ubuntu 22.04)
  Container: Jenkins LTS in Docker
  Backup: Automated daily S3 sync
  
Capabilities:
  ✅ Docker-in-Docker builds
  ✅ ECR integration
  ✅ AWS CLI access
  ✅ Automatic restoration
```



---

## ✨ Key Features

<table>
<tr>
<td width="50%">

### 🔄 **High Availability**
- ✅ Multi-AZ deployment
- ✅ Auto-scaling containers
- ✅ Database redundancy
- ✅ Load balancer health checks

### 🔒 **Enterprise Security**
- ✅ Encrypted storage & transit
- ✅ IAM role-based access
- ✅ Private container registry
- ✅ Network segmentation

</td>
<td width="50%">

### 📈 **Scalability**
- ✅ Serverless containers (Fargate)
- ✅ Auto-growing file system
- ✅ Database auto-scaling
- ✅ Elastic load balancing

### 💾 **Backup & Recovery**
- ✅ Automated Jenkins backups
- ✅ RDS point-in-time recovery
- ✅ EFS built-in redundancy
- ✅ Infrastructure as Code

</td>
</tr>
</table>

---

## 🚀 Quick Start

### Prerequisites

```bash
# Required tools
terraform --version  # >= 1.0
aws --version        # AWS CLI configured
```

### Deployment Steps

<details>
<summary><b>1️⃣ Deploy S3 Storage (Jenkins Backups)</b></summary>

```bash
cd jenkins-s3/
terraform init
terraform plan
terraform apply
```
</details>

<details>
<summary><b>2️⃣ Deploy Gitea Infrastructure</b></summary>

```bash
cd ../gitea/
terraform init
terraform plan
terraform apply
# Note: Creates ECR, ECS, EFS, RDS, IAM roles
```
</details>

<details>
<summary><b>3️⃣ Deploy Load Balancer & SSL</b></summary>

```bash
cd ../gitea-alb/
terraform init
terraform plan
terraform apply
# Outputs: DNS name and HTTPS URL
```
</details>

<details>
<summary><b>4️⃣ Deploy Jenkins CI/CD</b></summary>

```bash
cd ../jenkins-ec2/
terraform init
terraform plan
terraform apply
# Outputs: Jenkins URL and SSH command
```
</details>

### 🎉 **Access Your Services**

| Service | URL | Purpose |
|---------|-----|---------|
| **Gitea** | `https://my-gitea.pp.ua` | Git hosting & web interface |
| **Jenkins** | `http://jenkins-gitea.pp.ua:8080` | CI/CD pipeline management |

---

## 📊 Monitoring

### CloudWatch Integration

```yaml
Monitoring Stack:
  📈 Container Insights: ECS cluster metrics
  📋 Log Groups: Centralized application logs  
  🚨 Health Checks: ALB target health monitoring
  📊 Custom Metrics: Database performance insights
```

### Key Metrics to Watch

- ECS service CPU/Memory utilization
- RDS connection count and query performance  
- EFS throughput and IOPS
- ALB response times and error rates

---

## 🔒 Security

### 🛡️ **Security Best Practices Implemented**

| Layer | Security Measures |
|-------|------------------|
| **Network** | VPC isolation, Security Groups, Private subnets |
| **Data** | Encryption at rest (EFS, RDS, S3), SSL/TLS in transit |
| **Access** | IAM roles, least privilege principle, no hardcoded secrets |
| **Container** | Private ECR, vulnerability scanning, non-root users |

### 🔐 **Secrets Management**

All sensitive data is stored in **AWS Systems Manager Parameter Store**:
- Database credentials (encrypted)
- Application secrets and API keys
- SSL certificates and domain configuration

---

<div align="center">

### 💡 **Need Help?**

[![Issues](https://img.shields.io/badge/Issues-GitHub-red?style=for-the-badge&logo=github)](../../issues)
[![Documentation](https://img.shields.io/badge/Docs-AWS-orange?style=for-the-badge&logo=amazon-aws)](https://docs.aws.amazon.com/)
[![Terraform](https://img.shields.io/badge/Terraform-Docs-purple?style=for-the-badge&logo=terraform)](https://registry.terraform.io/providers/hashicorp/aws/latest/docs)

---

**Built with ❤️ using AWS + Terraform + Open Source**

*This infrastructure follows AWS Well-Architected Framework principles*

</div># AWS Infrastructure for Gitea and Jenkins

This infrastructure project provisions a complete AWS-based environment for running Gitea (a self-hosted Git service) and Jenkins (a CI/CD automation server) using Terraform. It includes container orchestration, persistent storage, secret management, backups, and secure public access via HTTPS.

## 🗂️ Components Overview

| Component          | Purpose                                                                 |
|--------------------|-------------------------------------------------------------------------|
| **ECS**            | Runs the Gitea container using AWS Fargate                              |
| **ECR**            | Stores the custom Gitea container image                                 |
| **EFS**            | Provides persistent, encrypted storage for Gitea                        |
| **RDS**            | PostgreSQL backend for Gitea database                                   |
| **S3**             | Stores Jenkins backups, versioned and encrypted                         |
| **IAM**            | Grants EC2 and ECS access to needed services (S3, ECR, etc.)            |
| **Parameter Store**| Holds all Gitea secrets and credentials securely                        |
| **ALB + ACM**      | Public HTTPS access to Gitea via a load balancer and a self-signed cert |
| **Route 53**       | DNS zone management and custom domain routing                           |
| **EC2**            | Runs the Jenkins server via Docker, initialized via `user_data`         |

---

## 🚀 Gitea Deployment (ECS + Fargate)

- Gitea runs inside a container defined in `task-definition.json`, hosted on **ECS Fargate**.
- Application data is mounted via **EFS**, ensuring persistent `/data`.
- Secrets like DB credentials and admin account info are securely pulled from **SSM Parameter Store**.
- Public access is managed via **Application Load Balancer (ALB)** with:
  - Automatic HTTP → HTTPS redirection
  - Self-signed SSL certificate provisioned via **ACM**
  - Domain mapping via **Route 53**

---

## 🔧 Jenkins Deployment (EC2 + Docker)

- Jenkins runs in a Docker container on an **EC2 instance**, provisioned with:
  - SSH access
  - Docker and AWS CLI pre-installed
  - Automatic restore from **S3** if backup is available
- Daily backups are uploaded to **S3**, versioned and encrypted
- EC2 instance uses an **IAM role** with permissions to read/write S3 and access ECR

---

## 🔐 Secrets Management (Parameter Store)

Secrets are stored under `/gitea/` namespace and injected into the Gitea container at runtime:
- Database host, user, password
- Admin username, password, email
- Security keys (e.g. `SECRET_KEY`, `INSTALL_LOCK`)

---

## 📦 S3 Usage

- Bucket: `my-jenkins-storage`
- Used to store and version Jenkins backup data
- Public access is fully blocked
- Server-side encryption is enforced with AES256

---

## 📌 Additional Notes

- All services are deployed in `us-east-1`
- Default VPC and subnets are used for quick setup
- Jenkins can be accessed at `[http://<EC2_PUBLIC_IP>:8080](http://jenkins-gitea.pp.ua:8080`
- Gitea is available at `https://my-gitea.pp.ua`

