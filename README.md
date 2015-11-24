# Linux Backup Bot
This tool is rsync-based util to perform incremental backups of your servers. I wrote that tool nearly 10 years ago, and after minor changes it still works like a charm ;)  
Since I'm not BASH programmer it's horribly written, but few people asked me to publish it anyway.

## How it works?
This tool was built with following architecture in mind:  
![architecture](http://i.imgur.com/X5l8nmi.png)  

Server on the left acts as central backup server placed in highly secured environment. It also should be duplicated to external locations, which can be done using the same script (nothing stops you from configuring backup server as node to backup).
Backup server has **read-only** access to data on every server, and in practice backup server decides to backup every node (node has no control on backup process). This small change in conventional backup architecture (where client/node writes data on backup server) adds additional layer of security - if someone get access to one of your servers he can't compromise or delete backups from backup server. Also in reverse situation attacker who compromised backup server will only gain access to all backups but he will have no option to destroy live systems.

## Configuration
  1. Install rsync server on node which you want to backup.
  2. Configure read-only access to your server. Do not forget about secure firewall rules!
  ```
  # Example configuration file
  port = 8730
  uid = root
  gid = root
  use chroot = yes
  read only = true
  list = no
  secrets file = /etc/rsyncd.secrets
  
  [backup]
  path = /
  comment = Example Backup Pull
  auth users = backup-example-server
  ```
  `/etc/rsyncd.secrets` file should have proper chmods! Every user is defined as new line containing user & password separated by colon.
  
  3. Install rsync client on your backup server.
  4. Create configuration for node you wish to backup. Example configuration can be found in `example` directory.
  5. Add rule in backup server crontab. You can use following rule:   
  `0 2 * * * /usr/local/bin/backup.sh /media/backup1/servers/example/_meta/config`  
  to run backup evryday at 2 a.m.
  6. Go grab a :beer:

## How backups are organized?
Incremental backups created by this utility are hardlink-based. So after three days of running you'll get something like this:
```
example
├── 2015-11-24
│   ├── bin
│   │   ├── bash
│   │   ├── bunzip2
......
├── 2015-11-25
│   ├── bin
│   │   ├── bash
│   │   ├── bunzip2
......
├── 2015-11-26
│   ├── bin
│   │   ├── bash
│   │   ├── bunzip2
......
├── last -> /media/backup1/servers/example/2015-11-26
└── _meta
    ├── config
    ├── excludes
    ├── last.log
    ├── passwd
    └── prev.log
```

In fact only one copy of `bash` and `bunzip2` are physicaly stored on disk. Using hardlinks comes with one downside - you can't easy check size of one particular backup.  
Such backup structure is extremely easy to maintain - if you want to e.g. delete all backups from previous month just execute `rm -rf 2015-10-*`. Since backups are hard-linked filesystem cares about all nasty incremental stuff - you can delete as much backups as you want, you can even delete all backups except latest one and everyhing will work as you expect.  
As you probably discovered yourself `last.log` and `prev.log` are created. First one contains last backup log, second one previous one (so if last backup failed you'll not loose last successful log). Of course you should monitor log files with automated tools to ensure everything is going smoothly.


## Issues
  * This method provides **NO ENCRYPTION** out of the box. You should use your own SSH tunnel or VPN.
  * Scrip is **not** prepared to backup in intervals smaller than 24 hours, since folders are named according to schema `YYYY-MM-DD`. That can be easily changed ;)
