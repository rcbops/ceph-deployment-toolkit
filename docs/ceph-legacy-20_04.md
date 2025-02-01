
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
bash scripts/prepare-deployment.sh <ceph-ansible branch>
```


### Setup Networking on all the ceph servers

Network requirements

* seperate networks for ceph frontend and backend networks
* active-active on both ceph frontend and backend networks
* jumbo frames on both ceph frontend and backend networks
* tunnel network is not needed

```
network:
    version: 2
    ethernets:
      em49:
        mtu: 9000
      em50:
        mtu: 9000
      p4p1:
        mtu: 9000
      p4p2:
        mtu: 9000
    bonds:
      bond0:
        interfaces: [ em49, p4p1 ]
        parameters:
          mode: 802.3ad
          lacp-rate: fast
          transmit-hash-policy: layer2+3
          mii-monitor-interval: 100
        dhcp4: false
        mtu: 9000
      bond1:
        interfaces: [ em50, p4p2 ]
        parameters:
          mode: 802.3ad
          lacp-rate: fast
          transmit-hash-policy: layer2+3
          mii-monitor-interval: 100
        dhcp4: false
        mtu: 9000
    bridges:
      br-bond0:
        dhcp4: false
        mtu: 1500
        interfaces:
          - bond0
      br-host:
        dhcp4: false
        mtu: 1500
        interfaces:
          - vlan1000
        addresses: [ 10.240.0.51/22 ]
        nameservers:
          addresses: [ 1.1.1.1, 1.0.0.1 ]
        routes:
          - to: 0.0.0.0/0
            via: 10.240.0.1
            metric: 500
      br-mgmt:
        dhcp4: false
        mtu: 1500
        interfaces:
          - vlan1010
        addresses: [ 172.29.236.51/22 ]
      br-storage:
        dhcp4: false
        mtu: 9000
        interfaces:
          - vlan1030
        addresses: [ 172.29.244.51/22 ]
      br-repl:
        dhcp4: false
        mtu: 9000
        interfaces:
          - vlan1040
        addresses: [ 172.29.248.51/22 ]
    vlans:
      vlan1000:
        id: 1000
        link: bond0
        dhcp4: false
        mtu: 1500
      vlan1010:
        id: 1010
        link: bond0
        dhcp4: false
        mtu: 1500
      vlan1030:
        id: 1030
        link: bond0
        dhcp4: false
        mtu: 9000
      vlan1040:
        id: 1040
        link: bond1
        dhcp4: false
        mtu: 9000
```

Reboot each node so that the network configs take.

## Start Ceph deployment

### Go into ceph-ansible and create inventory file

```
cd /opt/ceph-ansible
```

Your inventory file should look like this

```
cat << EOT > ceph_inventory.yml
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
EOT
```


### Verify Networking
Activate ansible virtual environment
```
cd /opt/ceph-ansible
ln -s /opt/ceph-toolkit/ceph_deploy venv
source venv/bin/activate
```
Ensure all nodes can ping deployment node via frontend storage network:
```
ansible -i ceph_inventory.yml all -m shell -a 'ping -M do -s 8972 -c 3 DEPLOYMENT_STORAGE_IP'
```
Ensure all nodes can ping deployment node via backend replication network:
```
ansible -i ceph_inventory.yml all -m shell -a 'ping -M do -s 8972 -c 3 DEPLOYMENT_REPL_IP'
```

If these commands hang, double check that the switches are properly configured for jumbo frames.

(consider verifying network throughput as well. iperf?)


### Copy the pre-made files from the toolkit to ceph-ansible

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
. /opt/ceph-toolkit/ceph_deploy/bin/activate

cd /opt/ceph-ansible
ln -sf site.yml.sample site.yml
ansible-playbook -i ceph_inventory.yml site.yml
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
ansible-playbook -i /opt/ceph-ansible/ceph_inventory.yml ./playbooks/common-playbooks/cpu_tuning.yml
```

### If RadosGW (swift/S3) services are required, reference rados_gateway_install.md



__Glossary__

Colocated - Occurs when every single drive in a ceph cluster is a SSD. The wal and db partitions will share the SSD with the data partition


Non-Collocated - Occurs when there are HDD with a small number of SSDs. The HDD drives will hold the data partition while the SSDs will hold the wal and db partitions for each osd


OSD - Data drive


MON - Ceph 'monitor'. This is more like an infra node than like monitoring.


RGW - Rados Gateway. Ceph's Object Storage.


MDS - Ceph Metadata Server. Used for CephFS.



