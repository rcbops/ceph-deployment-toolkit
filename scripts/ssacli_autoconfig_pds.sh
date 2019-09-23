#!/bin/sh

# ssacli_autoconfig_pds:
# Finds unused pds on HPE controllers and configures single-disk raid 0's on them.
# Primarily useful for configurations where data redundancy is handled upstream (ceph, cassandra, etc...)

SSACLI=$(which ssacli)

# this function finds all of the free pds on a given ctrl slot and creates a single disk raid 0 on that pd.
function build_all_free {
        echo "Checking lds on slot $1";
        
        ## TODO - this doesn't seem to find single-disk raid 0's, ironically.
        #used_pds=($($SSACLI ctrl slot=$1 ld all show detail 2>/dev/null | awk '/physicaldrive/ {print $2}'))
        
        ## TODO - new approach to detecting in-use pds.  Needs testing.
        used_pds=($($SSACLI ctrl slot=$1 pd all show detail 2>/dev/null | egrep -A2 "Array [A-Z]*$" | awk '/physicaldrive/ {print $2}'))
        
        for pd in $($SSACLI ctrl slot=$1 pd all show | awk '/physicaldrive/ {print $2}'); do
                
                in_use=0;
                count=0;
                
                # check that the current pd isn't in the "used_pds" array
                while [ "x${used_pds[count]}" != "x" ]
                do
                        if [ $pd == ${used_pds[count]} ]
                        then
                                echo "    Skipping in-use physical disk: $pd";
                                in_use=1;
                        fi;
                        
                        count=$(( $count + 1 ))
                done

                # if this pd is indeed unused, build a raid 0 on it
                if [ $in_use -eq 0 ]
                then
                        echo "    Building raid 0 on unused pd $pd";
                        yes y | $SSACLI ctrl slot=$1 create type=ld drives=$pd raid=0 >/dev/null 2>&1;
                fi;
        done
}

# find slots and pass their numbers to build_all_free above.
for slot in $($SSACLI ctrl all show | awk '/Slot/ {print substr($0,index($0,"Slot")+5,1)}'); do
        build_all_free $slot;
done
