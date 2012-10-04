####
# COMMON AND UTILITY FUNCTIONS
####

sub generate_cmd_connection_string{
   my $name = shift() || $db_name;
   my $host = shift() || $db_host;
   my $user = shift() || $db_user;
   my $port = shift() || $db_port;

   ($user?"-U $user ":'').($host?"-h $host ":'').($port?"-p $port ":'').$name;
}

sub echo{
   my @return;

   while((unshift(@return, shift())) && $return[0] && push(@return, shift(@return))){
      print get_time(0, $output_time_format) . $return[scalar(@return) - 1] unless $suppress_output;
   }

   shift(@return);

   scalar(@return) == 1?shift(@return):@return;
}

sub trim{
   $1 if shift() =~ /^\s*(.+)\s*$/;
}

sub get_time{
   my $time = shift();
   my $format = shift() || $time_format;

   $time = [$time?localtime($time):localtime];

   POSIX::strftime($format, @$time);
}

sub get_unix_time{
   my $time = shift() || time();

   get_time($time, '%s'); #there might be a better a way to do this
}

sub cmd{
   my $cmd = shift();

   my $output = `$cmd`;
   
   echo("shell command:\n$cmd\noutput:\n$output\n");
   
   $output;
}

sub db_execute{
   my $sql = shift();
   my $_db = shift() || $db;

   echo("database query: `$sql'");

   my $rs = $_db->prepare($sql);
   $rs->execute();

   $rs;
}

sub string_to_time{
   my $str = shift();

   my @time;

   if($str =~ /(...)\-(..)\-(..)_(..)(..)/){
      push(@time, 0, $5, $4, $3, $2 - 1, $1);
   }else{
      return(0);
   }

   timelocal(@time);
}

