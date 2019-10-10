# Adding Ceph Nodes/Drives

---

### Check that the ceph cluster is running the upmap balancer

```
ceph balancer status
```

##### Example output:

```
root@Vaporeon:~# ceph balancer status
{
    "active": true, 
    "plans": [], 
    "mode": "upmap"
}
```


### If the cluster does not have the upmap balancer set, this process will not work

---


### Configure the lvm partitions on the new drives to be added

##### For adding drives to existing nodes

Colocated example (replace XX with the correct numbering)
```
    <new drive>:
      name: ceph-dataXX
      db_lv: ceph-dbXX
      wal_lv: ceph-walXX
```

Dedicated example (replace XX with the correct numbering)
```
    <new drive>:
      name: ceph-dataXX
      db_lv: ceph-dbXX
      db_vg: ceph-ssdXX
      wal_lv: ceph-walXX
      wal_vg: ceph-ssdXX
```

##### For adding new osd nodes

If the new nodes match existing nodes, add the node to the env_inventory

``` 
vim /opt/ceph-toolkit/env_inventory
```

---
### Run Partitioning playbook

Drives with existing partitions will fail. New drives will be partitioned. 

```
cd /opt/ceph-toolkit
source ./ceph_deploy/bin/activate
ansible-playbook -i env_inventory ./playbooks/<correct partitioning playbook>
ansible -i env_inventory all -m shell -a 'lsblk'
```
---

### Configure ceph-ansible

##### For adding a new drive

If you are adding a drive to all ceph nodes (not a new node, but expanding the capacity of exiting servers), add the new drive to osds.yml

```
vim /opt/ceph-ansible/group-vars/osds.yml
```

If you are adding a drive of a different medium to existing ceph servers, or if all nodes will not share the same drive layout as a result of adding the drives, add the new drive to the ceph_inventory file. 

---

##### For adding a new node


If you are adding servers that share the same drive config as all others in the ceph cluster, you should only have to add the node to the ceph_inventory file

``` 
vim /opt/ceph-ansible/ceph_inventory
```

Add the node under `[osds]`

If you are adding servers that are different than the existing servers, you will have to add both the servers and the drive config to the ceph_inventory file. This will most likely be in YAML syntax.

```
vim /opt/ceph_inventory.yml
```

##### Example Config -> Dedicated 

```
        Leafeon:
          osd_scenario: lvm
          lvm_volumes:
            - data: ceph-data01
              data_vg: ceph-data01
              db: ceph-db01
              db_vg: ceph-ssd01
              wal: ceph-wal01
              wal_vg: ceph-ssd01
            - data: ceph-data02
              data_vg: ceph-data02
              db: ceph-db02
              db_vg: ceph-ssd01
              wal: ceph-wal02
              wal_vg: ceph-ssd01
            - data: ceph-data03
              data_vg: ceph-data03
              db: ceph-db03
              db_vg: ceph-ssd01
              wal: ceph-wal03
              wal_vg: ceph-ssd01

            ect.
```

##### Example Config -> Colocated 

```
        Glaceon:
          osd_scenario: lvm
          lvm_volumes:
            - data: ceph-data01
              data_vg: ceph-data01
              db: ceph-db01
              db_vg: ceph-data01
              wal: ceph-wal01
              wal_vg: ceph-data01
            - data: ceph-data02
              data_vg: ceph-data02
              db: ceph-db02
              db_vg: ceph-data02
              wal: ceph-wal02
              wal_vg: ceph-data02
            - data: ceph-data03
              data_vg: ceph-data03
              db: ceph-db03
              db_vg: ceph-data03
              wal: ceph-wal03
              wal_vg: ceph-data03
        
            ect.
```

---

### Set the needed flags to prevent rebalance from occuring

```
ceph osd set norecover
ceph osd set norebalance
```
---


### Run the add-osd.yml playbook with the no-restart variables added

```
grep -q tmux.log 2>/dev/null ~/.tmux.conf || cat << _EOF >> ~/.tmux.conf
bind-key H pipe-pane -o "exec cat >>$HOME/'#W-tmux.log'" \; display-message 'Toggled logging to $HOME/#W-tmux.log'
_EOF

tmux new -s ceph_osd_addition
cd /opt/ceph-ansible
source /opt/ceph-toolkit/ceph_deploy/bin/activate
cp ./infrastructure-playbooks/add-osd.yml ./add-osd.yml
ansible-playbook -i ceph_inventory ./add-osd.yml -e @/opt/ceph-toolkit/playbooks/vars/disable-restarts.yml
```

The playbooks will enable a `noin` flag. This is expected and the playbook will remove it once complete. 

Many pgs will be in a `remapped` status, this is expected.

---

### Map the pgs back to the drives where they already exist

You will have to run this script multiple times, and not all pgs will go out of the `remapped` status. Stop running it once the number of `remapped` pgs does not decrease.

```
python /opt/ceph-toolkit/scripts/upmap-remapped.py | sh
```

---

### Confirm that the drives are added with the correct drive medium associated with them

``` 
ceph osd tree | grep <new osd ids> 
```

If they are incorrect, run the following

```
ceph osd crush rm-device-class osd.<id>
ceph osd crush set-device-class <hdd or ssd> osd.<id>
```

---

### Unset flags 

Some data will move, but it should be quick

```
ceph osd unset norecover
ceph osd unset norebalance

watch ceph -s 
```

---

### Monitor balancer activity

PGs will move over the course of a few days/weeks, depending on the size of the cluster

``` 
ceph -w
```
---

The osds have been added. Deploy your monitoring for the new osds. 
