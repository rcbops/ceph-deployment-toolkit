
# Ceph Post Install QC

## This is for Greenfield clusters only. Not Ceph node additions

This is meant to be run after the Ceph install, but before the Openstack install. 
The aim is to both test the underlying infrastructure, and benchmark the cluster 
before starting the Openstack installation so there are no issues that can be masked 
by Openstack.

It is broken down into 4 main parts

1. Network Validation
2. Drive Partitioning Validation
3. RBD Functionality / Benchmarking
4. Rados GW Functionality / Benchmarking


## Part 1: Network Validation

The goal here is to determine if the Ceph cluster has consistent network throughput 
throughout the cluster. You will need to test the network throughput within a rack 
to confirm that the ToR switch is functioning as expected, and across racks to confirm
that the cross connects are functioning as expected. 



Install iperf3 to all ceph nodes

```
source /opt/ceph-toolkit/venv/bin/activate
cd /opt/ceph-ansible
ansible -i ceph_inventory all -m apt -a "name=iperf3 state=present"
```

You will need to test both the storage network (br-storage) and the replication network (br-repl)

Check that the node has both networks

```
ip a l | grep 'storage\|repl'
```

On the first node that has both networks, you will start the iperf3 server

```
iperf3 --server
```

Run the network test from ceph01

```
ansible -i ceph_inventory all -m shell -a 'iperf3 -i 0 -c ${BR-STORAGE IP OF IPERF3 SERVER}' --limit 'all:!{IPERF3 SERVER}' --forks 1
ansible -i ceph_inventory all -m shell -a 'iperf3 -i 0 -c ${BR-REPL IP OF IPERF3 SERVER}' --limit 'all:!{IPERF3 SERVER}' --forks 1
```

All of your Bandwidth speeds should be close to the same. More importantly, they 
should match up with the network speeds that your network is supposed to give. 
For example: A 10G Network should give around 9.3 Gbps, a 1G network should give
around 937 Mbps.

Example Output

#### From Clients

```
root@Flareon:/opt/ceph-ansible# ansible -i ceph_inventory all -m shell -a 'iperf3 -i 0 -c 172.29.244.62' --limit 'all:!Jolteon' --forks 1
Flareon | SUCCESS | rc=0 >>
Connecting to host 172.29.244.62, port 5201
[  4] local 172.29.244.61 port 43654 connected to 172.29.244.62 port 5201
[ ID] Interval           Transfer     Bandwidth       Retr  Cwnd
[  4]   0.00-10.00  sec  1.09 GBytes   936 Mbits/sec  245    379 KBytes       
- - - - - - - - - - - - - - - - - - - - - - - - -
[ ID] Interval           Transfer     Bandwidth       Retr
[  4]   0.00-10.00  sec  1.09 GBytes   936 Mbits/sec  245             sender
[  4]   0.00-10.00  sec  1.09 GBytes   934 Mbits/sec                  receiver

iperf Done.

Vaporeon | SUCCESS | rc=0 >>
Connecting to host 172.29.244.62, port 5201
[  4] local 172.29.244.63 port 38790 connected to 172.29.244.62 port 5201
[ ID] Interval           Transfer     Bandwidth       Retr  Cwnd
[  4]   0.00-10.00  sec  1.09 GBytes   937 Mbits/sec  181    379 KBytes       
- - - - - - - - - - - - - - - - - - - - - - - - -
[ ID] Interval           Transfer     Bandwidth       Retr
[  4]   0.00-10.00  sec  1.09 GBytes   937 Mbits/sec  181             sender
[  4]   0.00-10.00  sec  1.09 GBytes   935 Mbits/sec                  receiver

iperf Done.

Espeon | SUCCESS | rc=0 >>
Connecting to host 172.29.244.62, port 5201
[  4] local 172.29.244.64 port 35454 connected to 172.29.244.62 port 5201
[ ID] Interval           Transfer     Bandwidth       Retr  Cwnd
[  4]   0.00-10.00  sec  1.09 GBytes   937 Mbits/sec  250    202 KBytes       
- - - - - - - - - - - - - - - - - - - - - - - - -
[ ID] Interval           Transfer     Bandwidth       Retr
[  4]   0.00-10.00  sec  1.09 GBytes   937 Mbits/sec  250             sender
[  4]   0.00-10.00  sec  1.09 GBytes   935 Mbits/sec                  receiver

iperf Done.

Umbreon | SUCCESS | rc=0 >>
Connecting to host 172.29.244.62, port 5201
[  4] local 172.29.244.65 port 53798 connected to 172.29.244.62 port 5201
[ ID] Interval           Transfer     Bandwidth       Retr  Cwnd
[  4]   0.00-10.00  sec  1.09 GBytes   937 Mbits/sec  207    373 KBytes       
- - - - - - - - - - - - - - - - - - - - - - - - -
[ ID] Interval           Transfer     Bandwidth       Retr
[  4]   0.00-10.00  sec  1.09 GBytes   937 Mbits/sec  207             sender
[  4]   0.00-10.00  sec  1.09 GBytes   935 Mbits/sec                  receiver

iperf Done.

```

