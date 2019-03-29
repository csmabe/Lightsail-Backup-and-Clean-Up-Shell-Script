#!/bin/bash

######################################
##   CREATE A NEW SNAPSHOT BACKUP   ##
######################################
## This script takes in three arguments the name of your instance, the region, and the number of snapshots to keep.

NameOfYourInstance=$1
NameOfYourBackup=$NameOfYourInstance
snapshotsToKeep=$2
Region=$3

# Check arguments
if [ -z "$NameOfYourInstance" ]
then
	echo "usage: lightsail-backup-and-delete-cleanup.sh <name_of_instance> [snapshots_to_keep] [region i.e. us-east-2]"
	exit 1
fi

if [ -z "$snapshotsToKeep" ]
then
	echo "number of snpashots to keep not specified, defaulting to 5"
	snapshotsToKeep=5
fi

if [ -z "$Region" ]
then
	echo "Region not specified, attempting to infer it from instance name"	
	## Region Not provided, get it by looking for the instance name
	Region=$(aws lightsail get-instances | jq -r '.[] | map(select(.name == "'${NameOfYourInstance}'")) | .[].location.regionName')
fi

aws lightsail create-instance-snapshot --instance-snapshot-name ${NameOfYourBackup}-$(date +%Y-%m-%d_%H.%M) --instance-name $NameOfYourInstance --region $Region

## Delay before initiating clean up of old snapshots
sleep 30

###############################################
##   DELETE OLD SNAPSHOTS + RETAIN SNAPSHOTS ##
###############################################
# Set number of snapshots you'd like to keep in your account
echo "Number of Instance Snapshots to keep: ${snapshotsToKeep}"

# get the total number of available Lightsail snapshots
numberOfSnapshots=$(aws lightsail get-instance-snapshots | jq '[.[]  | select(.[].fromInstanceName == "'${NameOfYourInstance}'") ]| length')
echo "Number of instance snapshots: ${numberOfSnapshots}"

# get the names of all snapshots sorted from old to new
SnapshotNames=$(aws lightsail get-instance-snapshots | jq -r '.[] | sort_by(.createdAt) | map(select(.fromInstanceName == "'${NameOfYourInstance}'")) | .[].name')

# loop through all snapshots
while IFS= read -r line 
do 
let "i++"

	# delete old snapshots condition
	if (($i <= $numberOfSnapshots-$snapshotsToKeep))
	then
		# delete snapshot command
		aws lightsail delete-instance-snapshot --instance-snapshot-name $line 
	fi

done <<< "$SnapshotNames"

exit 0
