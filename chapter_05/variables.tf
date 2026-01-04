variable "namespace" {
  description = "The project namespace to ue for unique resource naming"
  type        = string
}

variable "region" {
  description = "AWS region"
  default     = "ca-central-1"
  type        = string
}

variable "profile" {
  description = "AWS profile"
  type        = string
}
