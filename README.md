# Cloud Build Status Publisher

[Google Cloud Build](https://cloud.google.com/build) supports [Cloud Build notifiers](https://cloud.google.com/build/docs/configuring-notifications/notifiers) to notify you of completed builds. These notifiers act on the [Cloud Build notifications](https://cloud.google.com/build/docs/subscribe-build-notifications).

To send an email, the notifier needs an SMTP server, and you need to configure an account to send emails from. This is quite a pain to manage. Gladly, [Cloud Monitoring](https://cloud.google.com/monitoring) offers notification channels as well. These channels are easier to maintain, since they don't require any SMTP configuration for sending emails.

Cloud Monitoring notification channels are triggered by Cloud Monitoring metrics. Cloud Build doesn't provide this (yet?). Therefore, this repository defines a container that publishes the build status as a metric.

## Build status metric

The metric is publishes as a custom metric: `custom.googleapis.com/build/status_count`.

The status is published as a metric label:
* status, one of queued, working, failure, succeeded
* failure_type, set to build failure type, when build status is failure
* failure_detail, set to build failure details, when build status is failure

The metric is associated with a [generic task](https://cloud.google.com/monitoring/api/resources#tag_generic_task) resource:
* project_id, derived from metadata server
* location, derived from build trigger location
* namespace, derived from build trigger project
* job, build trigger id
* task_id, build id

**Remark** Note that old events (>24h) are discarded, as they are rejected by Cloud Monitoring.