#### From Server

```
root@Jolteon:~# iperf3 --server
-----------------------------------------------------------
Server listening on 5201
-----------------------------------------------------------
Accepted connection from 172.29.244.61, port 43542
[  5] local 172.29.244.62 port 5201 connected to 172.29.244.61 port 43544
[ ID] Interval           Transfer     Bandwidth
[  5]   0.00-1.00   sec   107 MBytes   900 Mbits/sec                  
[  5]   1.00-2.00   sec   112 MBytes   936 Mbits/sec                  
[  5]   2.00-3.00   sec   112 MBytes   936 Mbits/sec                  
[  5]   3.00-4.00   sec   111 MBytes   933 Mbits/sec                  
[  5]   4.00-5.00   sec   111 MBytes   935 Mbits/sec                  
[  5]   5.00-6.00   sec   111 MBytes   935 Mbits/sec                  
[  5]   6.00-7.00   sec   111 MBytes   933 Mbits/sec                  
[  5]   7.00-8.00   sec   112 MBytes   937 Mbits/sec                  
[  5]   8.00-9.00   sec   111 MBytes   934 Mbits/sec                  
[  5]   9.00-10.00  sec   112 MBytes   937 Mbits/sec                  
[  5]  10.00-10.04  sec  4.19 MBytes   941 Mbits/sec                  
- - - - - - - - - - - - - - - - - - - - - - - - -
[ ID] Interval           Transfer     Bandwidth       Retr
[  5]   0.00-10.04  sec  1.09 GBytes   934 Mbits/sec  159             sender
[  5]   0.00-10.04  sec  1.09 GBytes   931 Mbits/sec                  receiver
-----------------------------------------------------------
Server listening on 5201
-----------------------------------------------------------
Accepted connection from 172.29.244.65, port 53242
[  5] local 172.29.244.62 port 5201 connected to 172.29.244.65 port 53244
[ ID] Interval           Transfer     Bandwidth
[  5]   0.00-1.00   sec   108 MBytes   903 Mbits/sec                  
[  5]   1.00-2.00   sec   111 MBytes   934 Mbits/sec                  
[  5]   2.00-3.00   sec   111 MBytes   935 Mbits/sec                  
[  5]   3.00-4.00   sec   112 MBytes   936 Mbits/sec                  
[  5]   4.00-5.00   sec   112 MBytes   937 Mbits/sec                  
[  5]   5.00-6.00   sec   111 MBytes   935 Mbits/sec                  
[  5]   6.00-7.00   sec   111 MBytes   934 Mbits/sec                  
[  5]   7.00-8.00   sec   111 MBytes   934 Mbits/sec                  
[  5]   8.00-9.00   sec   111 MBytes   935 Mbits/sec                  
[  5]   9.00-10.00  sec   112 MBytes   936 Mbits/sec                  
[  5]  10.00-10.03  sec  3.91 MBytes   942 Mbits/sec                  
- - - - - - - - - - - - - - - - - - - - - - - - -
[ ID] Interval           Transfer     Bandwidth       Retr
[  5]   0.00-10.03  sec  1.09 GBytes   933 Mbits/sec  248             sender
[  5]   0.00-10.03  sec  1.09 GBytes   932 Mbits/sec                  receiver
-----------------------------------------------------------
Server listening on 5201
-----------------------------------------------------------
Accepted connection from 172.29.244.61, port 43652
[  5] local 172.29.244.62 port 5201 connected to 172.29.244.61 port 43654
[ ID] Interval           Transfer     Bandwidth
[  5]   0.00-1.00   sec   107 MBytes   901 Mbits/sec                  
[  5]   1.00-2.00   sec   111 MBytes   935 Mbits/sec                  
[  5]   2.00-3.00   sec   111 MBytes   934 Mbits/sec                  
[  5]   3.00-4.00   sec   111 MBytes   935 Mbits/sec                  
[  5]   4.00-5.00   sec   111 MBytes   932 Mbits/sec                  
[  5]   5.00-6.00   sec   111 MBytes   933 Mbits/sec                  
[  5]   6.00-7.00   sec   111 MBytes   934 Mbits/sec                  
[  5]   7.00-8.00   sec   111 MBytes   935 Mbits/sec                  
[  5]   8.00-9.00   sec   111 MBytes   935 Mbits/sec                  
[  5]   9.00-10.00  sec   111 MBytes   935 Mbits/sec                  
[  5]  10.00-10.04  sec  4.21 MBytes   937 Mbits/sec                  
- - - - - - - - - - - - - - - - - - - - - - - - -
[ ID] Interval           Transfer     Bandwidth       Retr
[  5]   0.00-10.04  sec  1.09 GBytes   933 Mbits/sec  245             sender
[  5]   0.00-10.04  sec  1.09 GBytes   931 Mbits/sec                  receiver
-----------------------------------------------------------
Server listening on 5201
-----------------------------------------------------------
Accepted connection from 172.29.244.63, port 38788
[  5] local 172.29.244.62 port 5201 connected to 172.29.244.63 port 38790
[ ID] Interval           Transfer     Bandwidth
[  5]   0.00-1.00   sec   108 MBytes   902 Mbits/sec                  
[  5]   1.00-2.00   sec   111 MBytes   934 Mbits/sec                  
[  5]   2.00-3.00   sec   111 MBytes   935 Mbits/sec                  
[  5]   3.00-4.00   sec   111 MBytes   933 Mbits/sec                  
[  5]   4.00-5.00   sec   112 MBytes   935 Mbits/sec                  
[  5]   5.00-6.00   sec   111 MBytes   933 Mbits/sec                  
[  5]   6.00-7.00   sec   112 MBytes   936 Mbits/sec                  
[  5]   7.00-8.00   sec   111 MBytes   935 Mbits/sec                  
[  5]   8.00-9.00   sec   111 MBytes   935 Mbits/sec                  
[  5]   9.00-10.00  sec   111 MBytes   935 Mbits/sec                  
[  5]  10.00-10.04  sec  4.37 MBytes   934 Mbits/sec                  
- - - - - - - - - - - - - - - - - - - - - - - - -
[ ID] Interval           Transfer     Bandwidth       Retr
[  5]   0.00-10.04  sec  1.09 GBytes   933 Mbits/sec  181             sender
[  5]   0.00-10.04  sec  1.09 GBytes   931 Mbits/sec                  receiver
-----------------------------------------------------------
Server listening on 5201
-----------------------------------------------------------
Accepted connection from 172.29.244.64, port 35452
[  5] local 172.29.244.62 port 5201 connected to 172.29.244.64 port 35454
[ ID] Interval           Transfer     Bandwidth
[  5]   0.00-1.00   sec   108 MBytes   902 Mbits/sec                  
[  5]   1.00-2.00   sec   112 MBytes   937 Mbits/sec                  
[  5]   2.00-3.00   sec   111 MBytes   934 Mbits/sec                  
[  5]   3.00-4.00   sec   111 MBytes   934 Mbits/sec                  
[  5]   4.00-5.00   sec   112 MBytes   936 Mbits/sec                  
[  5]   5.00-6.00   sec   111 MBytes   934 Mbits/sec                  
[  5]   6.00-7.00   sec   111 MBytes   935 Mbits/sec                  
[  5]   7.00-8.00   sec   111 MBytes   935 Mbits/sec                  
[  5]   8.00-9.00   sec   111 MBytes   933 Mbits/sec                  
[  5]   9.00-10.00  sec   112 MBytes   937 Mbits/sec                  
[  5]  10.00-10.03  sec  3.87 MBytes   935 Mbits/sec                  
- - - - - - - - - - - - - - - - - - - - - - - - -
[ ID] Interval           Transfer     Bandwidth       Retr
[  5]   0.00-10.03  sec  1.09 GBytes   933 Mbits/sec  250             sender
[  5]   0.00-10.03  sec  1.09 GBytes   932 Mbits/sec                  receiver
-----------------------------------------------------------
Server listening on 5201
-----------------------------------------------------------
Accepted connection from 172.29.244.65, port 53796
[  5] local 172.29.244.62 port 5201 connected to 172.29.244.65 port 53798
[ ID] Interval           Transfer     Bandwidth
[  5]   0.00-1.00   sec   107 MBytes   900 Mbits/sec                  
[  5]   1.00-2.00   sec   111 MBytes   934 Mbits/sec                  
[  5]   2.00-3.00   sec   111 MBytes   933 Mbits/sec                  
[  5]   3.00-4.00   sec   112 MBytes   937 Mbits/sec                  
[  5]   4.00-5.00   sec   111 MBytes   933 Mbits/sec                  
[  5]   5.00-6.00   sec   112 MBytes   937 Mbits/sec                  
[  5]   6.00-7.00   sec   112 MBytes   936 Mbits/sec                  
[  5]   7.00-8.00   sec   111 MBytes   934 Mbits/sec                  
[  5]   8.00-9.00   sec   111 MBytes   935 Mbits/sec                  
[  5]   9.00-10.00  sec   112 MBytes   938 Mbits/sec                  
[  5]  10.00-10.03  sec  3.89 MBytes   937 Mbits/sec                  
- - - - - - - - - - - - - - - - - - - - - - - - -
[ ID] Interval           Transfer     Bandwidth       Retr
[  5]   0.00-10.03  sec  1.09 GBytes   934 Mbits/sec  207             sender
[  5]   0.00-10.03  sec  1.09 GBytes   932 Mbits/sec                  receiver
```

