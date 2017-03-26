#!/bin/bash
unset base

#***********************************************************************#
#Prints human-readable date for logs (e.g. 1993-03-07 23:30:00)
_get_log_date () { date +%Y-%m-%d\ %T; }

#Prints date in filesystem-safe format (e.g. 1993-03-07#23-30)
_get_fs_date () { date +%Y-%m-%d#%H-%M; }

#Prints UNIX timestamp
_get_ts_date () { date +%s; }

#Prints human-readable time difference between now and UNIX timestamp
# in the past (e.g. 2d 6h 32m 5s)
_get_human_time_diff () {
	if [ -z "$1" ]; then
		printf "??\n"
		return 1
	fi

	current_time=$(_get_ts_date)
	diff=`expr $current_time - $1`
	if [ "$diff" -ge "86400" ]; then
		printf $(expr "$diff" / "86400")"d "
		diff=$(expr "$diff" % "86400")
		[ "$diff" -eq "0" ] && printf "0h 0m 0s" && return 0
	fi

	if [ "$diff" -ge "3600" ]; then
                printf $(expr "$diff" / "3600")"h "
                diff=$(expr "$diff" % "3600")
                [ "$diff" -eq "0" ] && printf "0m 0s" && return 0
        fi

        if [ "$diff" -ge "60" ]; then
                printf $(expr "$diff" / "60")"m "
                diff=$(expr "$diff" % "60")
                [ "$diff" -eq "0" ] && printf "0s" && return 0
        fi

	printf "${diff}s"
	return 0
}

#Exits script removing lock file
#By default exits with code 0, first argument will overwrite that
_rel_lock_exit () {
	[ -z "$1" ] && exit="0" || exit=$1

	if [ ! -z "$lock_path" ] && [ -f "$lock_path" ]; then
		rm "$lock_path"
	fi

	exit $exit
}

_resolve_symlink () {
	[ -z "$1" ] && printf "No symlink given at " && caller && exit 1

	current_wd=`pwd -P`
	cd "$1" >/dev/null 2>&1

	[ "$?" -ne "0" ] && printf "$1" && return 1

	pwd -P
	cd "$current_wd"
	return 0
}
#***********************************************************************#

#Check if configuration file was given as an first argument
if [ "$#" = "0" ]; then
	printf "$0: missing config file\n\nUsage: $0 CONFIG_FILE\n"
	exit 1
fi

#Check whatever configuration file is readable
if [ ! -f "$1" ] || [ ! -r "$1" ]; then
	printf "Config file $1 is not readable\n"
	exit 1
fi

#...and load it
source "$1"

#Verify if it has base path (which is crucial for this script)
if [ -z "$base" ] || [ ! -d "$base" ] || [ ! -w "$base" ]; then
	printf "Invalid or not writable base dir\n"
	exit 1
fi

#***********************************************************************#
#Some runtime variables (maybe sometime I'll add them to config?)

#Path to all logs, configs etc
meta_path="${base}/_meta"

#Log file path used by this job
log_path="${meta_path}/last.log"

#Lock file path
lock_path="${meta_path}/run.lock"

#Directory path where new backup will be stored
new_backup_path="${base}/$(_get_fs_date)"

#Link to
last_backup_link_path="${base}/last"
#***********************************************************************#

#Ensure that never two backups with the same config are run in the same time
if [ -f "$lock_path" ]; then
	#We don't want to mess with currently running backup log neither fail siliently...
	conflicted_log_path="${log_path}-conflicted-$(_get_fs_date)"

	printf "Failed to start backup at $(_get_log_date).\n" >> "$conflicted_log_path"
	printf "Found existing lock file: $lock_path.\n" >> "$conflicted_log_path"
	printf "Lock was created at " >> "$conflicted_log_path"
	cat "$lock_path" >> "$conflicted_log_path"
	printf "\nIt's possible that another instance is running or something crashed,\n" >> "$conflicted_log_path"
	printf "investigate this situation manually and than remove lockfile.\n\n" >> "$conflicted_log_path"

	exit 1
else
	_get_log_date > "$lock_path"
fi

#Move old log if exists
if [ -f "$log_path" ]; then
        mv "$log_path" "$meta_path/prev.log"
fi

if [ ! -f "$meta_path/passwd" ]; then
	printf "No password file found (looked at ${meta_path}/passwd).\n" >> "$log_path"
	printf "Consult documentation.\n" >> "$log_path"
	_rel_lock_exit 1
fi
#TODO: add checking for chmods on that file

if [ ! -f "$meta_path/excludes" ]; then
        printf "No excludes file found (looked at ${meta_path}/excludes).\n" >> "$log_path"
        printf "If you don\'t want to exclude anything just create empty one.\n" >> "$log_path"
        _rel_lock_exit 1
fi

printf "Preparing backup of ${login}@${host}/${login} to ${new_backup_path}...\n" >> "$log_path"

#First check if last backup LINK even exists
if [ -L "$last_backup_link_path" ]; then
	#Check if link really points to valid location
	if [ -d "$last_backup_link_path" ]; then
		incremental_backup="1"
		last_backup_real_path=$(_resolve_symlink "$last_backup_link_path")
		printf "Backup will be incremental (based on $last_backup_real_path)\n" >> "$log_path"

	else
	        printf "\nFailed to start backup at $(_get_log_date).\n" >> "$log_path"
		printf "Found link to previous backup (${last_backup_link_path}) however it points to inaccessible location.\n" >> "$log_path"
		printf "If you deleted last backup fix the link to point to last viable backup, however if you see this\n" >> "$log_path"
		printf " message without any manual interventions check your storage! It may be failing now!!!\n" >> "$log_path"
		_rel_lock_exit 1
	fi
else
	incremental_backup="0"
	printf "Backup will be started from scratch (no previous one found)\n" >> "$log_path"
fi

printf "\nDisk statistics (free space & free INodes) before backup:\n" >> "$log_path"
 df -h "$base" >> "$log_path"
 df -h -i "$base" | sed -n 2p >> "$log_path"
printf "\n" >> "$log_path"

#Set variables for space & inodes raw values to calculate used space later
space_used=$(df "$base" | awk 'NR==2{print $3}');
inodes_used=$(df -i "$base" | awk 'NR==2{print $3}');

#Save timestamp for later calulation of timing
start_ts=$(_get_ts_date)

printf "Starting rsync at $(_get_log_date)...\n" >> "$log_path"
#TODO: add checking for $incremental_backup
rsync \
	"rsync://${login}@${host}/${login}" \
	-rz --devices --partial \
	-a "${new_backup_path}.in-progress" \
	--link-dest="$last_backup_link_path" \
	--password-file="$meta_path/passwd" \
	--exclude-from="$meta_path/excludes" \
	--log-file="$log_path"
ret=$?
	
rsync_human_time=$(_get_human_time_diff "$start_ts")

#TODO: add trap for signals - rsync will return 0 if interrupted by signal ;F
if [ "$ret" -ne "0" ]; then
	printf "Rsync FAILED (#$?) at $(_get_log_date) - it took ${rsync_human_time}\n" >> "$log_path"
	printf "Leaving unfinished backup at ${new_backup_path}.in-progress for investigation\n" >> "$log_path"
	_rel_lock_exit 1
fi

printf "\nRsync SUCEED at $(_get_log_date) - it took ${rsync_human_time}\n" >> "$log_path"

#TODO rebuild these lines to something like _get_human_time_diff ()
printf "Backup weight:  $((($(df $base | awk 'NR==2{print $3}') - $space_used)/1024))MB\n" >> "$log_path"
printf "INodes used: $(($(df -i $base | awk 'NR==2{print $3}') - $inodes_used))\n" >> "$log_path"

printf "\nDisk statistics (free space & free INodes) after backup:\n" >> "$log_path"
 df -h "$base" >> "$log_path"
 df -h -i "$base" | sed -n 2p >> "$log_path"
printf "\n" >> "$log_path"

mv "${new_backup_path}.in-progress" "$new_backup_path"
if [ "$?" -ne "0" ]; then
        printf "Failed to move ${new_backup_path}.in-progress to $new_backup_path (hmm? storage problems?)\n" >> "$log_path"
	_rel_lock_exit 1
fi

if [ "$incremental_backup" -eq "1" ]; then
	rm "$last_backup_link_path"
	if [ "$?" -ne "0" ]; then
		printf "Failed to remove old backup link $last_backup_link_path\n" >> "$log_path"
		_rel_lock_exit 1
	fi
fi

ln -s "$new_backup_path" "$last_backup_link_path"
if [ "$?" -ne "0" ]; then
        printf "Failed to link new backup $new_backup_path to $last_backup_link_path\n" >> "$log_path"
        _rel_lock_exit 1
fi

printf "Everything set, backup completed to $new_backup_path\n" >> "$log_path"

_rel_lock_exit 0
