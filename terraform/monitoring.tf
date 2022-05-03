resource "google_monitoring_alert_policy" "bad_requests_alert" {
  display_name = "Unsuccessful Request"
  combiner     = "OR"
  conditions {
    display_name = "test condition"
    condition_monitoring_query_language {
      query    = <<EOF
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
