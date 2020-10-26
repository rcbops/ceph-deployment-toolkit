# Ceph Nautilus (14.2.8) Install for Ubuntu 18.04+

It is assumed that all nodes have Ubuntu (18.04+) installed, and servers are accessible via ssh from the deployment node.

Unless specified otherwise, all commands are run from the deployment node. Usually, the deployment node is the first ceph node.

## Setup environment for automation

### Edit /etc/hosts to include all the ceph nodes with their host ips

Example

``` <text>
172.20.41.37 Bulbasaur
172.20.41.27 Squirtle
172.20.41.29 Charmander
172.20.41.41 Pikachu
172.20.41.45 Eevee
```

### Create ssh key and push the public key to the other ceph nodes

``` <bash>
ssh-keygen
<enter>
<enter>
<enter>
cat ~/.ssh/id_rsa.pub
```

#### Add the key to all ceph servers. Also, check for python and install if needed

``` <bash>
ssh-copyid  <hostname>
ssh <hostname> apt install python
```

### Setup Networking on all the ceph servers

Network requirements

* seperate networks for ceph frontend and backend networks
* active-active on both ceph frontend and backend networks
* jumbo frames on both ceph frontend and backend networks
* tunnel network is not needed

``` <text>
auto lo
iface lo inet loopback

auto em1
iface em1 inet manual
     bond-master bond0

auto p4p2
iface p4p2 inet manual
     bond-master bond0

auto bond0
iface bond0 inet static
    mtu 9000
    bond-mode 4
    bond_xmit_hash_policy layer3+4
    bond-lacp-rate 1
    bond-miimon 100
    slaves em1 p4p2
    address HOST_IP
    netmask 255.255.252.0
    gateway 10.240.0.1

auto em4
iface em4 inet manual
     bond-master bond1

auto p4p1
iface p4p1 inet manual
     bond-master bond1

auto bond1
iface bond1 inet manual
     mtu 9000
     bond-mode 4
     bond_xmit_hash_policy layer3+4
     bond-lacp-rate 1
     bond-miimon 100
     slaves em4 p4p1

auto em3
iface em3 inet static
    address SERVICENET_IP
    netmask 27
        post-up ip route add 10.191.192.0/18 via 10.141.35.225 dev em3
        pre-down ip route del 10.191.192.0/18 via 10.141.35.225 dev em3

# Container management VLAN interface (optional for RGW)
auto bond0.MGMT_VLAN
iface bond0.MGMT_VLAN inet manual
    mtu 1500
    vlan-raw-device bond0

# Storage network VLAN interface (REQUIRED)
auto bond0.STORE_VLAN
iface bond0.STORE_VLAN inet manual
    mtu 9000
    vlan-raw-device bond0

# Ceph Replication network (REQUIRED)
auto bond1.REPL_VLAN
iface bond1.REPL_VLAN inet manual
    mtu 9000
    vlan-raw-device bond1

# Management bridge  (Only needed for RGW)
auto br-mgmt
iface br-mgmt inet static
    mtu 1500
    bridge_stp off
    bridge_waitport 0
    bridge_fd 0
    # Bridge port references tagged interface
    bridge_ports bond0.MGMT_VLAN
    address MGMT_IP
    netmask 255.255.252.0

# Storage bridge (optional)
auto br-storage
iface br-storage inet static
    mtu 9000
    bridge_stp off
    bridge_waitport 0
    bridge_fd 0
    # Bridge port reference tagged interface
    bridge_ports bond0.STORE_VLAN
    address STORAGE_IP
    netmask 255.255.252.0

# Ceph Replication bridge (optional)
auto br-repl
iface br-repl inet static
    mtu 9000
    bridge_stp off
    bridge_waitport 0
    bridge_fd 0
    # Bridge port reference tagged interface
    bridge_ports bond1.REPL_VLAN
    address REPL_IP
    netmask 255.255.252.0

```

Reboot each node so that the network configs take.

#### Clone the ceph-toolkit repo onto the deployment host

``` <bash>
git clone <url of the repo> /opt/ceph-toolkit
```

