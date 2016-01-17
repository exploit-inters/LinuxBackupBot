#!/bin/bash

### CONFIGURATION ###
backupSource=/media/storage
backupTarget=/media/storage-backup
### END OF CONFIG ###

currentDTime=`date +%F-%T`
startTs=$(date +"%s");
logDirectory=/var/log/backup
logFile=$logDirectory/storage-$currentDTime

mountpoint -q $backupSource
if [ $? -ne 0 ]
then
 echo $backupSource is not an valid mountpoint >> $logFile
 exit 1
fi

mountpoint -q $backupTarget
if [ $? -ne 0 ]
then
 echo $backupTarget is not an valid mountpoint >> $logFile
 exit 1
fi

echo Backup of $backupSource to $backupTarget started at $currentDTime >> $logFile
echo "--- Locations statistics ---" >> $logFile
 df -h $backupSource >> $logFile
 df -h $backupTarget | sed -n 2p >> $logFile
 echo >> $logFile
 df -h -i $backupSource >> $logFile
 df -h -i $backupTarget | sed -n 2p >> $logFile
 echo >> $logFile

targetSpaceUsed=$(df $backupTarget | awk 'NR==2{print $3}');
targetInodesUsed=$(df -i $backupTarget | awk 'NR==2{print $3}');
rsync \
 --verbose \
 --archive --hard-links --executability --acls --xattrs \
 --specials --sparse --one-file-system --numeric-ids \
 --delete --fuzzy \
 --log-file=$logFile \
 $backupSource $backupTarget > /dev/null 2>&1
if [ $? != 0 ]; then
 echo Backup failed at `date +%H:%M:%S` >> $logFile
 exit 1;
fi

echo >> $logFile
echo "--- Statistics after backup ---" >> $logFile
 df -h $backupSource >> $logFile
 df -h $backupTarget | sed -n 2p >> $logFile
 echo >> $logFile
 df -h -i $backupSource >> $logFile
 df -h -i $backupTarget | sed -n 2p >> $logFile
 echo >> $logFile
echo "Backup weight:"  $((($(df $backupTarget | awk 'NR==2{print $3}') - $targetSpaceUsed)/1024))"MB" >> $logFile
echo "INodes used:" $(($(df -i $backupTarget | awk 'NR==2{print $3}') - $targetInodesUsed)) >> $logFile

echo >> $logFile
diff=$(($(date +"%s")-$startTs))
echo Backup of completed at `date +%H:%M:%S` "(took $(($diff / 60))m $(($diff % 60))s)" >> $logFile

# Purge old log files
find $logDirectory/* -type f -mtime +7