Ensure that you record the results for each test and put it into the runbook. 
This data will serve as the expected values for the environment and will be 
used for troubleshooting.

### Ensure you run this test using a node in each cab as the iperf3 server.

Example

If I have three cabs, I will run three tests. 

* Test 1 will have the iperf3 server in Cab A 
* Test 2 will have the iperf3 server in Cab B
* Test 3 will have the iperf3 server in Cab C


## Part 2: Drive Partitioning Validation

The goal here is to confirm that ceph-ansible has set itself up correctly. You 
should confirm that the drives that are expected to be the journal drives
_are in fact the journal drives_. You should have also set up the drives 
each in their own RAID 0. Below is what I use to confirm in my lab

```
source /opt/ceph-toolkit/venv/bin/activate
cd /opt/ceph-ansible
ansible -i ceph_inventory all -m shell -a 'lsblk'
```

The deployments team should add examples of what is correct to this section.


You should also confirm that the correct backend store was used for instalation.

```
cat /var/lib/ceph/osd/ceph-${osdID}/type
```

This will either show 'bluestore' or 'filestore'. Confirm that this matches with 
what the customer is expecting.

It should be 'bluestore' if there are only SSDs in the cluster. 


## Part 3: RBD Functionality


The goal here is for us to confirm that rbd is functioning, as well as provide 
benchmarks of the known working environment for us to use when troubleshooting 
in the future.

