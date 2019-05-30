# Ceph Install for Ubuntu 18.04+


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
echo "PUBLIC_KEY" >> ~/.ssh/authorized_keys
apt install python
```

#### Clone the ceph-toolkit repo onto the deployment host

``` 
apt install -y git
git clone <url of the repo> /opt/ceph-toolkit
```

#### Run script to install Ansible and clone Ceph-Ansible

```
cd /opt/ceph-toolkit
virtualenv venv
. venv/bin/activate
bash scripts/prepare-deployment.sh
```

### Create inventory for the pre-deployment automation 
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
```

### Prepare the drives.yml file for the type of environment you are deploying 

* 4% of your OSD drive size = db_size

* 2GB = wal_size

If you have all SSD drives, your drives.yml should be set up like this ...

```
---
wal_size: "2G"
db_size: "200G" # 4% of the drive size

drives:
  ssd:
    sdb:
      name: ceph-data1
      db_lv: ceph-db1
      wal_lv: ceph-wal1
    sdc:
      name: ceph-data2
      db_lv: ceph-db2
      wal_lv: ceph-wal2
    sdd:
      name: ceph-data3
      db_lv: ceph-db3
      wal_lv: ceph-wal3
    sde:
      name: ceph-data4
      db_lv: ceph-db4
      wal_lv: ceph-wal4
    sdf:
      name: ceph-data5
      db_lv: ceph-db5
      wal_lv: ceph-wal5
    sdg:
      name: ceph-data6
      db_lv: ceph-db6
      wal_lv: ceph-wal6

```

If you have SSD Journals and HDD OSDs, your drives.yml should be set up like this ...

```
---
wal_size: "2G"
db_size: "200G" # 4% of osd drive size

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


### Run the partioning playbook for the type of environment you are trying to deploy

For collocated, run

```
cd /opt/ceph-toolkit
ansible-playbook -i env_inventory -e @./drives.yml ./playbooks/common-playbooks/collocated-partitioning.yml
```

For non-collocated, run

```
cd /opt/ceph-toolkit
ansible-playbook -i env_inventory -e @./drives.yml ./playbooks/common-playbooks/non-collocated-partitioning.yml
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

## Start Ceph deployment

### Go into ceph-ansible and create inventory file

``` 
cd /opt/ceph-ansible
ln -s /opt/ceph-toolkit/venv venv
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
cp /opt/ceph-toolkit/playbooks/vars/all.default.yml /opt/ceph-ansible/group_vars/all.yml
cp /opt/ceph-toolkit/playbooks/vars/mons.default.yml /opt/ceph-ansible/group_vars/mons.yml
cp /opt/ceph-toolkit/playbooks/vars/osds.default.yml /opt/ceph-ansible/group_vars/osds.yml
cp /opt/ceph-toolkit/playbooks/vars/mgrs.default.yml /opt/ceph-ansible/group_vars/mgrs.yml
cp /opt/ceph-toolkit/playbooks/vars/nfss.default.yml /opt/ceph-ansible/group_vars/nfss.yml
cp /opt/ceph-toolkit/playbooks/vars/rgws.default.yml /opt/ceph-ansible/group_vars/rgws.yml
```

### Fill in the info in all.yml and osds.yml. Read the instructions in each file.


### Run site.yml to deploy Ceph

```
cd /opt/ceph-ansible
ln -s site.sample.yml site.yml
ansible-playbook -i ceph_inventory site.yml
```

