variable "location" {
  default = "Central India"
}

variable "resource_group_name" {
  default = "rg-devsecops-container-platform"
}

variable "admin_username" {
  default = "azureuser"
}

variable "ssh_public_key_path" {
  default = "~/.ssh/id_rsa.pub"
}

variable "allowed_source_ip" {
  description = "Your public IP for SSH access to runner VM. Example: x.x.x.x/32"
  type        = string
}

variable "github_repo_url" {
  description = "GitHub repo URL for self-hosted runner"
  default     = "https://github.com/rohnrd/enterprise-devsecops-platform"
}

variable "github_runner_token" {
  description = "Temporary GitHub self-hosted runner registration token"
  type        = string
  sensitive   = true
}

variable "container_image" {
  description = "Container image for Azure Container App"
  default     = "ghcr.io/rohnrd/enterprise-devsecops-platform:latest"
}