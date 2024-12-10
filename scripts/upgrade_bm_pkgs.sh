#!/usr/bin/env bash
HOST_LIST=$(cephadm shell ceph orch host ls | awk 'NR>2 {print line} {line=$2}')
echo "Host list: $HOST_LIST"
if [[ -z $1 ]]; then
        echo "No release version provided"
        exit 1
elif [[ ! $1 =~ (quincy|reef|squid)$ ]]; then
        echo "Invalid release provided, please provide one of: quincy, reef or squid"
        exit 1
fi
for i in $HOST_LIST
do
        if ssh -o StrictHostKeyChecking=accept-new $i dpkg -l | grep cephadm > /dev/null 2>&1; then

                echo "Cephadm installed on host with ip $i, updating repo"
                ssh -o StrictHostKeyChecking=accept-new $i cephadm add-repo --release $1

                echo "Updating Cephadm package"
                ssh -o StrictHostKeyChecking=accept-new $i apt install -y --only-upgrade cephadm

                echo "Checking for ceph-common package"
                if ssh -o StrictHostKeyChecking=accept-new $i dpkg -l | grep ceph-common > /dev/null 2>&1; then

                        echo "Ceph-common installed, updating"
                        ssh -o StrictHostKeyChecking=accept-new $i apt install -y --only-upgrade ceph-common
                else
                        echo "Ceph-common not installed, skipping"
                fi
        else
                echo "Cephadm not installed, skipping"
                continue
        fi
done