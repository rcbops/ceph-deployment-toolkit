#!/bin/bash

# install git
apt install -y git

# check which toolkit is installed
INSTALLED=$(cd /opt/ceph-toolkit; git remote -v  |grep fetch |awk '{print $2}' |sed -e 's/\.git//')

case $INSTALLED in
https://github.com/Alfano93/ceph-toolkit*)
    mv /opt/ceph-toolkit /opt/ceph-toolkit_deprecated
    cd /opt
    git clone https://github.com/rcbops/ceph-deployment-toolkit /opt/ceph-toolkit
    mv /opt/ceph-toolkit_deprecated/*inventory* /opt/ceph-toolkit/
    mv /opt/ceph-toolkit_deprecated/*.yaml /opt/ceph-toolkit/
    ;;
https://github.com/rcbops/ceph-deployment-toolkit*)
    cd /opt/ceph-toolkit
    git pull
    ;;
*)
    cd /opt
    git clone https://github.com/rcbops/ceph-deployment-toolkit /opt/ceph-toolkit
    ;;
esac

# set the correct cephrc
CEPH_MAJOR_VERSION=$(ceph -v |awk '{print $3}' |awk -F. '{print $1}')
case $CEPH_MAJOR_VERSION IN
12)
    cp /opt/ceph-toolkit/cephrc_mimic /opt/ceph-toolkit/cephrc
    ;;
13)
    cp /opt/ceph-toolkit/cephrc_mimic /opt/ceph-toolkit/cephrc
    ;;
14)
    cp /opt/ceph-toolkit/cephrc_nautilus /opt/ceph-toolkit/cephrc
    ;;
esac

# update venvs and ceph-ansible
cd /opt/ceph-toolkit
bash /opt/ceph-toolkit/scripts/prepare-deployment.sh

ln -sf /opt/ceph-toolkit/ceph_deploy /opt/ceph-ansible/venv
