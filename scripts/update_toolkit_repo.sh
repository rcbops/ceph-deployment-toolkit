#!/bin/bash

# install git
apt install -y git

# check which toolkit is installed
INSTALLED=$(cd /opt/ceph-toolkit; git remote -v  |grep fetch |awk '{print $2}')

if [ "${INSTALLED}" = "https://github.com/Alfano93/ceph-toolkit" ]
then
    mv /opt/ceph-toolkit /opt/ceph-toolkit_deprecated
    cd /opt
    git clone https://github.com/rcbops/ceph-deployment-toolkit /opt/ceph-toolkit
    mv /opt/ceph-toolkit_deprecated/*inventory* /opt/ceph-toolkit/
    mv /opt/ceph-toolkit_deprecated/*.yaml /opt/ceph-toolkit/
elif [ "${INSTALLED}" = "https://github.com/rcbops/ceph-deployment-toolkit" ]
then
    cd /opt/ceph-toolkit
    git pull
else
    cd /opt
    git clone https://github.com/rcbops/ceph-deployment-toolkit /opt/ceph-toolkit
fi

# set the correct cephrc
CEPH_MAJOR_VERSION=$(ceph -v |awk '{print $3}' |awk -F. '{print $1}')
if [ ${CEPH_MAJOR_VERSION} -eq 12 ]
then
    cp /opt/ceph-toolkit/cephrc_mimic /opt/ceph-toolkit/cephrc
elif [ ${CEPH_MAJOR_VERSION} -eq 13 ]
then
    cp /opt/ceph-toolkit/cephrc_mimic /opt/ceph-toolkit/cephrc
elif [ ${CEPH_MAJOR_VERSION} -eq 14 ]
then
    cp /opt/ceph-toolkit/cephrc_nautilus /opt/ceph-toolkit/cephrc
fi

# update venvs and ceph-ansible
cd /opt/ceph-toolkit
bash /opt/ceph-toolkit/scripts/prepare-deployment.sh

ln -sf /opt/ceph-toolkit/ceph_deploy /opt/ceph-ansible/venv
