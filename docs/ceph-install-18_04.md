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
<placeholder>
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

[mgrs]  # required

[osds]  # required

[mdss]  # only if customer is getting CephFS + Manila

[nfss]  # only if customer is getting CephFS + Manila

[rgws]  # only if customer is getting object storage with RGW


```


