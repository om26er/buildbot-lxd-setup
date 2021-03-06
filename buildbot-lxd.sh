#!/bin/sh

set -ev

CONTAINER_MASTER=master
CONTAINER_WORKER_1=worker-1
CONTAINER_WORKER_2=worker-2

apt update
apt purge lxd* lxc* -y
snap install lxd
# FIXME need to find a better way to ensure LXD is up and running
echo Waiting 12 seconds so lxd daemon starts
sleep 12

cat config/lxd_preseed.yaml | lxd init --preseed

for container in ${CONTAINER_MASTER} ${CONTAINER_WORKER_1} ${CONTAINER_WORKER_2}
do
        lxc launch ubuntu:16.04 ${container}
        # FIXME: need to find a better way to ensure internet is working inside container (ping ?)
        echo Waiting 6 seconds for internet
        sleep 6
        lxc exec ${container} -- apt update
        lxc exec ${container} -- apt install python3-pip -y
done

echo Configuring master
lxc exec ${CONTAINER_MASTER} -- pip3 install "buildbot[bundle]"
lxc exec ${CONTAINER_MASTER} -- buildbot create-master ~/master
MASTER_HOME=$(lxc exec ${CONTAINER_MASTER} -- sh -c 'echo $HOME')
lxc file push config/master.cfg ${CONTAINER_MASTER}${MASTER_HOME}/master/
lxc file push config/buildbot-master.service ${CONTAINER_MASTER}/etc/systemd/system/
lxc exec ${CONTAINER_MASTER} -- systemctl enable buildbot-master
lxc exec ${CONTAINER_MASTER} -- systemctl start buildbot-master

MASTER_CONTAINER_IP=$(lxc exec ${CONTAINER_MASTER} -- sh -c "hostname -I | cut -d ' ' -f1")
PUBLIC_IP=$(curl ipinfo.io/ip)

lxc config device add ${CONTAINER_MASTER} http proxy listen=tcp:${PUBLIC_IP}:8010 connect=tcp:${MASTER_CONTAINER_IP}:8010 bind=host

echo Configuring workers
for worker in ${CONTAINER_WORKER_1} ${CONTAINER_WORKER_2}
do
        lxc exec ${worker} -- pip3 install buildbot-worker
        lxc exec ${worker} -- buildbot-worker create-worker ~/worker ${MASTER_CONTAINER_IP} ${worker} secret_supersecret
        lxc file push config/buildbot-worker.service ${worker}/etc/systemd/system/
        lxc exec ${worker} -- systemctl enable buildbot-worker
        lxc exec ${worker} -- systemctl start buildbot-worker
done