Create the volume that will be used for benchmarking

```
rbd -p volumes create --size=10G bench_volume
```

### Run Benchmarks


#### For Seq Write

```
rbd -p volumes bench bench_volume --io-type write --io-size 8192 --io-threads 256 --io-total 10G --io-pattern seq
```
Example output
```
elapsed:    96  ops:  1310720  ops/sec: 13623.58  bytes/sec: 111604374.84
```


#### For Seq Read 

```
rbd -p volumes bench bench_volume --io-type read --io-size 8192 --io-threads 256 --io-total 10G --io-pattern seq 
```
Example output
```
elapsed:   118  ops:  1310720  ops/sec: 11097.68  bytes/sec: 90912181.85
```

#### Clean up bench_volume

```
rbd -p volumes remove bench_volume
```

We need to now recreate the bench volume so we can do random read/write testing

```
rbd -p volumes create --size=10G bench_volume
```

#### For Rand Write

```
rbd -p volumes bench bench_volume --io-type write --io-size 8192 --io-threads 256 --io-total 10G --io-pattern rand
```
Example output

```
elapsed:   442  ops:  1310720  ops/sec:  2962.61  bytes/sec: 24269684.10
```

#### For Rand Read

```
rbd -p volumes bench bench_volume --io-type read --io-size 8192 --io-threads 256 --io-total 10G --io-pattern rand
```