sub delete_old{
   my $db_name = shift();
   my $file_name_regexp = shift();
   my $file_name_time_format = shift();
   my $backup_subdir = shift();

   my $delete_older_than = get_time(time - ($delete_backups_older_than * 86400), $file_name_time_format); #seconds per day

   echo("Purging files older than $delete_older_than, max purge of $max_purge");

   my $full_backup_path = "$backup_path/$db_name/$backup_subdir";
   my $full_compress_path = "$compress_path/$db_name/$backup_subdir";

   unless($skip_purge){
      foreach(($full_backup_path, $full_compress_path)){	
         my $cur_path = $_;

         echo("Purging old $db_name backups at $cur_path ...");

         my @_ls = <$cur_path/*>;
         my @ls;
 
         echo("Iterating files to delete in $cur_path");
 
         push(@ls, (split('/', $_))[-1]) foreach(@_ls);

         my $count = 0;
         foreach(@ls){
         #   echo("file: $_");

            $count++ if $_ =~ $file_name_regexp; #so we don't accidentally count non-backups
         }

         if($count < $delete_backups_older_than){
            echo("Not enough backups to start purging.");
            next;
         }

         my $delete_count = 0;

         foreach(@ls){
            last if $delete_count >= $max_purge;
            next unless $_;
            (echo("deleting $cur_path/$_"), cmd("rm -rf \"$cur_path/$_\" 2>&1"), $delete_count++, echo("deleted $cur_path/$_")) if $_ lt $delete_older_than && $_ =~ $file_name_regexp; #the regexp so we don't accidentally delete non-backups
         }

         echo("Purge of $delete_count files from $cur_path complete.");
      }
   }else{
      echo("Skipping purge of $db_name...");
   }

   
   1;
}

sub compress_backups{
   my $db_name = shift();
   my $file_name_regexp = shift();
   my $backup_subdir = shift();

   unless($skip_compress){
      echo("Compressing $db_name backups...");  

      cmd("mkdir -p \"$compress_path/$db_name/$backup_subdir\" 2>&1");

      my @_ls = <$backup_path/$db_name/$backup_subdir/*>;
      my @ls;

      echo("Iterating files to compress in $compress_path/$db_name/$backup_subdir");

      push(@ls, (split('/', $_))[-1]) foreach(@_ls);

      foreach(@ls){
         $_ = trim($_);
         if($_ =~ $file_name_regexp){
            my $compress_file_path;
            unless(-e ($compress_file_path = "$compress_path/$db_name/$backup_subdir/$_" . $compressed_file_extension)){
               echo("Compressing $backup_path/$db_name/$backup_subdir/$_ to $compress_file_path ...");
               #commands are executed with $backup_path working directory
               cmd("cd \"$backup_path/$db_name/$backup_subdir\" 2>&1; $compress_cmd \"$compress_file_path\" \"$_\" 2>&1");
               echo("Finished compressing $backup_path/$db_name/$backup_subdir/$_ .");
            }else{
               echo("Already compressed $backup_path/$db_name/$backup_subdir/$_ ...");
            }
         }
      } 
 
      echo("Finished compressing $db_name backups.");  
   }else{
      echo("Skipping compression of $db_name...");
   }
}

####
# DAILY BACKUP FUNCTIONS
###

sub get_databases{
   my $rs = db_execute("select * from pg_database where datname not in ('" . join("', '", @exclude_databases) . "')");

   my @return;

   push(@return, $ref->{'datname'}) while $ref = $rs->fetchrow_hashref();

   @return;
}

sub backup_database{
   my $db_name = shift();

   my $db_cmd_connection_string = generate_cmd_connection_string($db_name);
   my $time = get_time(0, $daily_file_name_time_format);

   cmd("mkdir -p \"$backup_path/$db_name/$daily_backup_subdir/$time\" 2>&1");

   unless($skip_data){
      my $full_backup_path = "$backup_path/$db_name/$daily_backup_subdir/$time/$data_file_name";
      echo("Backing up $db_name data to $full_backup_path ...");
      cmd("pg_dump --data-only --disable-triggers $db_cmd_connection_string 2>&1 >\"$full_backup_path\"");
      echo("Data backup complete.");
   }else{
      echo("Skipping data backup of $db_name...");
   }
   
   unless($skip_schema){
      my $full_backup_path = "$backup_path/$db_name/$daily_backup_subdir/$time/$schema_file_name";
      echo("Backing up $db_name schema to $full_backup_path ...");
      cmd("pg_dump --schema-only --disable-triggers $db_cmd_connection_string 2>&1 >\"$full_backup_path\"");
      echo("Schema backup complete.");
   }else{
      echo("Skipping schema backup of $db_name");
   }
 
   unless($skip_table_backup){
      cmd("mkdir -p \"$backup_path/$db_name/$daily_backup_subdir/$time/tables\" 2>&1");

      echo("Backing up individual tables for $db_name...");

      #using .pgpass is recomended so that complications do not arrise at this point of the script when $db_pass may differ from the password of my $db_name
      my $db = DBI->connect("DBI:Pg:dbname=$db_name;host=$db_host", $db_user, $db_pass, {'RaiseError' => 1}) || die "Unable to connec to to database";

      my $rs = db_execute("select schemaname, tablename from pg_tables where schemaname not in ('" . join("', '", @table_backup_exclude_schemas) . "')", $db);

      my @tables;

      push(@tables, $ref) while $ref = $rs->fetchrow_hashref();

      unless($skip_data){
         echo("Backing up individual tables' data for $db_name");         

         foreach(@tables){
            my $tablename = $_->{'tablename'};
            my $schemaname = $_->{'schemaname'};

            my $full_backup_path = "$backup_path/$db_name/$daily_backup_subdir/$time/tables/$schemaname.$tablename" . $table_data_file_name_suffix;

            echo("backing up data for table $schemaname.$tablename...");
            cmd("pg_dump --data-only --disable-triggers --table=$tablename $db_cmd_connection_string 2>&1 >\"$full_backup_path\"");
            echo("Finished backing up data for table $schemaname.$tablename.");
         }

         echo("Finished backing up individual tables' data for $db_name.");
      }else{
         echo("Skipping individual table data backup for $db_name...");
      }

      unless($skip_schema){
         echo("Backing up individual tables' schema for $db_name...");

         foreach(@tables){
            my $tablename = $_->{'tablename'};
            my $schemaname = $_->{'schemaname'};

            my $full_backup_path = "$backup_path/$db_name/$daily_backup_subdir/$time/tables/$schemaname.$tablename" . $table_schema_file_name_suffix;

            echo("backing up schema for table $schemaname.$tablename...");
            cmd("pg_dump --schema-only --disable-triggers --table=$tablename $db_cmd_connection_string 2>&1 >\"$full_backup_path\"");
            echo("Finished backing up schema for table $schemaname.$tablename.");
         }

         echo("Finished backing up individual tables' schema for $db_name.");
      }else{
         echo("Skipping individual table schema backup for $db_name...");
      }

      $db->disconnect();
      
      echo("Finished backing up individual tables for $db_name.");
   }else{
      echo("Skipping backup of individual tables for $db_name...");
   }

   1;
}

sub vacuum{
   unless($skip_vacuum){
      echo("vacuumdb started...");
      cmd("vacuumdb -a -z -U $db_user -h localhost 2>&1");
      echo("vacuumdb finished.");
   }else{
      echo("Skipping vacuumdb...");
   }

   1;
}

sub handle_database{
   my $db_name = shift();

   echo("Handling $db_name...");

   backup_database($db_name);
   delete_old($db_name, $daily_file_name_regexp, $daily_file_name_time_format, $daily_backup_subdir);
   compress_backups($db_name, $daily_file_name_regexp, $daily_backup_subdir);

   echo("Finished handling $db_name.");

   1;
}

####
# FREQUENT BACKUP FUNCTIONS
####

sub get_minutes_since_last_backup{
   my $table = shift();

   my $table_name = $table->{'name'};
   my $schema_name = $table->{'schema'} || $default_schema_name;

   my $dbname = $table->{'db_name'} || $db_name;
  
   my @backups = <$backup_path/$dbname/$frequent_backup_subdir/*/$schema_name.$table_name$table_data_file_name_suffix>;

   unless(scalar(@backups)){
      echo("There do not appear to be any backups for $schema_name.$table_name yet.");
      return(-1);
   }

   my $last_backup = string_to_time(pop(@backups));

   (get_unix_time() - $last_backup) / 60;   
}

sub generate_cmd_args{
   my $table = shift();
   
   my $table_name = $table->{'name'};
   my $shcema_name = $table->{'schema'} || $default_schema_name;

   "--table=$table_name --schema=$schema_name";   
}

sub backup_table{
   my $table = shift();

   my $freq = $table->{'frequency'} || $frequency;

   my $minutes_since_last_backup = get_minutes_since_last_backup($table);

   my $table_name = $table->{'name'};
   my $schema_name = $table->{'schema'} || $default_schema_name; 

   unless($minutes_since_last_backup > ($freq - $frequency_error) || $minutes_since_last_backup < 0){
      echo("Skipping $schema_name.$table_name, backup time not yet reached...");
      echo('Next backup in approximately ' . ($freq - $minutes_since_last_backup) . ' minutes.');
      return(0);
   }

   my $dbname = $table->{'db_name'} || $db_name;
   my $dbhost = $table->{'db_host'} || $db_host;
   my $dbuser = $table->{'db_user'} || $db_user;
   my $dbport = $table->{'db_port'} || $db_port;

   my $db_cmd_connection_string = generate_cmd_connection_string($dbname, $dbhost, $dbuser, $dbport);
   my $db_cmd_args = generate_cmd_args($table);

   my $time = get_time($time_start, $frequent_file_name_time_format);

   cmd("mkdir -p \"$backup_path/$dbname/$frequent_backup_subdir/$time\" 2>&1");

   unless($skip_data){
      my $full_backup_path = "$backup_path/$dbname/$frequent_backup_subdir/$time/$schema_name.$table_name" . $table_data_file_name_suffix;
      echo("Backing up $dbname $schema_name.$table_name data to $full_backup_path ...");
      cmd("pg_dump --data-only --disable-triggers $db_cmd_args $db_cmd_connection_string 2>&1 >\"$full_backup_path\"");
      echo("Data backup complete.");
   }else{
      echo("Skipping data backup of $db_name $schema_name.$table_name...");
   }
   
   unless($skip_schema){
      my $full_backup_path = "$backup_path/$dbname/$frequent_backup_subdir/$time/$schema_name.$table_name" . $table_schema_file_name_suffix;
      echo("Backing up $db_name $schema_name.$table_name schema to $full_backup_path ...");
      cmd("pg_dump --schema-only --disable-triggers $db_cmd_args $db_cmd_connection_string 2>&1 >\"$full_backup_path\"");
      echo("Schema backup complete.");
   }else{
      echo("Skipping schema backup of $db_name $schema_name.$table_name...");
   }

   1;
}

%databases;
sub handle_table{
   my $table = shift();

   echo('Handling ' . $table->{'name'} . '...');

   backup_table($table);
 
   %databases->{$table->{'db_name'} || $db_name} = 1;

   echo('Finished handling ' . $table->{'name'} . '.');

   1;
}

1;	
