###      ###
# pgbackup #
###      ###

A collection of scripts for making postgresl database backups.  pgbackup scripts include many configurable features including:
*  Vaccum a database prior to backup.
*  Backup schema and data to seperate files.
*  Backup individual tables seperately.
*  Compress backups for faster transfer over the network.
*  Rotate backups automatically.
*  Keep daily, weekly and monthly backups automatically.
*  Keep frequent backups of specific tables at intervals of minutes.

For the most convinience, pgbackup should be set up as a cronjob as follows:
`0 5 * * * cd /var/lib/pgsql/9.0/pgbackup/script; /usr/bin/perl daily.pl >>daily_backup_log`

Inspect thoroughly the file /script/config.pl to see all configuration options!  Custom configurations should be saved seperately in the file /script/_config.pl.
If /script/_config.pl exists, it is run after /script/config.pl and overwrites any values set there.

For high fidelity backups, be sure to run the scripts at times of low database load.

###          ###
# Installation #
###          ###

To install pgbackup, clone the git codebase wherever is convinient -- usually in the postgres home directory -- and then set up your configurations in /script/_config.pl.

You will need to provide a $db_name.  If you are backing up a remote database, you will need to provide a $db_host.  Verify that the $backup_path is appropriate and set a value if it is not.  

If the script is to be executed on a slave node, $skip_vaccum should be set (you can not vaccum slave nodes, only masters).  Inspect /script/config.pl for any less important configurations you would like to override for your particular backup needs.

Set the daily backup script to run in your crontab:
`0 5 * * * cd /var/lib/pgsql/9.0/pgbackup/script; /usr/bin/perl daily.pl >>daily_backup_log` 

You will need to adjust the paths in the above command if any of them do not match your postgresql and perl installations

If frequent backups are required, set the frequent backup script to run in your crontab:
`*/15 * * * * cd /var/lib/pgsql/9.0/pgbackup/script; /usr/bin/perl frequent.pl >>frequent_backup_log` 

Adjust any paths if necesary.

It is generally a good idea to run the scripts from the command line at least once to verify that your configuration works as expected before allowing the cron jobs to steal the show.  Silly mistakes can easily be avoided this way.

It is usually a good idea to set up the daily cron to run at the time of least database load.
