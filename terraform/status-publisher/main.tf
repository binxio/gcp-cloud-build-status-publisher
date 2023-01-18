data "google_project" "project" {
  project_id = var.project_id
}


## Cloud Build notification topic
resource "google_pubsub_topic" "cloud_builds" {
  project = var.project_id
  name    = "cloud-builds"
}

## Status publisher subscription
resource "google_pubsub_subscription" "cloud_builds_status_listener" {
  project              = var.project_id
  name                 = "cloud-builds-status"
  topic                = "cloud-builds"
  ack_deadline_seconds = 60

  push_config {
    push_endpoint = google_cloud_run_service.build_status_publisher.status[0].url

    oidc_token {
      service_account_email = google_service_account.build_status_listener.email
    }
  }

  depends_on = [
    google_pubsub_topic.cloud_builds,
  ]
}

resource "google_service_account" "build_status_listener" {
  project      = var.project_id
  account_id   = "build-status-listener"
  display_name = "Build status listener"
}

# Allow subscription service account to be used by Pub/Sub.
resource "google_service_account_iam_member" "build_status_listener_impersonate_pubsub" {
  service_account_id = google_service_account.build_status_listener.name
  role               = "roles/iam.serviceAccountTokenCreator"
  member             = "serviceAccount:service-${data.google_project.project.number}@gcp-sa-pubsub.iam.gserviceaccount.com"
}

# Allow subscription service account to trigger Cloud Run instance.
resource "google_cloud_run_service_iam_member" "build_status_publisher_invoker_build_status_listener" {
  project  = var.project_id
  location = var.region
  service  = google_cloud_run_service.build_status_publisher.name
  role     = "roles/run.invoker"
  member   = "serviceAccount:${google_service_account.build_status_listener.email}"
}


## Status publisher instance
resource "google_cloud_run_service" "build_status_publisher" {
  project  = var.project_id
  location = var.region
  name     = "build-status-publisher"

  template {
    spec {
      service_account_name = google_service_account.build_status_publisher.email

      containers {
        image = "gcr.io/binx-io-public/gcp-cloud-build-status-publisher:v1.0.0"

        resources {
          limits = {
            "cpu"    = "1000m"
            "memory" = "512Mi"
          }
        }
      }
    }
  }

  traffic {
    percent         = 100
    latest_revision = true
  }

  metadata {
    annotations = {
      "run.googleapis.com/ingress" = "internal"
    }
  }

  autogenerate_revision_name = true
}

resource "google_service_account" "build_status_publisher" {
  project      = var.project_id
  account_id   = "build-status-publisher"
  display_name = "Build status publisher"
}

resource "google_project_iam_member" "build_status_publisher_log_writer" {
  project = var.project_id
  role    = "roles/logging.logWriter"
  member  = "serviceAccount:${google_service_account.build_status_publisher.email}"
}

# Grant permissions to publish custom metrics
resource "google_project_iam_member" "build_status_publisher_metric_writer" {
  project = var.project_id
  role    = "roles/monitoring.metricWriter"
  member  = "serviceAccount:${google_service_account.build_status_publisher.email}"
}
