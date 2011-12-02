# !!!!!!!!!!!!!!!!!!!!!!
# THESE ARE BASE CONFIGS
#
# IT IS RECOMENDED YOU PUT CUSTOM CONFIGS IN THE FILE ./_config.pl
# THIS WILL MAKE IT EASIER TO UPDATE THIS CODE USING GIT
# !!!!!!!!!!!!!!!!!!!!!!

##################
##COMMON CONFIGS##

$db_name = "postgres";
$db_host = "localhost";
$db_user = "postgres";
#$db_port; #if needed
#$db_pass = '***'; #use of this variable is discouraged, .pgpass files are preferred

$delete_backups_older_than = 10; #days, will not delete anything if there is not more than this number of backups
$max_purge = 3;  #maximum number of deletes before purging is stopped

$suppress_output = 0; #output will not be printed

$skip_data = 0;
$skip_schema = 0;
$skip_purge = 0;
$skip_compress = 0;

$table_data_file_name_suffix = '-data.sql'; #individual table backup data file name
$table_schema_file_name_suffix = '-schema.sql';  #individual table backup schema file name

$compress_cmd = "tar czvf "; #compress command to be executed with working directory $backup_path in the fashon `$compress_$cmd $compress_destination $compress_target` (tar syntax)
$compressed_file_extension = '.tar.gz';

$time_format = '%Y-%m-%d_%H%M';  #strftime
$output_time_format = '%Y-%m-%d %H:%M:%S : '; #calls to echo prepended with this time formatted string

$time_start = time();

$backup_path = '/var/lib/pgsql/9.0/backups';
$compress_path = "$backup_path/compressed";

#################
##DAILY CONFIGS##

$skip_vacuum = 0;  #slaves can not be vacuumed
$skip_table_backup = 0;

@exclude_databases = (
   'template1',
   'template0',
   'postgres',
);

@table_backup_exclude_schemas = (
   'information_schema',
   'pg_catalog'
);

$daily_backup_subdir = 'daily'; #directory of backups

$data_file_name = "data.sql";  #name of data backup file
$schema_file_name = "schema.sql";  #name of schema backup file

$daily_file_name_time_format = '%Y-%m-%d';  #strftime
$daily_file_name_regexp = /^\d\d\d\d\-\d\d\-\d\d/;
####################
##FREQUENT CONFIGS##

#NOTE: $db_pass does not apply to frequent.pl, .pgpass is required

$default_schema_name = 'public';

$frequent_backup_subdir = 'frequent'; #directory of backups

$frequency = '30'; #number of minutes between consecutive backups
$frequency_error = '5'; #backup will occur if ($current_time - $last_backup_time) >= ($frequency - $frequency_error)
#if $frequency error is greater than $frequency, backups will always occur

$frequent_file_name_time_format = '%Y-%m-%d_%H%M';  #strftime
$frequent_file_name_regexp = /^\d\d\d\d\-\d\d\-\d\d_\d\d\d\d/;

$tables = [
#   {  #mimimum config
#      'name' => 'table_name'
#   },
#   {  #more customized, global variables overridden
#      'name' => 'table_name',
#      'schema' => 'schema_name', #optional, default is 'public'
#      'db_name' => 'db_name', #to allow overriding global variables for this table
#      'db_host' => 'db_host',
#      'db_user' => 'db_user',
#      'db_port' => '5432',
#      'frequency' => '60' 
#   }
];

require "_config.pl" if -e "_config.pl";

1;
