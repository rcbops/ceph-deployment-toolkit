#!/bin/bash

add-apt-repository ppa:ansible/ansible
apt update
apt install ansible=$ANSIBLE_VERSION

echo "CLONING CEPH-ANSIBLE VERSION $CEPH_ANSIBLE_VERSION"

git clone https://github.com/ceph/ceph-ansible.git /opt/ceph-ansible

cd /opt/ceph-ansible && git checkout $CEPH_ANSIBLE_VERSION

echo "Environment prepared for automation" 
