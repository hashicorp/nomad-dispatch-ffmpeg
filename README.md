# Nomad Dispatch + ffmpeg video transcoding

This repository demonstrates using the new [Nomad Dispatch](https://www.nomadproject.io/docs/commands/job-dispatch.html) features to build a scalable video transcoding service. Nomad dispatch makes use of a feature called [parameterized jobs](https://www.nomadproject.io/docs/job-specification/parameterized.html), which act like a function definition and can be invoked with arguments.

In this demo, we define a `transcode` parameterized job, which takes a required `input` video file and an optional `profile` to control the video transcoding mode. The input video can be a link to an MP4 file, and the profile is either "small" for a 480p output, or "large" for a 720p output. The job file itself can be found in the nomad directory, and is very simple. The `parameterized` block is what changes the behavior from a standard Nomad job.

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

Our transcode service is ultimately invokes `bin/transcode.sh`. When called, the input file is downloaded, the MD5 is computed, ffmpeg is used to transcode, and the converted output is uploaded to S3 for storage. The transcode script supports a "small" and "large" profile, which convert files to 480p or 720p respectively.

To test the transcode service, we can either use [Vagrant](https://www.vagrantup.com) locally or [Terraform](https://www.terraform.io) to spin up an AWS cluster.

# Transcode Job Setup

Before using either Vagrant or Terraform to test our cluster, we need to configure the Nomad job.
The job is provided at `nomad/transcode.nomad`, however we must configure the S3 bucket to upload to
and provide the AWS credentials to upload to S3.

Inside the job file, we will see the following sections:

```
job "transcode" {
    ...
    env {
        S3_BUCKET = "BUCKET_NAME"
    }
    ...
    template {
        destination = "local/s3cfg.ini"
        data        = <<EOH
[default]
access_key = "ACCESS_KEY"
secret_key = "SECRET_KEY"
EOH
    }
...
```

We need to replace `BUCKET_NAME` with the name of the actual S3 bucket to upload to,
and `ACCESS_KEY` and `SECRET_KEY` with credentials that have permission to use that bucket.

**Caveats**:
For the sake of simplicity, we can hard code the credentials, however in a real world scenario
we would use [Vault](https://www.vaultproject.io) to store the credentials and use Nomad's
[template integration](https://www.nomadproject.io/docs/job-specification/template.html) to
populate the values.

# Vagrant

Using Vagrant we can setup a local virtual machine to test our transcoding service.
Assuming Vagrant is installed already, the provided `Vagrantfile` will setup the VM and register our Nomad job:

```
$ vagrant up
Bringing machine 'default' up with 'vmware_fusion' provider...
==> default: Cloning VMware VM: 'cbednarski/ubuntu-1404'. This can take some time...
==> default: Checking if box 'cbednarski/ubuntu-1404' is up to date...
==> default: Verifying vmnet devices are healthy...
==> default: Preparing network adapters...
==> default: Starting the VMware VM...
...
==> default: nomad start/running, process 14816
==> default: Running provisioner: file...
==> default: Running provisioner: shell...
    default: Running: inline script
==> default: stdin: is not a tty
==> default: Job registration successful
```

At this point, we should have a Vagrant VM running with Nomad setup and our `transcode` job registered.
We can verify this is the case:

```
$ vagrant ssh
...

$ nomad status
ID         Type   Priority  Status
transcode  batch  50        running

$ nomad status transcode
ID            = transcode
Name          = transcode
Type          = batch
Priority      = 50
Datacenters   = dc1
Status        = running
Periodic      = false
Parameterized = true

Parameterized Job
Payload           = optional
Required Metadata = input
Optional Metadata = profile

Parameterized Job Summary
Pending  Running  Dead
0        0        0

No dispatched instances of parameterized job found
```

To attempt transcoding, we can use the provided samples:

```
$ vagrant ssh
...

$ cd /vagrant/

$ ./bin/dispatch.sh samples/one.txt
Input file: http://s3.amazonaws.com/akamai.netstorage/HD_downloads/Orion_SM.mp4
Dispatched Job ID = transcode/dispatch-1486005726-0d20aa76
Evaluation ID     = ac7a43be
Dispatched Job ID = transcode/dispatch-1486005726-6671c576
Evaluation ID     = ba6cfb02

$ nomad status transcode
ID            = transcode
Name          = transcode
Type          = batch
Priority      = 50
Datacenters   = dc1
Status        = running
Periodic      = false
Parameterized = true

Parameterized Job
Payload           = optional
Required Metadata = input
Optional Metadata = profile

Parameterized Job Summary
Pending  Running  Dead
0        2        0

Dispatched Jobs
ID                                      Status
transcode/dispatch-1486005726-0d20aa76  running
transcode/dispatch-1486005726-6671c576  running
```

Here we can see that we've dispatched two jobs, both are processing the same input file, one for the "small" profile and one for the "large" profile. We can use the standard Nomad commands to inspect and monitor those jobs, as they are regular batch jobs.

We can cleanup using Vagrant:

```
$ vagrant destroy
    default: Are you sure you want to destroy the 'default' VM? [y/N] y
==> default: Stopping the VMware VM...
==> default: Deleting the VM...
```

Don't forget to delete the output files in S3 to avoid being charged.

# Terraform

Using Terraform we can setup a remote AWS cluster to test our transcoding service.
This allows us to scale up the number of Nomad nodes to increase the total transcoding throughput.
Assuming Terraform and Nomad are installed locally, we must configure Terraform by creating a file
at `tf/terraform.tfvars`:

```
# Configure Datadog API keys
datadog_api_key = "1234..."
datadog_app_key = "5cc7..."

# Configure the AWS access keys
aws_access_key = "AKIA..."
aws_secret_key = "HZFm..."

# Set the number of Nomad clients
client_count = 2
```

We are using [Datadog](http://datadoghq.com) to monitor the queue depth of pending jobs.
This gives us visibility into how busy our cluster is, and if we need to add more Nomad nodes
to scale up our processing throughput. We use AWS to spin up a simple Nomad cluster, with a single
server, and a variable number of clients (defaulting to 1). Once we've setup our variables, we
can spin up the cluster with Terraform:

```
$ cd tf/

$ terraform plan
Refreshing Terraform state in-memory prior to plan...
The refreshed state will be used to calculate this plan, but
will not be persisted to local or remote state storage.

data.aws_ami.ubuntu: Refreshing state...
...


Plan: 19 to add, 0 to change, 0 to destroy.

$ terraform apply
Refreshing Terraform state in-memory prior to plan...
The refreshed state will be used to calculate this plan, but
will not be persisted to local or remote state storage.

data.aws_ami.ubuntu: Refreshing state...
...

Apply complete! Resources: 19 added, 0 changed, 0 destroyed.

Outputs:

nomad_addr = http://174.129.94.31:4646/

$ export NOMAD_ADDR=`terraform output nomad_addr`

$ nomad status
ID                                      Type   Priority  Status
transcode                               batch  50        running
```

At this point, we have a Nomad cluster running in AWS with our `transcode` job registered.
We can now submit many input files to be converted:

```
$ ./bin/dispatch.sh samples/many.txt
Input file: http://s3.amazonaws.com/akamai.netstorage/HD_downloads/Orion_SM.mp4
Dispatched Job ID = transcode/dispatch-1486005726-0d20aa76
Evaluation ID     = ac7a43be
Dispatched Job ID = transcode/dispatch-1486005726-6671c576
Evaluation ID     = ba6cfb02
...

$ nomad status
ID                                      Type   Priority  Status
transcode                               batch  50        running
transcode/dispatch-1486001045-40d24d1d  batch  50        running
transcode/dispatch-1486001045-8627bc67  batch  50        running
transcode/dispatch-1486001307-3a1b99e7  batch  50        running
transcode/dispatch-1486001307-9301d53a  batch  50        running
transcode/dispatch-1486001307-d13f810d  batch  50        running
...
```

We can now see all the jobs queued, some are `running` while many are `pending`
as they are queued until resources free up. Nomad is acting like a job queue,
waiting for jobs to complete and then scheduling additional work. If we wanted
to increase throughput, we can increase `client_count` in `tf/terraform.tfvars`
and run Terraform again.

We can cleanup using Terraform:

```
$ cd tf/
$ terraform destroy
Do you really want to destroy?
  Terraform will delete all your managed infrastructure.
  There is no undo. Only 'yes' will be accepted to confirm.

  Enter a value: yes

...
module.vpc.aws_vpc.mod: Destroying...
module.vpc.aws_vpc.mod: Destruction complete

Destroy complete! Resources: 19 destroyed.
```

Don't forget to delete the output files in S3 to avoid being charged.

**Caveats**:
Terraform is deploying the Nomad server to be accessible on the Internet with
an insecure configuration. This makes it easy to demo the dispatch features,
however in real world usage the Nomad servers should be accessible only via
VPN or a bastion host.

Additionally, for the sake of simplicity we are using provisioners to configure
our AWS instances after launch. In practice, we would use [Packer](https://www.packer.io)
to pre-bake AMIs that are already configured to reduce startup time and the risk
of partial failures during setup.

