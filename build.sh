#!/bin/bash

set -euxo pipefail
IFS=$'\n\t'

wget -cN http://download.fedoraproject.org/pub/fedora/linux/releases/21/Cloud/Images/x86_64/Fedora-Cloud-Atomic-20141203-21.x86_64.qcow2

pushd cloud-init
genisoimage -output atomic01-cidata.iso -volid cidata -joliet -rock user-data meta-data
popd

qemu-img create -f qcow2 -o preallocation=off atomicdisk.qcow2 100G
virt-resize --expand /dev/sda2 Fedora-Cloud-Atomic-20141203-21.x86_64.qcow2 atomicdisk.qcow2

# Get a free port for port forwarding
SSH_PORT=$(port=32768; while netstat -atn | grep -q :$port; do port=$(expr $port + 1); done; echo $port)

qemu-kvm -name atomic-cloud-host -m 768 -hda atomicdisk.qcow2 --drive media=cdrom,file=cloud-init/atomic01-cidata.iso,readonly -netdev bridge,br=virbr0,id=net0 -device virtio-net-pci,netdev=net0 -net user,hostfwd=tcp:127.0.0.1:$SSH_PORT-:22 -net nic -daemonize -monitor unix:monitor,server,nowait -display none

ssh -oStrictHostKeyChecking=no -p$SSH_PORT -i/opt/vagrant/embedded/gems/gems/vagrant-1.7.1/keys/vagrant vagrant@localhost sudo docker info
ssh -oStrictHostKeyChecking=no -p$SSH_PORT -i/opt/vagrant/embedded/gems/gems/vagrant-1.7.1/keys/vagrant vagrant@localhost sudo atomic upgrade
ssh -oStrictHostKeyChecking=no -p$SSH_PORT -i/opt/vagrant/embedded/gems/gems/vagrant-1.7.1/keys/vagrant vagrant@localhost sudo rm -f /etc/ssh/ssh_host_*

echo system_powerdown | socat - UNIX-CONNECT:monitor
rm -f monitor
