#!/bin/bash

set -euxo pipefail

wget -cN http://download.fedoraproject.org/pub/fedora/linux/releases/21/Cloud/Images/x86_64/Fedora-Cloud-Atomic-20141203-21.x86_64.qcow2

pushd cloud-init
genisoimage -output atomic01-cidata.iso -volid cidata -joliet -rock user-data meta-data
popd

qemu-img create -f qcow2 -o preallocation=off box.img 100G
virt-resize --expand /dev/sda2 Fedora-Cloud-Atomic-20141203-21.x86_64.qcow2 box.img

# Get a free port for port forwarding
SSH_PORT=$(port=32768; while netstat -atn | grep -q :$port; do port=$(expr $port + 1); done; echo $port)
SSH_OPTIONS="-oStrictHostKeyChecking=no -oUserKnownHostsFile=/dev/null"

qemu-kvm -name atomic-cloud-host -m 768 -hda box.img --drive media=cdrom,file=cloud-init/atomic01-cidata.iso,readonly -netdev bridge,br=virbr0,id=net0 -device virtio-net-pci,netdev=net0 -net user,hostfwd=tcp:127.0.0.1:$SSH_PORT-:22 -net nic -daemonize -monitor unix:monitor,server,nowait -display none

sleep 30s

ssh $SSH_OPTIONS -p$SSH_PORT -i/opt/vagrant/embedded/gems/gems/vagrant-1.7.2/keys/vagrant vagrant@localhost sudo docker info
ssh $SSH_OPTIONS -p$SSH_PORT -i/opt/vagrant/embedded/gems/gems/vagrant-1.7.2/keys/vagrant vagrant@localhost sudo atomic upgrade

ssh $SSH_OPTIONS -p$SSH_PORT -i/opt/vagrant/embedded/gems/gems/vagrant-1.7.2/keys/vagrant vagrant@localhost sudo systemctl reboot || true

sleep 30s

ssh $SSH_OPTIONS -p$SSH_PORT -i/opt/vagrant/embedded/gems/gems/vagrant-1.7.2/keys/vagrant vagrant@localhost sudo ostree admin undeploy 1
ssh $SSH_OPTIONS -p$SSH_PORT -i/opt/vagrant/embedded/gems/gems/vagrant-1.7.2/keys/vagrant vagrant@localhost sudo ostree admin cleanup
ssh $SSH_OPTIONS -p$SSH_PORT -i/opt/vagrant/embedded/gems/gems/vagrant-1.7.2/keys/vagrant vagrant@localhost sudo sed -i 's/.*UseDNS.*/UseDNS\ no/' /etc/ssh/sshd_config
ssh $SSH_OPTIONS -p$SSH_PORT -i/opt/vagrant/embedded/gems/gems/vagrant-1.7.2/keys/vagrant vagrant@localhost sudo rm -f /etc/ssh/ssh_host_*
ssh $SSH_OPTIONS -p$SSH_PORT -i/opt/vagrant/embedded/gems/gems/vagrant-1.7.2/keys/vagrant vagrant@localhost sudo systemctl enable docker
ssh $SSH_OPTIONS -p$SSH_PORT -i/opt/vagrant/embedded/gems/gems/vagrant-1.7.2/keys/vagrant vagrant@localhost sudo groupadd docker
ssh $SSH_OPTIONS -p$SSH_PORT -i/opt/vagrant/embedded/gems/gems/vagrant-1.7.2/keys/vagrant vagrant@localhost sudo sed -i 's/^SELINUX=.*/SELINUX=disabled/' /etc/selinux/config
ssh $SSH_OPTIONS -p$SSH_PORT -i/opt/vagrant/embedded/gems/gems/vagrant-1.7.2/keys/vagrant vagrant@localhost sudo sed -i 's/^SELINUX=.*/SELINUX=disabled/' /etc/sysconfig/selinux

echo system_powerdown | socat - UNIX-CONNECT:monitor

rm -f monitor

sleep 30s

tar -czvf atomic-libvirt.box Vagrantfile metadata.json box.img

qemu-img convert -O vmdk box.img box-virtualbox-disk1.vmdk
tar --transform 'flags=r;s|-virtualbox||' -czvf atomic-virtualbox.box Vagrantfile metadata-virtualbox.json box-virtualbox-disk1.vmdk box-virtualbox.ovf
