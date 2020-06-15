# Ceph Install for Ubuntu 18.04+

It is assumed that all nodes have Ubuntu (18.04+) installed, and servers are accessible via ssh from the deployment node.

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
ssh <hostname> apt install python
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

### Create inventory for the pre-deployment automation 
#### Servers that will require colocated partitioning need to be in a colocated group
#### Servers that will require non-colocated partitioning need to be in a noncolocated group

If you don't know what colocated or noncolocated is, see the glossary at the end of this doc.

```
vim /opt/ceph-toolkit/env_inventory
```
Example

```
[nodes]
Bulbasaur
Squirtle
Charmander
Pikachu
Eevee

[colocated]
Bulbasaur
Squirtle
Charmander

[noncolocated]
Pikachu
Eevee


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

### Prepare the drives.yml file for the type of environment you are deploying.

If you have a fast tier and slow tier of osd nodes, then it is recommended that you create a drives.yml file for each type of osd node and then use that file when running the corresponding partitioning playbook. 
 

* 4% of a single OSD drive size = db_size

* 2GB = wal_size

If you have all SSD drives, your drives.yml should be set up like this ...

```
---
wal_size: "2G"
db_size: "200G" # 30GB or 4% of a single osd drive size, whichever is larger

drives:
  ssd:
    sdb:
      name: ceph-data01
      db_lv: ceph-db01
      wal_lv: ceph-wal01
    sdc:
      name: ceph-data02
      db_lv: ceph-db02
      wal_lv: ceph-wal02
    sdd:
      name: ceph-data03
      db_lv: ceph-db03
      wal_lv: ceph-wal03
    sde:
      name: ceph-data04
      db_lv: ceph-db04
      wal_lv: ceph-wal04
    sdf:
      name: ceph-data05
      db_lv: ceph-db05
      wal_lv: ceph-wal05
    sdg:
      name: ceph-data06
      db_lv: ceph-db06
      wal_lv: ceph-wal06

```

If you have SSD Journals and HDD OSDs, your drives.yml should be set up like this ...

```
---
wal_size: "2G"
db_size: "200G" #  30GB or 4% of a single osd drive size, whichever is larger

drives:
  ssd:
    sdb:
      vg: ceph-ssd01
    sdc:
      vg: ceph-ssd02
  hdd:
    sde:
      name: ceph-data01
      db_lv: ceph-db01
      db_vg: ceph-ssd01
      wal_lv: ceph-wal01
      wal_vg: ceph-ssd01
    sdf:
      name: ceph-data02
      db_lv: ceph-db02
      db_vg: ceph-ssd01
      wal_lv: ceph-wal02
      wal_vg: ceph-ssd01
    sdg:
      name: ceph-data03
      db_lv: ceph-db03
      db_vg: ceph-ssd01
      wal_lv: ceph-wal03
      wal_vg: ceph-ssd01
    sdi:
      name: ceph-data04
      db_lv: ceph-db04
      db_vg: ceph-ssd02
      wal_lv: ceph-wal04
      wal_vg: ceph-ssd02
    sdj:
      name: ceph-data05
      db_lv: ceph-db05
      db_vg: ceph-ssd02
      wal_lv: ceph-wal05
      wal_vg: ceph-ssd02
    sdk:
      name: ceph-data06
      db_lv: ceph-db06
      db_vg: ceph-ssd02
      wal_lv: ceph-wal06
      wal_vg: ceph-ssd02
    sdd:
      name: ceph-data07
      db_lv: ceph-db07
      db_vg: ceph-ssd01
      wal_lv: ceph-wal07
      wal_vg: ceph-ssd01
    sdh:
      name: ceph-data08
      db_lv: ceph-db08
      db_vg: ceph-ssd02
      wal_lv: ceph-wal08
      wal_vg: ceph-ssd02

```

There are examples of both scenarios inside ./playbooks/vars/
Note that each HDD will use two LVs on the SSDs (one each for WAL and DB).  Verify that each SSD is large enough for all of the LVs to be created on it. If necessary, the wal_size and/or db_size may need to be reduced, but consult with the storage team if this is necessary.


### Run the partioning playbook for the type of environment you are trying to deploy. If you have both types, you need to run both.

For colocated, run

```
cd /opt/ceph-toolkit
ansible-playbook -i env_inventory -e @./drives.yml ./playbooks/common-playbooks/colocated-partitioning.yml
```

For non-colocated, run

```
cd /opt/ceph-toolkit
ansible-playbook -i env_inventory -e @./drives.yml ./playbooks/common-playbooks/non-colocated-partitioning.yml
```

### Set the performance scaling governor and disable cpu idle states

```
cd /opt/ceph-toolkit
ansible-playbook -i env_inventory ./playbooks/common-playbooks/cpu_tuning.yml
```

## Start Ceph deployment

### Go into ceph-ansible and create inventory file

``` 
cd /opt/ceph-ansible
source /opt/ceph-toolkit/ceph_deploy/bin/activate
vim ceph_inventory
```

Your inventory file should look like this

```
[mons]  # required
Bulbasaur
Squirtle
Charmander

[mgrs]  # required
Bulbasaur
Squirtle
Charmander

[osds]  # required
Bulbasaur
Squirtle
Charmander
Pikachu
Eevee

[mdss]  # only if customer is getting CephFS + Manila
Bulbasaur
Squirtle
Charmander

[nfss]  # only if customer is getting CephFS + Manila
Bulbasaur
Squirtle
Charmander

[rgws]  # only if customer is getting object storage with RGW
Bulbasaur
Squirtle
Charmander

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

### Fill in the info in all.yml and osds.yml. Read the instructions in each file.


### Run site.yml to deploy Ceph

```
cd /opt/ceph-ansible
cp site.yml.sample site.yml
ansible-playbook -i ceph_inventory site.yml
```

### Set tunables and enable the balancer 

```
ceph osd set-require-min-compat-client luminous
ceph mgr module enable balancer 
ceph balancer mode upmap
ceph osd crush tunables optimal 
ceph balancer on
```
### Enable the Ceph Dashboard

Record what the username and password are for the dashboard in a Runbook

```
ceph mgr module enable dashboard
ceph dashboard create-self-signed-cert
ceph dashboard set-login-credentials <username> <password>
ceph mgr module disable dashboard
ceph mgr module enable dashboard
```

Check that the dashboard is enabled
```
ceph mgr services
```
Navigate to the dashboard and log in with the username/password you recorded from before


__Glossary__

Colocated - Occurs when every single drive in a ceph cluster is a SSD. The wal and db partitions will share the SSD with the data partition


Non-Collocated - Occurs when there are HDD with a small number of SSDs. The HDD drives will hold the data partition while the SSDs will hold the wal and db partitions for each osd


OSD - Data drive


MON - Ceph 'monitor'. This is more like an infra node than like monitoring.


RGW - Rados Gateway. Ceph's Object Storage.


MDS - Ceph Metadata Server. Used for CephFS.




