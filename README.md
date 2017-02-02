# Nomad Dispatch + ffmpeg video transcoding

This repository demonstrates using the new [Nomad Dispatch](https://www.nomadproject.io/docs/commands/job-dispatch.html) features to build a scalable video transcoding service. Nomad dispatch makes use of a feature called [parameterized jobs](https://www.nomadproject.io/docs/job-specification/parameterized.html), which act like a function definition and can be invoked with arguments.

In this demo, we define a `transcode` parameterized job, which takes a required `input` video file and an `optional` profile to control the video transcoding mode. The input video can be a link to an MP4 file, and the profile is either "small" for a 480p output, or "large" for a 720p output. The job file itself can be found in the nomad directory, and is very simple. The `parameterized` block is what changes the behavior from a standard Nomad job.

To make use of the parameterized job, we invoke dispatch with our arguments:

```
$ nomad job dispatch -meta "profile=small" -meta "input=http://..." transcode
Dispatched Job ID = transcode/dispatch-1486004956-35ff5396
Evaluation ID     = e33db4b6

==> Monitoring evaluation "e33db4b6"
    Evaluation triggered by job "transcode/dispatch-1486004956-35ff5396"
    Allocation "6f8fab33" created: node "6bc692ac", group "tc"
    Evaluation status changed: "pending" -> "complete"
==> Evaluation "e33db4b6" finished with status "complete"
```

Each time we dispatch a parameterized job, we create a new job with a unique ID.
This is similar to a future or promise in many programming languages, and allows us to track the status of a given invocation.

Our transcode service is quite simple and ultimately invokes `bin/transcode.sh`. When called, the input file is downloaded, the MD5 is computed, ffmpeg is used to transcode, and the converted output is uploaded to S3 for storage. The transcode script supports a "small" and "large" profile, which convert files to 480p or 720p respectively.

To test the transcode service, we can either use [Vagrant](https://www.vagrantup.com) locally or [Terraform](https://www.terraform.io) to spin up an AWS cluster.

