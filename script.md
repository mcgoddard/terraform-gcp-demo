# Prerequisites

You will need:
- node (v14.18.3)
- npm (8.1.1)
- gcloud cli tools (379.0.0)
- terraform (v1.1.9)
- gcloud configured with an account for which you have admin
- a billing account with GCP (billing account ID to hand)

# Create an app to deploy

```bash
npm install -g @vue/cli
vue create hello-world
```

Open `hello-world` in vscode
```bash
npm run serve
```

Open localhost:8080 in browser
```bash
CMD+C
npm run build
```

# Configure gcloud

Switch gcloud config
```bash
gcloud config configurations activate personal
```

## Create project

Create project
```bash
gcloud projects create mg-iac-demo --name="IAC Demo"
gcloud config set project mg-iac-demo
```

## Add service account

Add service account
```bash
gcloud iam service-accounts create terraform --description="Service account to run terraform" --display-name="terraform"
gcloud projects add-iam-policy-binding mg-iac-demo --member="serviceAccount:terraform@mg-iac-demo.iam.gserviceaccount.com" --role='roles/editor'
mkdir terraform
gcloud iam service-accounts keys create terraform/creds.json --iam-account=terraform@mg-iac-demo.iam.gserviceaccount.com
gcloud alpha billing projects link mg-iac-demo --billing-account=<BILLING_ACCOUNT_ID>
```

# Start terraforming

```bash
touch terraform/main.tf
```

main.tf
```hcl
terraform {
  required_providers {
    google = {
      source = "hashicorp/google"
      version = "4.18.0"
    }
  }
}

provider "google" {
  credentials = file("creds.json")

  project = "mg-iac-demo"
  region  = "europe-west2"
  zone    =     "europe-west2-a"
}
```

## Init
```bash
terraform init
```

## Extras
```bash
terraform fmt
terraform validate
```

## Building some resources

vue.config.js
```js
publicPath: '/mg-iac-demo-site'
```

```bash
npm run build
```

website.tf
```hcl
resource "google_storage_bucket" "static-site" {
  name          = "mg-iac-demo-site"
  location      = "EU"
  force_destroy = true

  website {
    main_page_suffix = "index.html"
    not_found_page   = "index.html"
  }
}

resource "null_resource" "website-files" {
  provisioner "local-exec" {
    command = "gsutil rsync -d -r ../dist ${google_storage_bucket.static-site.url}"
    interpreter = ["bash", "-c"]
  }
  
  triggers = {
    dist_hash = sha1(join("", [for f in fileset("../dist", "*"): filesha1("../dist/${f}")]))
  }
}

resource "google_storage_default_object_acl" "website_acl" {
  bucket      = google_storage_bucket.static-site.name
  role_entity = ["READER:allUsers"]
}
```

```bash
terraform plan
```

```bash
terraform apply
```

Visit https://storage.googleapis.com/mg-iac-demo-site/index.html

## Some more resources

monitoring.tf
```hcl
resource "google_monitoring_alert_policy" "bad_requests_alert" {
  display_name = "Unsuccessful Requests"
  combiner     = "OR"
  conditions {
    display_name = "test condition"
    condition_monitoring_query_language {
      query = <<EOF
fetch gcs_bucket
| metric 'storage.googleapis.com/api/request_count'
| filter (bucket_name = '${google_storage_bucket.static-site.name}')
| filter (metric.response_code != 'OK')
| align rate(1m)
| every 1m
| group_by [], [value_request_count_aggregate: aggregate(value.request_count)] 
| condition val() >= cast_units(1.0, '1/s')
EOF
      duration = "60s"
      trigger {
          count = 1
      }
    }
  }
}
```

monitoring.tf
```hcl
resource "google_monitoring_dashboard" "site_dashboard" {
  dashboard_json = <<EOF
{
  "displayName": "Site bucket",
  "mosaicLayout": {
    "columns": 12,
    "tiles": [
      {
        "height": 4,
        "widget": {
          "alertChart": {
            "name": "${google_monitoring_alert_policy.bad_requests_alert.name}"
          }
        },
        "width": 6
      }
    ]
  }
}
EOF
}
```

# Another environment

## Local setup
```bash
mkdir ../backup
cp -r .terraform ../backup/.terraform
cp .terraform.lock.hcl ../backup/.terraform.lock.hcl
cp terraform.tfstate ../backup/terraform.tfstate
cp terraform.tfstate.backup ../backup/terraform.tfstate.backup
rm -rf .terraform .terraform.lock.hcl terraform.tfstate terraform.tfstate.backup
terraform init
```

```bash
terraform workspace new staging
```

## GCP setup
```bash
gcloud projects create mg-iac-demo-staging --name="IAC Demo staging"
gcloud config set project mg-iac-demo-staging
gcloud iam service-accounts create terraform --description="Service account to run terraform" --display-name="terraform"
gcloud projects add-iam-policy-binding mg-iac-demo-staging --member="serviceAccount:terraform@mg-iac-demo-staging.iam.gserviceaccount.com" --role='roles/editor'
gcloud iam service-accounts keys create creds_staging.json --iam-account=terraform@mg-iac-demo-staging.iam.gserviceaccount.com
gcloud alpha billing projects link mg-iac-demo-staging --billing-account=<BILLING_ACCOUNT_ID>
```

## Terraform vars
variables.tf
```hcl
variable "project_id" {
  type    = string
}

variable "credentials" {
  type    = string
  default = "creds.json"
}

variable "bucket_name" {
  type    = string
}
```

main.tf
```hcl
  credentials = file(var.credentials)

  project = var.project_id
```

website.tf
```hcl
  name          = var.bucket_name
```

prod.tfvars
```hcl
project_id = "mg-iac-demo"
credentials = "creds.json"
bucket_name = "mg-iac-demo-site"
```

staging.tfvars
```hcl
project_id = "mg-iac-demo-staging"
credentials = "creds_staging.json"
bucket_name = "mg-iac-demo-site-staging"
```

```bash
terraform apply -var-file="staging.tfvars"
```

# Cleaning up

## Destroying resources
```bash
terraform destroy -var-file="staging.tfvars"
```

## GCP
```bash
gcloud projects delete mg-iac-demo-staging
```

## Prod
```bash
rm -rf .terraform .terraform.lock.hcl terraform.tfstate terraform.tfstate.backup
cp -r ../backup/. .
terraform init
```

```bash
terraform workspace select default
```

```bash
terraform destroy -var-file="prod.tfvars"
gcloud projects delete mg-iac-demo
```
