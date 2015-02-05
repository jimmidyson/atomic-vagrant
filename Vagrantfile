Vagrant.configure("2") do |config|
  config.vm.synced_folder ".", "/vagrant", disabled: true

  config.vm.provider :libvirt do |libvirt, override|
    libvirt.disk_bus = 'sata'
  end

  config.vm.base_mac = "080027D03E76"

  config.vm.provider :virtualbox do |vb|
    # Guest Additions are unavailable.
    vb.check_guest_additions = false
    vb.functional_vboxsf     = false

    # Fix docker not being able to resolve private registry in VirtualBox
    vb.customize ["modifyvm", :id, "--natdnshostresolver1", "on"]
    vb.customize ["modifyvm", :id, "--natdnsproxy1", "on"]
  end
end
