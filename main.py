import base64
import json
import os
import logging
import datetime

from flask import Flask, request

from google.cloud.monitoring_v3.types.common import timestamp_pb2 as gm_timestamp
from google.cloud import monitoring_v3

# Setup logging
if os.getenv("LOGS_TARGET") == "GCP":
    import google.cloud.logging
    client = google.cloud.logging.Client()
    client.setup_logging()
else:
    import sys
    logging.basicConfig(stream=sys.stdout, level=logging.DEBUG)

logger = logging.getLogger('app')

def get_project_id() -> str:
    import urllib.error
    try:
        import urllib.request
        req = urllib.request.Request("http://metadata.google.internal/computeMetadata/v1/project/project-id")
        req.add_header("Metadata-Flavor", "Google")
        project_id = urllib.request.urlopen(req).read().decode()
    except urllib.error.URLError:
        logger.warning("Failed to look up project id through compute engine metadata. Are you running on Cloud Run?", exc_info=1)

        # Assuming local run..
        logger.info("Defaulting to provided project id..")
        project_id = os.getenv("PROJECT_ID")
    
    if not project_id:
        logger.error("Invalid runtime: unable to get project id. Are you running on Cloud Run?")
        raise EnvironmentError("GCP Project ID is not available. Run on GCP or supply environment variable 'PROJECT_ID'.")
    
    return project_id

# Try parse location from source resource id: projects/../locations/../builds/..
def get_event_location(event: dict) -> str:
    location = "global" # Assuming global build as a default
    if "name" in event:
        name = event["name"]
        if "/locations/" in name:
            location = name.split("/")[3]
    
    return location

project = get_project_id()
app = Flask(__name__)

@app.route("/", methods=["POST"])
def index():
    envelope = request.get_json()
    if not envelope:
        logger.error("no Pub/Sub message received")
        return "Bad Request: no Pub/Sub message received", 400

    if not isinstance(envelope, dict) or "message" not in envelope:
        logger.error("invalid Pub/Sub message format")
        return "Bad Request: invalid Pub/Sub message format", 400

    pubsub_message = envelope["message"]
    if not isinstance(pubsub_message, dict) or "data" not in pubsub_message:
        logger.error("no Pub/Sub message data received")
        return "Bad Request: no Pub/Sub message data received", 400

    event_string = base64.b64decode(pubsub_message["data"]).decode("utf-8").strip()
    event = json.loads(event_string)

    if (
            "id" not in event or
            "status" not in event or
            "projectId" not in event  or
            "buildTriggerId" not in event 
        ):
        logger.warning("invalid event, missing required attribute id/status/projectId/buildTriggerId. Event=%s", json.dumps(event))
        return "Bad request: invalid event, missing required attribute id/status/projectId/buildTriggerId", 400

    build_id = event["id"]
    build_status = event["status"]
    logger.info("Received build notification. Build=%s, Status=%s", build_id, build_status)

    # Get last event time, default to pub/sub message time.
    event_time = pubsub_message["publishTime"]
    if "finishTime" in event:
        event_time = event["finishTime"]
    elif "startTime" in event:
        event_time = event["startTime"]
    elif "createTime" in event:
        event_time = event["createTime"]
    
    event_timestamp = gm_timestamp.Timestamp
    gm_timestamp.Timestamp.FromJsonString(self=event_timestamp, value=event_time)

    # Assert event time within last day.
    event_process_delta:datetime.timedelta = gm_timestamp.Timestamp.ToDatetime(self=event_timestamp, tzinfo=datetime.timezone.utc) - datetime.datetime.now(tz=datetime.timezone.utc)
    if event_process_delta.total_seconds() > 0.0:
        logger.warning("invalid event, future event. Event=%s", json.dumps(event))
        return "Bad request: invalid event, future event", 400
    elif event_process_delta.total_seconds() < -86400.0:
        logger.warning("Received outdated event, discarding event. Event=%s", json.dumps(event))
        return ("", 204)

    series = monitoring_v3.TimeSeries({
        "metric": {
            "type": "custom.googleapis.com/build/status_count",
            "labels": {
                "status": build_status
            }
        },
        "resource": {
            "type": "generic_task",
            "labels": {
                "project_id": project,
                "location": get_event_location(event),
                "namespace": event["projectId"],
                "job": event["buildTriggerId"],
                "task_id": build_id
            }
        },
        "points": [
            {
                "interval": {
                    "end_time": {
                        "seconds": event_timestamp.seconds,
                        "nanos": event_timestamp.nanos
                    }
                },
                "value": {
                    "int64_value": 1
                }
            }
        ]
    })
    
    if "failureInfo" in event:
        failure_info = event["failureInfo"]

        if "type" in failure_info:
            series.metric.labels["failure_type"] = failure_info["type"]
    
        if "detail" in failure_info:
            series.metric.labels["failure_detail"] = json.dumps(failure_info["detail"])

    client = monitoring_v3.MetricServiceClient()
    client.create_time_series(name=f"projects/{project}", time_series=[series])

    return ("", 204)




if __name__ == "__main__":
    PORT = int(os.getenv("PORT")) if os.getenv("PORT") else 8080

    # This is used when running locally. Gunicorn is used to run the
    # application on Cloud Run. See entrypoint in Dockerfile.
    app.run(host="127.0.0.1", port=PORT, debug=True)
