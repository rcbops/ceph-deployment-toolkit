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

#### Install Ansible 2.8.0

```
sudo add-apt-repository ppa:ansible/ansible
sudo apt update
sudo apt install ansible=2.8.0-1ppa~bionic
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

