#!/bin/sh

set -e

apt update
apt dist-upgrade -y
apt autoremove -y
apt purge lxd* lxc* -y
snap install lxd

for i in {1..20}
do
        if [ ! -S /var/snap/lxd/common/lxd/unix.socket ]; then
            echo "LXD daemon not started, waiting"
            sleep 1
        fi
done

cat lxd_preseed.yaml | lxd init --preseed

for container in master worker-1 worker-2
do
        lxc launch ubuntu:16.04 $container
        echo Waiting 6 seconds for internet
        sleep 6
        lxc exec $container -- sh -c 'apt update'
        lxc exec $container -- sh -c 'apt dist-upgrade -y'
        lxc exec $container -- sh -c 'apt install python3-pip -y'
done

echo Configuring master
lxc exec master -- sh -c 'buildbot create-master /root/master'
lxc exec master -- sh -c 'cp /root/master/master.cfg.sample /root/master/master.cfg'
lxc exec master -- sh -c 'buildbot start /root/master'

