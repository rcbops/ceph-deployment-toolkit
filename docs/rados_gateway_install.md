## Rados Gateway Configuration for Openstack Swift API 

Rados Gateway is the Object Storage service provided by Ceph. It exposes a Swift and Amazon S3 API for clients 
to consume their Ceph storage cluster. This is the installation process to first install Rados Gateway, and 
then expose it to the Openstack Environment. 

### Rados Gateway Installation 

These steps are executed from the Ceph Deployment node. (typically the first ceph mon node)

#### Add [rgws] to the ceph_inventory file in ceph-ansible

Typically, these will be the same as the ceph-mon nodes unless otherwise stated. 

```
cd /opt/ceph-ansible
vim ceph_inventory 
```

Example:

```
[rgws]
Articuno
Zapdos
Moltres
```
#### Copy the default rgw file from ceph-toolkit and into ceph-ansible. 

You will need the following to fill in the document

  * The Openstack Management Network
  * The Internal Load Balancer VIP 
  * The Swift User Password Created by Openstack-Ansible (typically in /etc/openstack_deploy/user_secrets.yml)

```
cp /opt/ceph-toolkit/defaults/rgws.default/yml /opt/ceph-ansible/group_vars/rgws.yml
vim /opt/ceph-ansible/group_vars/rgws.yml
```

#### Run site.yml

```
source /opt/ceph-toolkit/venv/bin/activate
cd /opt/ceph-ansible
ansible-playbook -i ceph_inventory -e @/opt/ceph-toolkit/playbooks/vars/disable-restarts.yml site.yml
```

#### Confirm that the correct values have been deployed to the Rados Gateway nodes

You will need to run this command from the Rados Gateway nodes


```
ceph daemon /var/run/ceph/ceph-client.rgw.(hostname).asok config show | grep keystone
```

Confirm that the **User**,**password**, and **keystone endpoint** are correct.

### Openstack Configuration 

These steps will be executed from a location where the openstack client is installed and working. (For example, the utility container in Openstack Queens)

You will need:

  * The Internal Load Balancer VIP
  * The External Load Balancer VIP
  * The SAME Swift User Password you used to install Rados Gateway

### Execute the following commands

**Double check that all values are correct before execution. ESPECIALLY THE SWIFT PASSWORD**

```
openstack service create --name=swift --description="Swift Service" object-store

openstack endpoint create swift --region RegionOne public "https://{EXTERNAL_VIP}:8080/swift/v1/%(tenant_id)s"

openstack endpoint create swift --region RegionOne admin "http://{INTERNAL_VIP}:8080/swift/v1/%(tenant_id)s"

openstack endpoint create swift --region RegionOne internal "http://{INTERNAL_VIP}:8080/swift/v1/%(tenant_id)s"

openstack user create swift --project service --password {Swift Service Password}

openstack role add --project service --user swift admin
```

### Test Swift Functionality

``` 
source openrc
swift stat --debug

swift upload test <put a test file here>
swift stat
rm <put a test file here>
swift download test <put a test file here>
```

