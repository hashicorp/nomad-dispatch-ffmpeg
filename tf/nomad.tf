# Query for the latest AMI of Ubuntu 14.04
data "aws_ami" "ubuntu" {
  most_recent = true

  filter {
    name   = "name"
    values = ["ubuntu/images/hvm-ssd/ubuntu-trusty-14.04-amd64-server-*"]
  }

  filter {
    name   = "virtualization-type"
    values = ["hvm"]
  }

  owners = ["099720109477"] # Canonical
}

# Register our new key pair using the public key
resource "aws_key_pair" "nomad-key" {
  key_name   = "nomad-key"
  public_key = "${file("nomad-key.pem.pub")}"
}

# Create a security group that allows all inbound traffic
# used for the Nomad servers in the public subnet
resource "aws_security_group" "allow_all" {
  name        = "allow_all"
  description = "Allow all inbound traffic"
  vpc_id      = "${module.vpc.vpc_id}"

  ingress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }

  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }
}

# Create a nomad server in the public subnet, this also acts
# as our bastion host into the rest of the cluster
resource "aws_instance" "server" {
  ami           = "${data.aws_ami.ubuntu.id}"
  instance_type = "c4.large"

  tags {
    Name = "Nomad Server"
  }

  subnet_id                   = "${module.vpc.public_subnets[0]}"
  associate_public_ip_address = "true"
  key_name                    = "${aws_key_pair.nomad-key.key_name}"
  vpc_security_group_ids      = ["${module.vpc.default_security_group_id}", "${aws_security_group.allow_all.id}"]

  connection {
    user        = "ubuntu"
    private_key = "${file("nomad-key.pem")}"
  }

  provisioner "file" {
    source      = "../bin/provision.sh"
    destination = "/tmp/provision.sh"
  }

  provisioner "file" {
    source      = "../nomad/transcode.nomad"
    destination = "/tmp/transcode.nomad"
  }

  provisioner "remote-exec" {
    inline = [
      "chmod +x /tmp/provision.sh",
      "sudo DD_API_KEY=${var.datadog_api_key} /tmp/provision.sh server",
      "nomad run /tmp/transcode.nomad",
    ]
  }
}

# Create any number of nomad clients in the private subnet. They are
# provisioned using the nomad server as a bastion host.
resource "aws_instance" "client" {
  count         = "${var.client_count}"
  ami           = "${data.aws_ami.ubuntu.id}"
  instance_type = "c4.large"

  tags {
    Name = "Nomad Client"
  }

  subnet_id              = "${module.vpc.private_subnets[0]}"
  key_name               = "${aws_key_pair.nomad-key.key_name}"
  vpc_security_group_ids = ["${module.vpc.default_security_group_id}"]

  connection {
    bastion_host = "${aws_instance.server.public_ip}"
    user         = "ubuntu"
    private_key  = "${file("nomad-key.pem")}"
  }

  provisioner "file" {
    source      = "../bin/transcode.sh"
    destination = "/tmp/transcode.sh"
  }

  provisioner "file" {
    source      = "../bin/provision.sh"
    destination = "/tmp/provision.sh"
  }

  provisioner "remote-exec" {
    inline = [
      "chmod +x /tmp/transcode.sh",
      "chmod +x /tmp/provision.sh",
      "sudo mv /tmp/transcode.sh /usr/bin/transcode.sh",
      "sudo DD_API_KEY=${var.datadog_api_key} /tmp/provision.sh client",
      "nomad client-config -update-servers ${aws_instance.server.private_ip}:4647",
    ]
  }
}

# Output the nomad server address to make it easier to setup Nomad
output "nomad_addr" {
  value = "http://${aws_instance.server.public_ip}:4646/"
}
