variable "project_id" {
  description = "Project to deploy to e.g. `my-project`."
  type        = string
}

variable "monitored_projects" {
  description = "Projects to monitor e.g. `[ 'dev-project', 'production-project' ]`."
  type        = list(string)
  default     = []
}

variable "notification_email" {
  description = "Address to receive notifications e.g. `laurens@binx.io`."
  type        = string
}
