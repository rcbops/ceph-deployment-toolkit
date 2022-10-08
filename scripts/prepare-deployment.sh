#!/bin/bash

if [ ! -e ./cephrc ]
then
    echo "Can't find ./cephrc"
    exit
fi
source ./cephrc

echo " ###################################"
echo " # CREATING ceph_deploy VIRTUALENV #"
echo " ###################################"

lsb_release -r |grep -q 18.04 2>/dev/null

if [ $? -eq 0 ]; then
    apt install -y python git
    wget https://bootstrap.pypa.io/pip/2.7/get-pip.py -O /opt/ceph-toolkit/get-pip.py
    python /opt/ceph-toolkit/get-pip.py
    pip install virtualenv
else
    apt install -y python3 git
    wget https://bootstrap.pypa.io/pip/3.6/get-pip.py -O /opt/ceph-toolkit/get-pip.py
    python3 /opt/ceph-toolkit/get-pip.py
    pip install virtualenv
fi

virtualenv ceph_deploy
source ceph_deploy/bin/activate


echo " ################################################"
echo " # DOWNLOADING ANSIBLE VERSION $ANSIBLE_VERSION #"
echo " ################################################"

#add-apt-repository ppa:ansible/ansible
#apt update
#apt install ansible=$ANSIBLE_VERSION

pip install --upgrade 'setuptools<45.0.0'
pip install ansible==$ANSIBLE_VERSION
pip install notario
pip install netaddr
pip install six


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
