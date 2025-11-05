# Log Sink for centralized logging (optional - writes to Cloud Logging by default)
resource "google_logging_project_sink" "app_logs" {
  count = var.environment == "prod" ? 1 : 0

  name        = "${var.service_name}-logs-${var.environment}"
  description = "Log sink for ${var.service_name} in ${var.environment}"
  destination = "logging.googleapis.com/projects/${var.project_id}/locations/global/buckets/_Default"

  filter = <<-EOT
    resource.type="cloud_run_revision"
    resource.labels.service_name="${var.cloud_run_service_name}"
  EOT

  unique_writer_identity = true
}

# Notification Channel (Email)
resource "google_monitoring_notification_channel" "email" {
  count = var.notification_email != "" ? 1 : 0

  display_name = "Email Notifications - ${var.environment}"
  type         = "email"
  labels = {
    email_address = var.notification_email
  }

  enabled = true
}

# Alert Policy: High Error Rate
resource "google_monitoring_alert_policy" "high_error_rate" {
  count = var.notification_email != "" ? 1 : 0

  display_name = "[${upper(var.environment)}] High Error Rate - ${var.service_name}"
  combiner     = "OR"

  conditions {
    display_name = "Error rate above 5%"

    condition_threshold {
      filter          = <<-EOT
        resource.type="cloud_run_revision"
        resource.labels.service_name="${var.cloud_run_service_name}"
        metric.type="run.googleapis.com/request_count"
        metric.labels.response_code_class="5xx"
      EOT
      duration        = "300s"
      comparison      = "COMPARISON_GT"
      threshold_value = 5

      aggregations {
        alignment_period   = "60s"
        per_series_aligner = "ALIGN_RATE"
      }
    }
  }

  notification_channels = [google_monitoring_notification_channel.email[0].id]

  alert_strategy {
    auto_close = "1800s"
  }

  documentation {
    content   = "Error rate for ${var.service_name} in ${var.environment} has exceeded 5%. Check logs at https://console.cloud.google.com/logs"
    mime_type = "text/markdown"
  }
}

# Alert Policy: High Latency
resource "google_monitoring_alert_policy" "high_latency" {
  count = var.notification_email != "" ? 1 : 0

  display_name = "[${upper(var.environment)}] High Latency - ${var.service_name}"
  combiner     = "OR"

  conditions {
    display_name = "P95 latency above 5 seconds"

    condition_threshold {
      filter          = <<-EOT
        resource.type="cloud_run_revision"
        resource.labels.service_name="${var.cloud_run_service_name}"
        metric.type="run.googleapis.com/request_latencies"
      EOT
      duration        = "300s"
      comparison      = "COMPARISON_GT"
      threshold_value = 5000

      aggregations {
        alignment_period     = "60s"
        per_series_aligner   = "ALIGN_DELTA"
        cross_series_reducer = "REDUCE_PERCENTILE_95"
        group_by_fields      = ["resource.service_name"]
      }
    }
  }

  notification_channels = [google_monitoring_notification_channel.email[0].id]

  alert_strategy {
    auto_close = "1800s"
  }

  documentation {
    content   = "Request latency (P95) for ${var.service_name} in ${var.environment} has exceeded 5 seconds."
    mime_type = "text/markdown"
  }
}

# Alert Policy: Service Down
resource "google_monitoring_alert_policy" "service_down" {
  count = var.notification_email != "" && var.environment == "prod" ? 1 : 0

  display_name = "[${upper(var.environment)}] Service Down - ${var.service_name}"
  combiner     = "OR"

  conditions {
    display_name = "No requests in 5 minutes"

    condition_threshold {
      filter          = <<-EOT
        resource.type="cloud_run_revision"
        resource.labels.service_name="${var.cloud_run_service_name}"
        metric.type="run.googleapis.com/request_count"
      EOT
      duration        = "300s"
      comparison      = "COMPARISON_LT"
      threshold_value = 1

      aggregations {
        alignment_period   = "60s"
        per_series_aligner = "ALIGN_RATE"
      }
    }
  }

  notification_channels = [google_monitoring_notification_channel.email[0].id]

  alert_strategy {
    auto_close = "1800s"
  }

  documentation {
    content   = "🚨 ${var.service_name} in ${var.environment} appears to be down - no requests received in the last 5 minutes."
    mime_type = "text/markdown"
  }
}

# Dashboard (Optional)
resource "google_monitoring_dashboard" "app_dashboard" {
  dashboard_json = jsonencode({
    displayName = "${var.service_name} - ${var.environment}"
    mosaicLayout = {
      columns = 12
      tiles = [
        {
          width  = 6
          height = 4
          widget = {
            title = "Request Count"
            xyChart = {
              dataSets = [{
                timeSeriesQuery = {
                  timeSeriesFilter = {
                    filter = "resource.type=\"cloud_run_revision\" resource.labels.service_name=\"${var.cloud_run_service_name}\" metric.type=\"run.googleapis.com/request_count\""
                    aggregation = {
                      alignmentPeriod  = "60s"
                      perSeriesAligner = "ALIGN_RATE"
                    }
                  }
                }
              }]
            }
          }
        },
        {
          xPos   = 6
          width  = 6
          height = 4
          widget = {
            title = "Request Latency (P50, P95, P99)"
            xyChart = {
              dataSets = [{
                timeSeriesQuery = {
                  timeSeriesFilter = {
                    filter = "resource.type=\"cloud_run_revision\" resource.labels.service_name=\"${var.cloud_run_service_name}\" metric.type=\"run.googleapis.com/request_latencies\""
                    aggregation = {
                      alignmentPeriod    = "60s"
                      perSeriesAligner   = "ALIGN_DELTA"
                      crossSeriesReducer = "REDUCE_PERCENTILE_95"
                    }
                  }
                }
              }]
            }
          }
        }
      ]
    }
  })
}
