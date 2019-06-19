The finger of blame is a DoS detector that will give you the uuid of the VM or Volume in your openstack cloud that is overloading your ceph cluster. This is a good script to run when the cluster complains about slow requests. 

Run it like so:

```
bash finger_of_blame.sh -p <pool> -o <osd.id>
```

The script will increase the logging level of the osd being probed for 300 seconds, but will remove it once it is complete. If there is no output, run it again.


TODO: Make the length of time variable
