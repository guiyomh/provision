# -*- mode: ruby -*-
# vi: set ft=ruby :

###############################################################################
## --- Disc setup ---
###############################################################################

require 'shellwords'
VAGRANT_ROOT = File.dirname(File.expand_path(__FILE__))
DiskVmData = File.join(VAGRANT_ROOT, '/disks/vm-data.vdi')

###############################################################################
## --- Vagrant setup ---
###############################################################################
Vagrant.configure(2) do |config|

  config.vm.box = "centos/7"

  config.vm.network "private_network", ip: "192.168.56.22"

  config.vm.synced_folder ".", "/home/vagrant/sync", disabled: true
  config.vm.synced_folder ".", "/vagrant", id: "vagrant" , type: "nfs"

  # VirtualBox
  config.vm.provider :virtualbox do |v|
      v.gui = false
      v.customize ["modifyvm", :id, "--name",                "test"]
      v.customize ["modifyvm", :id, "--natdnshostresolver1", "on"]
      v.customize ["modifyvm", :id, "--memory",              2048]
      v.customize ["modifyvm", :id, "--cpus",                2]
      v.customize ["modifyvm", :id, "--chipset",             "ich9"]
      v.customize ["modifyvm", :id, "--ioapic",              "on"]
      v.customize ["modifyvm", :id, "--rtcuseutc",           "on"]
      v.customize ["modifyvm", :id, "--pae",                 "on"]
      v.customize ["modifyvm", :id, "--hwvirtex",            "on"]
      v.customize ["modifyvm", :id, "--nestedpaging",        "on"]

      # Workaround: stability fix
      v.auto_nat_dns_proxy = false
      v.customize ["modifyvm", :id, "--natdnsproxy1", "off" ]
      v.customize ["modifyvm", :id, "--natdnshostresolver1", "off" ]

      # second disk
      unless File.exist?(DiskVmData)
          v.customize ['createhd', '--filename', DiskVmData, '--size', 6* 1024]
          # v.customize ['modifyhd', DiskVmData, '--type', 'multiattach']
      end
      v.customize ['storageattach', :id, '--storagectl', 'IDE Controller', '--port', 1, '--device', 0, '--type', 'hdd', '--medium', DiskVmData]

      # network
      v.customize ["modifyvm", :id, "--nictype1", "virtio"]
      v.customize ["modifyvm", :id, "--nictype2", "virtio"]
  end

  #################
  # Provisioning
  #################

  config.ssh.insert_key = false
  # Workaround: shell is not a tty
  config.ssh.shell = "bash -c 'BASH_ENV=/etc/profile exec bash'"

  # Bootstrap (only first time)
  config.vm.provision "bootstrap", type: "shell" do |s|
      s.inline = "sudo bash /vagrant/bootstrap.sh"
  end

end
