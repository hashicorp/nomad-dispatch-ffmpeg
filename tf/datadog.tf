# Setup the datadog provider
provider "datadog" {
  api_key = "${var.datadog_api_key}"
  app_key = "${var.datadog_app_key}"
}

# Setup a dashboard for the queue depth of jobs waiting to be scheduled
resource "datadog_timeboard" "nomad" {
  title       = "Nomad queue depth (created via Terraform)"
  description = "Depth of jobs waiting to be scheduled"
  read_only   = true

  graph {
    title = "Queue depth"
    viz   = "timeseries"

    request {
      q = "sum:nomad.ip_${replace(aws_instance.server.private_ip, ".", "_")}.nomad.blocked_evals.total_blocked{*}"
    }
  }
}
