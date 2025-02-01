#!/bin/bash

if [ -z "$1" ]; then
  echo "The ceph-ansible branch version must be defined:"
  echo "$0 stable-7.0"
  echo ""
  echo "Octopus stable-5.0"
  echo "Pacific stable-6.0"
  echo "Quincy	stable-7.0 *"

  exit 1
fi

echo " ###################################"
echo " # CREATING ceph_deploy VIRTUALENV #"
echo " ###################################"

OS_RELEASE=$(lsb_release -sr)
BASEDIR="/opt/ceph-toolkit"
CEPH_ANSIBLE_VERSION="$1"
CEPH_ANSIBLE_DIR="/opt/ceph-ansible"
CEPHADM=false
INSTALL_ANSIBLE_COLLECTIONS=false

if [ ${OS_RELEASE} = "18.04" ]; then
   echo "Ubuntu 18.04 is no longer supported with this code, please use the older version at SHA b880e4b55f8f10702d841c03893706d4179bfcdf"
   exit 1
else
    apt install -y python3 python-is-python3 python3-distutils python3-venv git
    wget https://bootstrap.pypa.io/get-pip.py -O /opt/ceph-toolkit/get-pip.py
    python3 /opt/ceph-toolkit/get-pip.py
    python3 -m venv ceph_deploy
fi

rm -f ${BASEDIR}/cephrc
source ceph_deploy/bin/activate

ANSIBLE_MODULE=""
case "$CEPH_ANSIBLE_VERSION" in
    stable-5.0)
      ANSIBLE_MODULE="ansible==2.10.7"
      INSTALL_ANSIBLE_COLLECTIONS=false
    ;;

    stable-6.0)
      ANSIBLE_MODULE="ansible==2.10.7"
      INSTALL_ANSIBLE_COLLECTIONS=false
      CEPHADM=true
    ;;

    stable-7.0)
      case "$OS_RELEASE" in
        20.04)
          ANSIBLE_MODULE="ansible-core==2.13.13"
	;;
        22.04)
          ANSIBLE_MODULE="ansible-core==2.15.13"
	;;
      esac

      INSTALL_ANSIBLE_COLLECTIONS=true
      CEPHADM=true
    ;;
esac

if [ -z "$ANSIBLE_MODULE" ]; then
  echo "Could not set ansible module to install. Check input"
  exit 1
fi

echo " #######################################"
echo " # DOWNLOADING ANSIBLE $ANSIBLE_MODULE #"
echo " #######################################"
pip install $ANSIBLE_MODULE

pip install 'notario<=0.0.16'
pip install 'netaddr<=1.3.0'
pip install 'six<=1.16.0'


if $INSTALL_ANSIBLE_COLLECTIONS; then
  ansible-galaxy collection install ansible.posix
  ansible-galaxy collection install ansible.utils
  ansible-galaxy collection install community.general
fi

if [ ! -d ${CEPH_ANSIBLE_DIR} ]
then
    echo "########################"
    echo "# CLONING CEPH-ANSIBLE #"
    echo "########################"

    git clone https://github.com/ceph/ceph-ansible.git ${CEPH_ANSIBLE_DIR}

    # Patching
    if [ "$CEPH_ANSIBLE_VERSION" = "stable-5.0" ]; then
      ( cd "$CEPH_ANSIBLE_DIR" && patch -p1 < "$BASEDIR/patch/ceph-ansible-v2.9-limit.patch" )
    fi
fi

echo "###########################################################"
echo "# CHECKING OUT CEPH-ANSIBLE VERSION $CEPH_ANSIBLE_VERSION #"
echo "###########################################################"

cd ${CEPH_ANSIBLE_DIR} && git fetch && git checkout $CEPH_ANSIBLE_VERSION

if [ $? -gt 0 ]; then
  echo "Git checkout failed, check if $CEPH_ANSIBLE_DIR is not clean"
fi

echo "Write local cephrc"
cat << EOT > ${BASEDIR}/cephrc
ANSIBLE_MODULE=$ANSIBLE_MODULE
CEPHADM=$CEPHADM
CEPH_ANSIBLE_DIR=$CEPH_ANSIBLE_DIR
EOT


echo "Environment prepared for automation" 
