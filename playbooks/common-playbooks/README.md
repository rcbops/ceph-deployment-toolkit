# Playbooks to do common things that will happen when creating/maintaining a ceph cluster


| Playbook                        | Description                                                                                          |
| --------------------------------|------------------------------------------------------------------------------------------------------| 
| colocated-partitioning.yml      | Create partitions for when the ceph cluster only has SSDs in it (the collocated scenario)            |
| non-collocated-partitioning.yml | Create partitions for when the ceph cluster has HDDs with SSD journals (the non-collocated scenario) |
| cpu_tuning.yml                  | Sets the scaling governor to performance and disables the CPU states 2,3,4                           |
