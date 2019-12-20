#!/bin/bash

if [ ! -e ./cephrc ]
then
    echo "Can't find ./cephrc"
    exit
fi
source ./cephrc

echo " #################################"
echo " # INSTALLING GIT AND VIRTUALENV #"
echo " #################################"

apt install -y git virtualenv


echo " ###################################"
echo " # CREATING ceph_deploy VIRTUALENV #"
echo " ###################################"

virtualenv ceph_deploy
source ceph_deploy/bin/activate


echo " ################################################"
echo " # DOWNLOADING ANSIBLE VERSION $ANSIBLE_VERSION #"
echo " ################################################"

#add-apt-repository ppa:ansible/ansible
#apt update
#apt install ansible=$ANSIBLE_VERSION
pip install ansible==$ANSIBLE_VERSION
pip install notario
pip install netaddr


if [ ! -d ${CEPH_ANSIBLE_DIR} ]
then
    echo "########################"
    echo "# CLONING CEPH-ANSIBLE #"
    echo "########################"

    git clone https://github.com/ceph/ceph-ansible.git ${CEPH_ANSIBLE_DIR}
fi

echo "###########################################################"
echo "# CHECKING OUT CEPH-ANSIBLE VERSION $CEPH_ANSIBLE_VERSION #"
echo "###########################################################"

cd ${CEPH_ANSIBLE_DIR} && git fetch && git checkout $CEPH_ANSIBLE_VERSION
    

echo "Environment prepared for automation" 
