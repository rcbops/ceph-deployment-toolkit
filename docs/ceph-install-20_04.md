
# DRAFT, IN EDIT

# Ceph Install for Ubuntu 20.04+

It is assumed that all nodes have Ubuntu (20.04+) installed, and servers are accessible via ssh from the deployment node.

Unless specified otherwise, all commands are run from the deployment node. Usually, the deployment node is the first ceph node.

## Setup environment for automation

### Edit /etc/hosts to include all the ceph nodes with their host ips

Example

```
172.20.41.37 Bulbasaur
172.20.41.27 Squirtle
172.20.41.29 Charmander
172.20.41.41 Pikachu
172.20.41.45 Eevee
```

### Create ssh key and push the public key to the other ceph nodes

```
ssh-keygen
<enter>
<enter>
<enter>
cat ~/.ssh/id_rsa.pub
```
#### Add the key to all ceph servers. Also, check for python and install if needed

```
ssh-copyid  <hostname>
ssh <hostname> apt install python3
```

#### Clone the ceph-toolkit repo onto the deployment host

```
git clone <url of the repo> /opt/ceph-toolkit
```

#### Run script to install Ansible and clone Ceph-Ansible

```
cd /opt/ceph-toolkit
bash scripts/prepare-deployment.sh
```

### Setup Networking on all the ceph servers

Network requirements

* seperate networks for ceph frontend and backend networks
* active-active on both ceph frontend and backend networks
* jumbo frames on both ceph frontend and backend networks
* tunnel network is not needed

```
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

### Verify Networking
Activate ansible virtual environment
```
cd /opt/ceph-ansible
ln -s /opt/ceph-toolkit/ceph_deploy venv
source venv/bin/activate
```
Ensure all nodes can ping deployment node via frontend storage network:
```
ansible -i env_inventory all -m shell -a 'ping -M do -s 8972 -c 3 DEPLOYMENT_STORAGE_IP'
```
Ensure all nodes can ping deployment node via backend replication network:
```
ansible -i env_inventory all -m shell -a 'ping -M do -s 8972 -c 3 DEPLOYMENT_REPL_IP'
```

If these commands hang, double check that the switches are properly configured for jumbo frames.

(consider verifying network throughput as well. iperf?)

## Start Ceph deployment

### Go into ceph-ansible and create inventory file

```
ln -s ceph_inventory.yml ceph_inventory
vim ceph_inventory.yml
```

Your inventory file should look like this

```
---
all:
  children:
    mons:   # required
      hosts:
        Bulbasaur:
        Squirtle:
        Charmander:
    mgrs:   # required
      hosts:
        Bulbasaur:
        Squirtle:
        Charmander:
    osds:   # required
      hosts:
        Bulbasaur:
        Squirtle:
        Charmander:
        Pikachu:
        Eevee:
    grafana-server:   #required
      hosts:
        Bulbasaur:
    rgws:  # only if customer is getting object storage with RGW
      hosts:
        Bulbasaur:
        Squirtle:
        Charmander:
    mdss:  # only if customer is getting CephFS + Manila
      hosts:
        Bulbasaur:
        Squirtle:
        Charmander:
    nfss:  # only if customer is getting CephFS + Manila
      hosts:
        Bulbasaur:
        Squirtle:
        Charmander:
```

### Copy the premade files from the toolkit to ceph-ansible

```
cp /opt/ceph-toolkit/defaults/all.default.yml /opt/ceph-ansible/group_vars/all.yml
cp /opt/ceph-toolkit/defaults/mons.default.yml /opt/ceph-ansible/group_vars/mons.yml
cp /opt/ceph-toolkit/defaults/osds.default.yml /opt/ceph-ansible/group_vars/osds.yml
cp /opt/ceph-toolkit/defaults/mgrs.default.yml /opt/ceph-ansible/group_vars/mgrs.yml
cp /opt/ceph-toolkit/defaults/nfss.default.yml /opt/ceph-ansible/group_vars/nfss.yml
cp /opt/ceph-toolkit/defaults/rgws.default.yml /opt/ceph-ansible/group_vars/rgws.yml
```

### Fill in the info in all.yml, osds.yml and rgws.yml. Read the instructions in each file.


### Run site.yml to deploy Ceph

```
cd /opt/ceph-ansible
ln -sf site.yml.sample site.yml
ansible-playbook -i ceph_inventory site.yml
```

### Set tunables and enable the balancer

```
ceph osd set-require-min-compat-client octopus
ceph balancer mode upmap
ceph osd crush tunables optimal
ceph balancer on
```

### Enable the Ceph Dashboard

Check that the dashboard is enabled
```
ceph mgr services
```
Navigate to the dashboard and log in with the username/password you recorded from before


### Set the performance scaling governor and disable cpu idle states

```
cd /opt/ceph-toolkit
ansible-playbook -i /opt/ceph-ansible/ceph_inventory ./playbooks/common-playbooks/cpu_tuning.yml
```

### If RadosGW (swift/S3) services are required, reference rados_gateway_install.md


__Glossary__

Colocated - Occurs when every single drive in a ceph cluster is a SSD. The wal and db partitions will share the SSD with the data partition


Non-Collocated - Occurs when there are HDD with a small number of SSDs. The HDD drives will hold the data partition while the SSDs will hold the wal and db partitions for each osd


OSD - Data drive


MON - Ceph 'monitor'. This is more like an infra node than like monitoring.


RGW - Rados Gateway. Ceph's Object Storage.


MDS - Ceph Metadata Server. Used for CephFS.


