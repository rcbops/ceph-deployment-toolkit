#!/usr/bin/perl

### This script needs to be run somewhere with SSH passwordless auth to the ceph mons, generally mon01 in the cluster
### On a controller for openstack, you can query the DB to match volumes to instances with:
## VOLUMES=$(awk '!/^clients/ {print $3}' ceph_jewel_clients.txt |grep "volume-" |sed -e 's/.*\/volume-//g' |sort -u |awk '{ print "\""$1"\""; }' |paste -sd ",") 
## mysql -e "select cinder.volume_attachment.instance_uuid, cinder.volume_attachment.volume_id, cinder.volumes.project_id from cinder.volumes join (cinder.volume_attachment) on (cinder.volume_attachment.volume_id = cinder.volumes.id) where cinder.volumes.id in (${VOLUMES}) and cinder.volume_attachment.attach_status='attached';" > ceph_volumes_instances
## VMS=$(awk '!/^clients/ {print $3}' ceph_jewel_clients.txt |grep "_disk" |sed -e 's/.*\///g' |sed -e 's/_disk//g' |sort -u |awk '{ print "\""$1"\""; }' |paste -sd ",")
## mysql -e "select nova.instances.uuid, nova.instances.hostname from nova.instances where instances.uuid in (${VMS}) ;" >> ceph_volumes_instances

use Data::Dumper;
use Getopt::Std;

getopts('hc:p:v:');
help() if ($opt_h);

my $ceph_conf = ( defined($opt_c) ? $opt_c : "/etc/ceph/ceph.conf" );

#my $ceph_pool = ( defined($opt_p) ? $opt_p : "volumes" );
my $ceph_version = ( defined($opt_v) ? $opt_v : undef );

open( my $fh_ceph_conf, "<", $ceph_conf )
    or die("Can't open file: $ceph_conf\n");

my @monlist;
while (<$fh_ceph_conf>) {
    next unless (/^\s*mon[ _]host\s+=\s+(\S+)/);
    @monlist = split( /,/, $1 );
}

#map { print "$_\n" } @monlist;

my @sessions;
foreach my $mon (@monlist) {
    push @sessions,
        (
        `ssh $mon "ceph daemon /var/run/ceph/ceph-mon* sessions" |grep MonSession`
        );
}
chomp(@sessions);

map { $_ =~ s/^\s*"MonSession\((.*?)\)"[,]*/$1/ } @sessions;
@sessions = grep {/^client/} @sessions;
if ( defined($ceph_version) ) {
    @sessions = grep {/$ceph_version/} @sessions;
}

#map { print "$_\n" } @sessions;

my %client_sessions;
foreach my $session (@sessions) {
    $session
        =~ /^(\S+)\s+(\S+)\s+(.*?)\s+allow\s+(.*?),\s+features\s+(\S+)\s+\((\S+)\)$/;
    $client_sessions{$2} = {
        'client_id' => $1,
        'state'     => $3,
        'caps'      => $4,
        'features'  => $5,
        'version'   => $6
    };
}

#print Dumper(\%client_sessions);
print "clients found: ", scalar( keys %client_sessions ), "\n";

#print "DEBUG: ssh $monlist[0] \"rbd -p $ceph_pool ls\"\n";
my @rbd_list;
my @pools = (`ssh $monlist[0] "ceph osd pool ls"`);
chomp @pools;

#print "DEBUG: pools:\n";
#map { print "$_\n" } @pools;

foreach my $pool (@pools) {
    my @pool_rbd_list = (`ssh $monlist[0] "rbd -p $pool ls"`);
    die("Command failed: ssh $monlist[0] \"rbd -p $pool ls\": $!\n")
        if ( $? != 0 );
    chomp @pool_rbd_list;
    warn("No RBD images found for pool $pool\n")
        unless ( scalar(@pool_rbd_list) );
    map {s/^(.*?)$/$pool\/$1/} @pool_rbd_list;
    push @rbd_list, @pool_rbd_list;
}

#map { print "$_\n" } @rbd_list;

my %rbd_watchers;
foreach my $rbd (@rbd_list) {

    #print "DEBUG: ssh $monlist[0] \"rbd status $rbd\"\n";
    my $output = `ssh $monlist[0] "rbd status $rbd"`;
    if ( $output =~ /watcher=(\S+)\s+(client\S+)\s+(cookie\S+)/ ) {
        $rbd_watchers{$1} = {
            'rbd'       => $rbd,
            'client_id' => $2,
            'cookie'    => $3
        };
    }
}

#print Dumper(\%rbd_watchers);

foreach my $session ( keys %client_sessions ) {
    if ( $rbd_watchers{$session} ) {
        print $session, ", ", $client_sessions{$session}->{'client_id'}, " ",
            $rbd_watchers{$session}->{'rbd'}, "\n";
    }
    else {
        print $session, " - no matching RBD images found\n";
    }
}

sub help {
    print "ceph_client_sessions.pl [-c <ceph.conf>] [-v <client version>]\n";
    print
        "     -c <ceph.conf>  # path to ceph config, default: /etc/ceph/ceph.conf\n";

    print
        "     -v <client version>  # client version to filter sessions on, default: all client versions\n";
    exit;
}
