#!/usr/bin/perl -l

###############
# Frequent Database Schema and Data Backup Script
# frequent.pl
#
# Script for makring frequent backups for specific tables.
#
# For cron:
# cd /path/to/script/directory ; /usr/bin/perl frequent.pl >>db_backup_log
#
# cd is not necesarily required, but it is harmless and convinient in cron
#

use POSIX;
use Time::Local;

require 'config.pl';
require 'funcs.pl';

###############
# SCRIPT
###############

handle_table($_) foreach @$tables;

(delete_old($_, $frequent_file_name_regexp, $frequent_file_name_time_format, $frequent_backup_subdir), compress_backups($_, $frequent_file_name_regexp, $frequent_backup_subdir)) foreach keys %databases;