Example output

```
elapsed:   364  ops:  1310720  ops/sec:  3591.67  bytes/sec: 29422938.70
```

Clean up the volume 

```
rbd -p volumes remove bench_volume
```

## Part 4: Rados GW benchmarking

#### If a customer doesn't have Rados GW, this can be skipped.

The goal here is to make sure that Rados GW is functional, and generate benchmark
data that can be used for troubleshooting in the future.


### Add data to the cluster

```
rados bench -p .rgw.root 100 write --no-cleanup
```
Example Output

```
sec Cur ops   started  finished  avg MB/s  cur MB/s last lat(s)  avg lat(s)
100      16      3346      3330   133.183       136    0.420334    0.478569

Total time run:         100.513295
Total writes made:      3347
Write size:             4194304
Object size:            4194304
Bandwidth (MB/sec):     133.196
Stddev Bandwidth:       14.0475
Max bandwidth (MB/sec): 168
Min bandwidth (MB/sec): 104
Average IOPS:           33
Stddev IOPS:            3
Max IOPS:               42
Min IOPS:               26
Average Latency(s):     0.48037
Stddev Latency(s):      0.32016
Max latency(s):         2.02365
Min latency(s):         0.079103

```

#### Seq Read Test

```
rados bench -p .rgw.root 100 seq
```

Example output

```
  sec Cur ops   started  finished  avg MB/s  cur MB/s last lat(s)  avg lat(s)
  100      16      3347      3331   133.226       140    0.893807    0.477932

Total time run:       100.437275
Total reads made:     3347
Read size:            4194304
Object size:          4194304
Bandwidth (MB/sec):   133.297
Average IOPS:         33
Stddev IOPS:          2
Max IOPS:             43
Min IOPS:             28
Average Latency(s):   0.479328
Max latency(s):       2.31153
Min latency(s):       0.00562555

```

#### Random Read Test

```
rados bench -p .rgw.root 100 rand
```

Example output 

```
  sec Cur ops   started  finished  avg MB/s  cur MB/s last lat(s)  avg lat(s)
  100      16      3364      3348   133.906       140    0.739422    0.475306

Total time run:       100.686650
Total reads made:     3365
Read size:            4194304
Object size:          4194304
Bandwidth (MB/sec):   133.682
Average IOPS:         33
Stddev IOPS:          2
Max IOPS:             41
Min IOPS:             27
Average Latency(s):   0.477045
Max latency(s):       2.47053
Min latency(s):       0.00180482

```

Clean up the benchmark data

```
rados -p .rgw.root cleanup
```


### Again, make sure all these values make it into the runbook and paste output in the install ticket as a private comment

