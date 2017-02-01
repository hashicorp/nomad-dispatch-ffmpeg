job "transcode" {
    type = "batch"
    datacenters = ["dc1"]

    # Require the input file, allow optional profile (default to small)
    parameterized {
        meta_required = ["input"]
        meta_optional = ["profile"]
    }
    meta {
        input = ""
        profile = "small"
    }

    task "tc" {
        driver = "exec"
        config {
            command = "transcode.sh"
            args = ["${NOMAD_META_INPUT}", "${NOMAD_META_PROFILE}"]
        }
        env {
            S3_BUCKET = "BUCKET_NAME"
        }
        resources {
            cpu = 1000
            memory = 256
        }
        template {
            destination = "local/s3cfg.ini"
            data        = <<EOH
[default]
access_key = "ACCESS_KEY"
secret_key = "SECRET_KEY"
EOH
        }
    }
}
