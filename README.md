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

## Deployment

Use Terraform to configure the build status publishers in your environment.

```bash
cd terraform/status-publisher
terraform init
terraform apply -var='project_id="my-project-id"' -var='region="europe-west1"'
```

## Contributing

Feel free to submit a PR or fork and alter the code.

For local development, use `Make` to set up your environment.

```bash
make venv
PROJECT=your-google-project PORT=8080 make run
```

Now invoke the service by submitting a pub/sub payload to localhost:8080. An example payload is found in the `data`-folder.

```bash
curl -X POST -H "Content-Type: application/json" -d @data/pubsub_build_failure.json http://localhost:8080/
```
