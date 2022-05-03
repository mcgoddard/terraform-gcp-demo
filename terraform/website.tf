resource "google_storage_bucket" "static-site" {
  name          = var.bucket_name
  location      = "EU"
  force_destroy = true

  website {
    main_page_suffix = "index.html"
    not_found_page   = "index.html"
  }
}

resource "null_resource" "website-files" {
  triggers = {
    dist_hash = sha1(join("", [for f in fileset("../dist", "*") : filesha1("../dist/${f}")]))
  }

  provisioner "local-exec" {
    command = "gsutil rsync -d -r ../dist ${google_storage_bucket.static-site.url}"
    interpreter = [
      "bash", "-c"
    ]
  }
}

resource "google_storage_default_object_acl" "website_acl" {
  bucket      = google_storage_bucket.static-site.name
  role_entity = ["READER:allUsers"]
}
