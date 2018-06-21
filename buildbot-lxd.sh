#!/bin/sh

set -ev

CONTAINER_MASTER=master
CONTAINER_WORKER_1=worker-1
CONTAINER_WORKER_2=worker-2

apt update
apt purge lxd* lxc* -y
snap install lxd
echo Waiting 12 seconds so lxd daemon starts
sleep 12

cat config/lxd_preseed.yaml | lxd init --preseed

for container in ${CONTAINER_MASTER} ${CONTAINER_WORKER_1} ${CONTAINER_WORKER_2}
do
        lxc launch ubuntu:16.04 ${container}
        echo Waiting 6 seconds for internet
        sleep 6
        lxc exec ${container} -- apt update
        lxc exec ${container} -- apt install python3-pip -y
done

echo Configuring master
lxc exec ${CONTAINER_MASTER} -- pip3 install "buildbot[bundle]"
lxc exec ${CONTAINER_MASTER} -- buildbot create-master ~/master
lxc exec ${CONTAINER_MASTER} -- cp ~/master/master.cfg.sample ~/master/master.cfg
lxc exec ${CONTAINER_MASTER} -- buildbot start ~/master

MASTER_CONTAINER_IP=$(lxc exec ${CONTAINER_MASTER} -- sh -c "hostname -I | cut -d ' ' -f1")
PUBLIC_IP=$(curl ipinfo.io/ip)

lxc config device add ${CONTAINER_MASTER} http proxy listen=tcp:${PUBLIC_IP}:8010 connect=tcp:${MASTER_CONTAINER_IP}:8010 bind=host

echo Configuring workers
for worker in ${CONTAINER_WORKER_1} ${CONTAINER_WORKER_2}
do
        lxc exec ${worker} -- pip3 install buildbot-worker
        lxc exec ${worker} -- buildbot-worker create-worker ~/worker ${MASTER_CONTAINER_IP} ${worker} secret_supersecret
        lxc exec ${worker} -- buildbot-worker start ~/worker
done
