terraform {
  required_version = ">= 1.9.8, < 2.0.0"
  required_providers {
    google = {
      source  = "hashicorp/google"
      version = "= 6.15.0"
    }
  }
}
