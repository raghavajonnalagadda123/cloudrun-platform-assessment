variable "project_id" {
  type = string
}

variable "region" {
  type = string
}

variable "service_name" {
  type = string
}

variable "environment" {
  type = string

  validation {
    condition     = contains(["dev", "prod"], var.environment)
    error_message = "environment must be dev or prod."
  }
}

variable "image" {
  type        = string
  description = "Immutable Artifact Registry image reference."

  validation {
    condition     = can(regex("@sha256:[a-f0-9]{64}$", var.image))
    error_message = "image must be pinned to a sha256 digest."
  }
}

variable "cpu" {
  type    = string
  default = "1"
}

variable "memory" {
  type    = string
  default = "512Mi"
}

variable "timeout" {
  type    = string
  default = "30s"
}

variable "max_instance_request_concurrency" {
  type    = number
  default = 80
}

variable "min_instance_count" {
  type    = number
  default = 0
}

variable "max_instance_count" {
  type    = number
  default = 10
}

variable "ingress" {
  type    = string
  default = "INGRESS_TRAFFIC_INTERNAL_ONLY"

  validation {
    condition = contains([
      "INGRESS_TRAFFIC_ALL",
      "INGRESS_TRAFFIC_INTERNAL_ONLY",
      "INGRESS_TRAFFIC_INTERNAL_LOAD_BALANCER"
    ], var.ingress)
    error_message = "Unsupported Cloud Run ingress value."
  }
}

variable "allow_unauthenticated" {
  type        = bool
  default     = false
  description = "Enable only when the selected ingress architecture intentionally permits public invocation."
}

variable "runtime_service_account_id" {
  type = string
}

variable "secret_env" {
  description = "Environment variable names mapped to Secret Manager secret IDs and versions; no secret payloads."

  type = map(object({
    secret_id = string
    version   = optional(string, "latest")
  }))

  default = {}
}

variable "labels" {
  type    = map(string)
  default = {}
}
