#!/usr/bin/perl -l

###############
# Daily Database Schema and Data Backup Script
# daily.pl
#
# Backs up a postgresql database with schema and data sql files seperate, with the option to also seperate sql for each table
#
# For cron:
# cd /path/to/script/directory ; /usr/bin/perl daily.pl >>db_backup_log
#
# cd is not necesarily required, but it is harmless and convinient in cron
#


use DBI;
use POSIX;

use POSIX;
use Time::Local;

require "config.pl";
require "funcs.pl";

$db = DBI->connect("DBI:Pg:dbname=$db_name;host=$db_host" . ($db_port?";port=$db_port":''), $db_user, $db_pass, {'RaiseError' => 1}) || die "Unable to connecto to database";

###############
# SCRIPT
###############

vacuum();

handle_database($_) foreach get_databases();

($sec,$min,$hour,$mday,$mon,$year,$wday,$yday,$isdst) = localtime(time);

if($mday == 1){
   $daily_backup_subdir = 'monthly';

   handle_database($_) foreach get_databases();
}

if($wday == 0){
   $daily_backup_subdir = 'weekly';

   handle_database($_) foreach get_databases();
}

$db->disconnect();
