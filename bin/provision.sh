#!/bin/bash
set -e

# Set the mode for the provisioning. This can be "vagrant", "server", or
# "client"
MODE="vagrant"
if [ $1 == "server" ]; then
  MODE=$1
elif [ $1 == "client" ]; then
  MODE=$1
elif [ $1 == "vagrant" ]; then
  MODE=$1
fi
echo "Provisioning mode: $MODE"

# Get the packages necessary for add-apt-respository
sudo apt-get install -y software-properties-common

# Add the ffmpeg PPA
yes | sudo add-apt-repository ppa:mc3man/trusty-media

# Update the package versions
sudo apt-get update

# Install the latest version of necessary packages
sudo apt-get install -y s3cmd ffmpeg unzip docker.io

# Instead of symlink, move ffmpeg to be inside the chroot for Nomad
sudo rm /usr/bin/ffmpeg
sudo cp /opt/ffmpeg/bin/ffmpeg /usr/bin/ffmpeg

# Install the datadog agent
if [ ! -z $DD_API_KEY ]; then
  bash -c "$(curl -L https://raw.githubusercontent.com/DataDog/dd-agent/master/packaging/datadog-agent/source/install_agent.sh)"
fi

# Download the latest build of Nomad
wget -nv -O /tmp/nomad.zip "https://releases.hashicorp.com/nomad/0.5.4/nomad_0.5.4_linux_amd64.zip"

# Unzip and install nomad
unzip /tmp/nomad.zip
sudo chmod +x nomad
sudo mv nomad /usr/bin/nomad

# Determine the configuration
if [ $MODE == "vagrant" ]; then
  BIND="127.0.0.1"
  SERVER_ENABLED="true"
  CLIENT_ENABLED="true"
  BOOTSTRAP="1"
  ADVERTISE='
advertise {
  http="127.0.0.1"
  rpc="127.0.0.1"
  serf="127.0.0.1"
}
'
elif [ $MODE == "server" ]; then
  BIND="0.0.0.0"
  SERVER_ENABLED="true"
  CLIENT_ENABLED="false"
  BOOTSTRAP="1"
  ADVERTISE=""
elif [ $MODE == "client" ]; then
  BIND="127.0.0.1"
  SERVER_ENABLED="false"
  CLIENT_ENABLED="true"
  BOOTSTRAP="0"
  ADVERTISE=""
fi

# Create the configuration directory and populate
sudo mkdir -p /etc/nomad.d/
sudo mkdir -p /var/nomad/
cat >/tmp/agent.json <<EOL
data_dir = "/var/nomad/"
bind_addr = "$BIND"

server {
  enabled = $SERVER_ENABLED
  bootstrap_expect = $BOOTSTRAP
}

client {
  enabled = $CLIENT_ENABLED
}

telemetry {
  datadog_address = "127.0.0.1:8125"
}
$ADVERTISE
EOL
sudo mv /tmp/agent.json /etc/nomad.d/agent.json

# Create the init script
cat >/tmp/nomad.conf <<EOL
# nomad - Nomad application scheduler agent

description "agent to participate in a Nomad cluster"

start on runlevel [2345]
stop on runlevel [!2345]

respawn
exec nomad agent -config /etc/nomad.d/
EOL
sudo mv /tmp/nomad.conf /etc/init/nomad.conf

# Start nomad
sudo start nomad || true

# Wait for Nomad to start
sleep 10
