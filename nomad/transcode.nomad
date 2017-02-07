job "transcode" {
  type        = "batch"
  datacenters = ["dc1"]

  meta {
    input   = ""
    profile = "small"
  }

  # This is the new "parameterized" stanza that marks a job as dispatchable. In
  # this example, there are two pieces of metadata (see above). The "input"
  # parameter is required, but the "profile" parameter is optional and defaults
  # to "small" if left unspecified when dispatching the job.
  parameterized {
    meta_required = ["input"]
    meta_optional = ["profile"]
  }

  task "tc" {
    driver = "exec"

    config {
      command = "transcode.sh"
      args    = ["${NOMAD_META_INPUT}", "${NOMAD_META_PROFILE}"]
    }

    env {
      "S3_BUCKET" = "BUCKET_NAME"
    }

    resources {
      cpu    = 1000
      memory = 256
    }

    template {
      destination = "local/s3cfg.ini"

      # This example uses hard-coded credentials, but a real production job
      # file should pull secrets using the Vault integration.
      data = <<EOH
[default]
access_key = "<access_key>"
secret_key = "<secret_key>"
EOH
    }
  }
}
