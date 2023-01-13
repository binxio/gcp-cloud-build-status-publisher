variable "project_id" {
  description = "Project to deploy to e.g. `my-project`."
  type        = string
}

variable "region" {
  description = "Region to use e.g. `europe-west4`. Region must support Cloud Run, see https://cloud.google.com/run/docs/locations"
  type        = string
}
