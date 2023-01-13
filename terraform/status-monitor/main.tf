## Metrics scope
locals {
  # Target project is implicitly included in metrics scope.
  monitored_projects = [for p in var.monitored_projects : p if p != var.project_id]
}

resource "google_monitoring_monitored_project" "project" {
  for_each = toset(local.monitored_projects)

  metrics_scope = var.project_id
  name          = each.value
}


## Email notification channel
resource "google_monitoring_notification_channel" "email" {
  project      = var.project_id
  display_name = "Build status emails"
  type         = "email"
  labels = {
    email_address = var.notification_email
  }
}


## Failed build alert, sends an email for every failed build.
resource "google_monitoring_alert_policy" "alert_policy" {
  project = var.project_id

  display_name = "Build failure"

  notification_channels = [
    google_monitoring_notification_channel.email.id,
  ]

  documentation {
    mime_type = "text/markdown"
    content   = <<EOT
    A build has failed!
    
    Troublsheet and resolve using the logs: https://console.cloud.google.com/cloud-build/builds/$${resource.label.task_id}?project=$${resource.label.namespace}
    EOT
  }

  combiner = "OR"
  conditions {
    display_name = "failed_job"

    condition_threshold {

      # Consider using a filter to only look at specific projects using "resource.label.namespace = 'project-x'"
      filter   = <<EOT
      resource.type = "generic_task" AND metric.type = "custom.googleapis.com/build/status_count" AND metric.labels.status = "FAILURE"
      EOT
      duration = "0s"
      aggregations {
        alignment_period   = "60s"
        per_series_aligner = "ALIGN_MEAN"

        cross_series_reducer = "REDUCE_SUM"
        group_by_fields = [
          "resource.label.namespace", # Source project
          "resource.label.job",       # Source trigger ID
          "resource.label.task_id",   # Source job ID
        ]
      }

      comparison = "COMPARISON_GT"
      trigger {
        count = 1
      }
    }
  }

  alert_strategy {
    auto_close = "1800s"
  }
}
