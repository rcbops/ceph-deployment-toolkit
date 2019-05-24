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
##### Add the key to all servers. Also, check for python and install if needed

``` 
echo "$PUBLIC_KEY" >> ~/.ssh/authorized_keys
apt install python
```

#### clone the ceph-toolkit repo onto the deployment host

``` 
apt install -y git
git clone <url of the repo> /opt/ceph-toolkit
```

#### Run script to install Ansible and clone Ceph-Ansible

```
cd /opt/ceph-toolkit
bash scripts/prepare-deployment.sh
```

### Create inventory for the pre-deployment automation 
```
vim /opt/ceph-toolkit/env_inventory
```
example:
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
<placeholder>
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

For non-collocated, run

```
cd /opt/ceph-toolkit
ansible-playbook -i env_inventory -e @./drives.yml ./playbooks/common-playbooks/non-collocated-partitioning.yml
```

For collocated, run

```
cd /opt/ceph-toolkit
ansible-playbook -i env_inventory -e @./drives.yml ./playbooks/common-playbooks/collocated-partitioning.yml
```


### Setup Networking on all the ceph servers

Network requirements

* seperate networks for ceph frontend and backend networks
* active-active on both ceph frontend and backend networks
* jumbo frames on both ceph frontend and backend networks
* tunnel network is not needed

```
put example file here
```

## Start Ceph deployment

### Go into ceph-ansible and create inventory file

``` 
cd /opt/ceph-ansible
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
cp /opt/ceph-ansible/site.sample.yml /opt/ceph-ansible/site.yml
ansible-playbook -i ceph_inventory site.yml
```

