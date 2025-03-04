# Ceph Install for Ubuntu 20.04 and later

It is assumed that all nodes have Ubuntu installed, and servers are accessible via ssh from the deployment node.

Unless specified otherwise, all commands are run from the deployment node. Usually, the deployment node is the first ceph node.

## Setup environment for automation

### Edit /etc/hosts to include all the ceph nodes with their host ips

Example

```
172.20.41.10 host1
172.20.41.11 host2
172.20.41.12 host3
172.20.41.13 host4
172.20.41.14 host5
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

bash scripts/prepare-deployment.sh <ceph-ansible-branch>
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
  hosts:
    host1:
      ansible_host: 172.20.41.10
    host2:
      ansible_host: 172.20.41.11
    host3:
      ansible_host: 172.20.41.12
    host4:
      ansible_host: 172.20.41.13
    host5:
      ansible_host: 172.20.41.14
  children:
    mons:   # required
      hosts:
        host1:
        host2:
        host3:
    mgrs:   # required
      hosts:
        host1:
        host2:
        host3:
    osds:   # required
      hosts:
        host1:
        host2:
        host3:
        host4:
        host5:
    monitoring:   #required
      hosts:
        host1:
    rgws:  # only if customer is getting object storage with RGW
      hosts:
        host1:
        host2:
        host3:
    mdss:  # only if customer is getting CephFS + Manila
      hosts:
        host1:
        host2:
        host3:
    nfss:  # only if customer is getting CephFS + Manila
      hosts:
        host1:
        host2:
        host3:
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
```

### Fill in the info in all.yml. Read the instructions in the file.



### Run cephadm.yml to deploy Ceph

```
. /opt/ceph-toolkit/ceph_deploy/bin/activate

cd /opt/ceph-ansible
ln -sf infrastructure-playbooks/cephadm.yml cephadm.yml
ansible-playbook -i ceph_inventory.yml cephadm.yml
```

### Confirm all nodes have been added and labeled, and mon/mgr/monitoring services are running

```
cephadm shell -m /opt/ceph-toolkit:/opt/ceph-toolkit /opt/cephadm-specs:/opt/cephadm-specs
ceph -s
ceph orch host ls
ceph orch ls
```

### Export the node and service specs

```
ceph orch host ls --format yaml |tee /opt/cephadm-specs/cluster-nodes.yml
ceph orch ls --format yaml |tee /opt/cephadm-specs/services.yml
```

### Import default configs

```
ceph config assimilate-conf -i /opt/ceph-toolkit/defaults/cephadm/default_ceph.conf
ceph config dump
```

### Enable logging to files

```
ceph config set global log_to_file true
ceph config set global mon_cluster_log_to_file true
ceph config set global log_to_stderr false
ceph config set global mon_cluster_log_to_stderr false
```

### Create the osds

```
cp /opt/ceph-toolkit/defaults/cephadm/osd_specs/{example} /opt/cephadm-specs/osds.yml
# customize osd spec or multiple specs as required

ceph orch apply -i /opt/cephadm-specs/osds.yml
ceph orch ls
```

### Create rgws if necessary
 
```
cp /opt/ceph-toolkit/defaults/cephadm/other_specs/rgws.yml /opt/cephadm-specs/rgws.yml
# edit /opt/cephadm-specs/rgws.yml with correct network
 
ceph orch apply -i /opt/cephadm-specs/rgws.yml
ceph config set client.rgw.radosgw rgw_keystone_api_version 3
ceph config set client.rgw.radosgw rgw_keystone_url "<INTERNAL KEYSTONE ENDPOINT>"
ceph config set client.rgw.radosgw rgw_keystone_admin_user "swift"
ceph config set client.rgw.radosgw rgw_keystone_admin_password "<PASSWORD FROM OPENSTACK>"
ceph config set client.rgw.radosgw rgw_keystone_admin_tenant "service"
ceph config set client.rgw.radosgw rgw_keystone_admin_domain "default"
ceph config set client.rgw.radosgw rgw_keystone_accepted_roles "Member, _member_, admin"
ceph config set client.rgw.radosgw rgw_keystone_token_cache_size "10000"
ceph config set client.rgw.radosgw rgw_s3_auth_use_keystone "true"
ceph config set client.rgw.radosgw rgw_swift_account_in_url "true"
ceph config set client.rgw.radosgw rgw_keystone_implicit_tenants "true"
```

( the above needs to be tested thoroughly )

### Enable the Ceph Dashboard

### Set the performance scaling governor and disable cpu idle states

```
exit

cd /opt/ceph-toolkit
source ceph_deploy/bin/activate
ansible-playbook -i /opt/ceph-ansible/ceph_inventory.yml ./playbooks/common-playbooks/cpu_tuning.yml
```

### Install OpenStack integration

The ceph pool creation for openstack functionality moved to the openstack-ops module and is typically executed from the deployment host, controller1 for example: 

```
cd /opt/openstack-ops/playbooks
openstack-ansible -i <ceph inventory file> configure-ceph.yml -e ceph_stable_release=quincy
```

Ensure that `ceph_stable_release` is either set per `/etc/openstack_deploy` or command line as ceph client will be installed onto the ceph monitor
regardless if the ceph deployment is containerized or not.
OSA at this point does not support cephadm and as workaround we install a ceph client onto the monitor nodes.


### Glossary

Colocated - Occurs when every single drive in a ceph cluster is a SSD. The wal and db partitions will share the SSD with the data partition


Non-Collocated - Occurs when there are HDD with a small number of SSDs. The HDD drives will hold the data partition while the SSDs will hold the wal and db partitions for each osd


OSD - Data drive


MON - Ceph 'monitor'. This is more like an infra node than like monitoring.


RGW - Rados Gateway. Ceph's Object Storage.


MDS - Ceph Metadata Server. Used for CephFS.



