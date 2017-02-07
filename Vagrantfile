# DD_API_KEY is the Datadog API key to use for the agents
DD_API_KEY = ENV["DD_API_KEY"]

Vagrant.configure("2") do |config|
  config.vm.box = "cbednarski/ubuntu-1404"

  config.vm.provider "virtualbox" do |vb|
    vb.cpus = 2
    vb.memory = "2048"
  end

  config.vm.provider "vmware_desktop" do |vmware|
    vmware.cpus = 2
    vmware.memory = "2048"
    vmware.enable_vmrun_ip_lookup = false
  end

  # Copy the transcode script
  config.vm.provision "file",
    source: "bin/transcode.sh",
    destination: "/tmp/transcode.sh"

  config.vm.provision "shell", inline: <<SCRIPT
    sudo chmod +x /tmp/transcode.sh
    sudo mv /tmp/transcode.sh /usr/bin/transcode.sh
SCRIPT

  # Setup the machine
  config.vm.provision "shell",
    path: "bin/provision.sh",
    args: ["vagrant"],
    env: { "DD_API_KEY" => DD_API_KE Y}

  # Register the nomad job
  config.vm.provision "file",
    source: "nomad/transcode.nomad",
    destination: "/tmp/transcode.nomad"

  config.vm.provision "shell",
    inline: "nomad run /tmp/transcode.nomad"
end
