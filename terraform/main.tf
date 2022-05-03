terraform {
  required_providers {
    google = {
      source  = "hashicorp/google"
      version = "4.18.0"
    }
  }
}

provider "google" {
  credentials = file(var.credentials)

  project = var.project_id
  region  = "europe-west2"
  zone    = "europe-west2-a"
}
