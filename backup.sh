#!/bin/bash
unset base

if [ "$#" == "0" ]; then
	echo "$0: missing config file"
	echo
	echo "Usage: $0 CONFIG_FILE"
	exit 1;
fi

if [ ! -f $1 ] || [ ! -r $1 ]; then
	echo "Config file" $1 "is not readable";
	exit 1
fi

source $1

if [ -z "$base" ] || [ ! -d "$base" ] || [ ! -w "$base" ]; then
	echo "Invalid or not writable base dir"
	exit 1
fi

log=$base/_meta/last.log
# END OF CONFIG
folder=`date +%Y-%m-%d`

mv $log $base/_meta/prev.log
start_ts=$(date +"%s");
echo "Backup for" $host "started at" $folder `date +%H:%M:%S` > $log
echo "Base folder:" $base >> $log
echo "Disk space before:" >> $log
 df -h $base >> $log
 df -h -i $base | sed -n 2p >> $log
space_used=$(df $base | awk 'NR==2{print $3}');
inodes_used=$(df -i $base | awk 'NR==2{print $3}');

echo >> $log

rsync rsync://$login"@"$host/backup -rz -a $base/$folder --link-dest=$base/last --devices --password-file=$base/_meta/passwd --exclude-from=$base/_meta/excludes --log-file=$log
if [ $? != 0 ]; then
        echo "Backup of" $host "failed at" `date +%H:%M:%S` >> $log
	exit 1;
fi

echo "Backup weight:"  $((($(df $base | awk 'NR==2{print $3}') - $space_used)/1024))"MB" >> $log
echo "INodes used:" $(($(df -i $base | awk 'NR==2{print $3}') - $inodes_used)) >> $log
echo "Disk space after:" >> $log
 df -h $base >> $log
 df -h -i $base | sed -n 2p >> $log
echo >> $log

rm $base/last
ln -s $base/$folder $base/last

diff=$(($(date +"%s")-$start_ts))
echo "Backup of" $host "completed at" `date +%H:%M:%S` "(took $(($diff / 60))m $(($diff % 60))s)" >> $log

exit 0;
