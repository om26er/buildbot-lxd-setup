#!/bin/sh

set -ev

CONTAINER_MASTER=master
CONTAINER_WORKER_1=worker-1
CONTAINER_WORKER_2=worker-2

apt update
apt purge lxd* lxc* -y
snap install lxd

for i in {1..20}
do
        if [ ! -S /var/snap/lxd/common/lxd/unix.socket ]; then
            echo "LXD daemon not started, waiting"
            sleep 1
        else
            break
        fi
done

cat config/lxd_preseed.yaml | lxd init --preseed

for container in ${CONTAINER_MASTER} ${CONTAINER_WORKER_1} ${CONTAINER_WORKER_2}
do
        lxc launch ubuntu:16.04 ${container}
        echo Waiting 6 seconds for internet
        sleep 6
        lxc exec ${container} -- sh -c 'apt update'
        lxc exec ${container} -- sh -c 'apt install python3-pip -y'
done

echo Configuring master
lxc exec ${CONTAINER_MASTER} -- sh -c 'pip install "buildbot[bundle]"'
lxc exec ${CONTAINER_MASTER} -- sh -c 'buildbot create-master ~/master'
lxc exec ${CONTAINER_MASTER} -- sh -c 'cp ~/master/master.cfg.sample ~/master/master.cfg'
lxc exec ${CONTAINER_MASTER} -- sh -c 'buildbot start ~/master'

echo Configuring workers
MASTER_IP=$(lxc exec ${CONTAINER_MASTER} -- sh -c "hostname -I | cut -d ' ' -f1")
for worker in ${CONTAINER_WORKER_1} ${CONTAINER_WORKER_2}
do
        lxc exec ${worker} -- sh -c 'pip install buildbot-worker'
        lxc exec ${worker} -- sh -c 'buildbot-worker create-worker ~/worker ${MASTER_IP} example-worker pass'
done
