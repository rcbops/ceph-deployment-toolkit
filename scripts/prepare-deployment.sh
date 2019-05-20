#!/bin/bash

source /opt/ceph-deployment-toolkit/cephrc

echo " ################################################"
echo " # DOWNLOADING ANSIBLE VERSION $ANSIBLE_VERSION #"
echo " ################################################"

add-apt-repository ppa:ansible/ansible
apt update
apt install ansible=$ANSIBLE_VERSION

echo "######################################################"
echo "# CLONING CEPH-ANSIBLE VERSION $CEPH_ANSIBLE_VERSION #"
echo "######################################################"

git clone https://github.com/ceph/ceph-ansible.git /opt/ceph-ansible

cd /opt/ceph-ansible && git checkout $CEPH_ANSIBLE_VERSION

echo "Environment prepared for automation" 
