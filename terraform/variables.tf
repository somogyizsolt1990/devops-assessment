variable "kubeconfig_path" {
  description = "Path to the kubeconfig file."
  type        = string
  default     = "~/.kube/config"
}

variable "kube_context" {
  description = "kubeconfig context to deploy to. No default on purpose: nothing is deployed to whatever context happens to be current."
  type        = string
}

variable "namespace" {
  description = "Namespace of the release. Created and owned by Terraform."
  type        = string

  validation {
    condition     = can(regex("^[a-z0-9]([-a-z0-9]{0,61}[a-z0-9])?$", var.namespace))
    error_message = "namespace must be a valid DNS-1123 label: lowercase letters, digits and '-', at most 63 characters."
  }
}

variable "environment" {
  description = "Value of the ENVIRONMENT variable inside the application."
  type        = string

  validation {
    condition     = contains(["dev", "staging", "prod"], var.environment)
    error_message = "environment must be one of: dev, staging, prod."
  }
}

variable "image_tag" {
  description = "Container image tag to deploy. Set by the caller (CI) on every deployment."
  type        = string

  validation {
    condition     = length(trimspace(var.image_tag)) > 0 && var.image_tag != "latest"
    error_message = "image_tag must not be empty or \"latest\"."
  }
}