#### Run script to install Ansible and clone Ceph-Ansible

``` <bash>
cd /opt/ceph-toolkit
bash scripts/prepare-deployment.sh
```

#### Create ceph_inventory.yaml file

``` <bash>
cd /opt/ceph-ansible
vim ceph_inventory.yaml
```

``` <YAML>
---
all:
  children:
    mons:
      hosts:
        Bulbasaur:
        Squirtle:
        Charmander:
        Pikachu:
        Eevee:
    mgrs:
      hosts:
        Bulbasaur:
        Squirtle:
        Charmander:
        Pikachu:
        Eevee:
    osds:
      hosts:
        Bulbasaur:
        Squirtle:
        Charmander:
        Pikachu:
        Eevee:
    rgws:
      hosts:
        Bulbasaur:
        Squirtle:
        Charmander:
        Pikachu:
        Eevee:
    grafana-server:
      hosts:
        Bulbasaur:
        Squirtle:
        Charmander:
        
```

#### Confirm that all servers report the correct drive type. Fix those that do not report correctly

All servers should match unless the customer is getting two tiers of storage

``` <bash>
source ../ceph-toolkit/ceph_deploy/bin/activate

ansible -i ceph_inventory.yaml all -m copy -a 'src=/opt/ceph-toolkit/scripts/ssd_rotational_fix.sh dest=/root/'

ansible -i ceph_inventory.yaml all -m shell -a 'bash /root/ssd_rotational_fix.sh'

```

### Reboot the node so udev rules take

``` <bash>
reboot & exit
```

### Verify Networking

Ensure all nodes can ping deployment node via frontend storage network:

``` <bash>
ansible -i ceph_inventory.yaml all -m shell -a 'ping -M do -s 8972 -c 3 DEPLOYMENT_STORAGE_IP'
```

Ensure all nodes can ping deployment node via backend replication network:

``` <bash>
ansible -i ceph_inventory.yaml all -m shell -a 'ping -M do -s 8972 -c 3 DEPLOYMENT_REPL_IP'
```

### Copy the premade files from the toolkit to ceph-ansible

``` <bash>
cp /opt/ceph-toolkit/defaults/all.default.yml /opt/ceph-ansible/group_vars/all.yml
cp /opt/ceph-toolkit/defaults/mons.default.yml /opt/ceph-ansible/group_vars/mons.yml
cp /opt/ceph-toolkit/defaults/osds.default.yml /opt/ceph-ansible/group_vars/osds.yml
cp /opt/ceph-toolkit/defaults/mgrs.default.yml /opt/ceph-ansible/group_vars/mgrs.yml
cp /opt/ceph-toolkit/defaults/nfss.default.yml /opt/ceph-ansible/group_vars/nfss.yml
cp /opt/ceph-toolkit/defaults/rgws.default.yml /opt/ceph-ansible/group_vars/rgws.yml
```

### Fill in the info in all.yml,osds.yml and rgws.yml. Read the instructions in each file

Come up with a secure password for these two values in all.yml

``` <text>
dashboard_admin_password
grafana_admin_password
```

### Run site.yml to deploy Ceph

Fill in the info in all.yml, osds.yml, and rgws.yml (if deploying rgw). Read the instructions in each file

### Run site.yml to deploy Ceph

``` <bash>
cd /opt/ceph-ansible
cp site.yml.sample site.yml
ansible-playbook -i ceph_inventory site.yml
```

### Set tunables and enable the balancer

``` <bash>
ceph osd set-require-min-compat-client nautilus
ceph mgr module enable balancer
ceph balancer mode upmap
ceph osd crush tunables optimal
ceph balancer on
```

### Enable the Ceph Dashboard

Record what the username and password are for the dashboard in a Runbook

``` <bash>
ceph mgr module enable dashboard
ceph dashboard create-self-signed-cert
ceph dashboard set-login-credentials <username> <password>
ceph mgr module disable dashboard
ceph mgr module enable dashboard
```

Check that the dashboard is enabled

```<bash>
ceph mgr services
```

Navigate to the dashboard and log in with the username/password you recorded from before
