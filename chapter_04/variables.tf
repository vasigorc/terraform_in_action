variable "namespace" {
  description = "The project namespace to ue for unique resource naming"
  type        = string
}

variable "ssh_keypair" {
  description = "SSH keypair to use for EC2 instance"
  default     = null
  type        = string
}

variable "region" {
  description = "AWS region"
  default     = "ca-central-1"
  type        = string
}
