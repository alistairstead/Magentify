load Gem.find_files('nonrails.rb').last.to_s

# =========================================================================
# These variables MUST be set in the client capfiles. If they are not set,
# the deploy will fail with an error.
# =========================================================================
_cset(:app_symlinks) {
  abort "Please specify an array of symlinks to shared resources, set :app_symlinks, ['/media', ./. '/staging']"
}
_cset(:app_shared_dirs)  {
  abort "Please specify an array of shared directories to be created, set :app_shared_dirs"
}
_cset(:app_shared_files)  {
  abort "Please specify an array of shared files to be symlinked, set :app_shared_files"
}

_cset :compile, false
_cset :app_webroot, ''
_cset :app_relative_media_dir, 'media/'
_cset :local_files_dir, app_relative_media_dir
_cset :interactive_mode, true


_cset :remote_tmp_dir, "/tmp"
_cset :local_tmp_dir, "/tmp"
_cset :remote_dump_filename, "#{remote_tmp_dir}/dump_#{release_name}.sql"
_cset :local_dump_filename, "#{local_tmp_dir}/dump_#{release_name}.sql"
_cset :app_relative_magento_dir, '..'
_cset :remote_mysqldump_command, 'mysqldump'
_cset :local_mysql_command, 'mysql'
_cset :local_anonymize_sql_file, ''
_cset :db_dump_ignore_tables, []
_cset :db_dump_cleanup, true

def init_local_variables

  local_file = "#{local_magento_path}/app/etc/local.xml"

  unless File.exist?(local_file)
    abort "no local.xml file found with path #{local_file}. Please specify variable local_magento_path"
  end

  require "rexml/document"
  file = File.new(local_file)
  doc = REXML::Document.new file
  local_db_host = REXML::XPath.first(doc, "//default_setup/connection/host/text()")
  local_db_username = REXML::XPath.first(doc, "//default_setup/connection/username/text()")
  local_db_pass = REXML::XPath.first(doc, "//default_setup/connection/password/text()")
  local_db_dbname = REXML::XPath.first(doc, "//default_setup/connection/dbname/text()")

  return local_db_dbname, local_db_host, local_db_pass, local_db_username
end

def init_remote_variables
  file = "#{current_path}#{app_webroot}/app/etc/local.xml"

  db_host = capture "xmllint --nocdata --xpath '//default_setup/connection/host/text()' #{file}"
  db_username = capture "xmllint --nocdata --xpath '//default_setup/connection/username/text()' #{file}"
  db_pass = capture "xmllint --nocdata --xpath '//default_setup/connection/password/text()' #{file}"
  db_dbname = capture "xmllint --nocdata --xpath '//default_setup/connection/dbname/text()' #{file}"
  return db_dbname, db_host, db_pass, db_username
end

namespace :mage do
  desc <<-DESC
    Prepares one or more servers for deployment of Magento. Before you can use any \
    of the Capistrano deployment tasks with your project, you will need to \
    make sure all of your servers have been prepared with `cap deploy:setup'. When \
    you add a new server to your cluster, you can easily run the setup task \
    on just that server by specifying the HOSTS environment variable:

      $ cap HOSTS=new.server.com mage:setup

    It is safe to run this task on servers that have already been set up; it \
    will not destroy any deployed revisions or data.
  DESC
  task :setup, :roles => [:web, :app], :except => { :no_release => true } do
    if app_shared_dirs
      app_shared_dirs.each { |link| run "#{try_sudo} mkdir -p #{shared_path}#{link} && #{try_sudo} chmod g+w #{shared_path}#{link}"}
    end
    if app_shared_files
      app_shared_files.each { |link| run "#{try_sudo} touch #{shared_path}#{link} && #{try_sudo} chmod g+w #{shared_path}#{link}" }
    end
  end

  desc <<-DESC
    Touches up the released code. This is called by update_code \
    after the basic deploy finishes.

    Any directories deployed from the SCM are first removed and then replaced with \
    symlinks to the same directories within the shared location.
  DESC
  task :finalize_update, :roles => [:web, :app], :except => { :no_release => true } do
    run "chmod -R g+w #{latest_release}" if fetch(:group_writable, true)

    if app_symlinks
      # Remove the contents of the shared directories if they were deployed from SCM
      app_symlinks.each { |link| run "#{try_sudo} rm -rf #{latest_release}#{link}" }
      # Add symlinks the directoris in the shared location
      app_symlinks.each { |link| run "ln -nfs #{shared_path}#{link} #{latest_release}#{link}" }
    end

    if app_shared_files
      # Remove the contents of the shared directories if they were deployed from SCM
      app_shared_files.each { |link| run "#{try_sudo} rm -rf #{latest_release}/#{link}" }
      # Add symlinks the directoris in the shared location
      app_shared_files.each { |link| run "ln -s #{shared_path}#{link} #{latest_release}#{link}" }
    end
  end

  desc <<-DESC
    Clear the Magento Cache
  DESC
  task :cc, :roles => [:web, :app] do
    run "cd #{current_path}#{app_webroot} && php -r \"require_once('app/Mage.php'); Mage::app()->cleanCache();\""
  end

  desc <<-DESC
    Disable the Magento install by creating the maintenance.flag in the web root.
  DESC
  task :disable, :roles => :web do
    run "cd #{current_path}#{app_webroot} && touch maintenance.flag"
  end

  desc <<-DESC
    Enable the Magento stores by removing the maintenance.flag in the web root.
  DESC
  task :enable, :roles => :web do
    run "cd #{current_path}#{app_webroot} && rm -f maintenance.flag"
  end

  desc <<-DESC
    Run the Magento compiler
  DESC
  task :compiler, :roles => [:web, :app] do
    if fetch(:compile, true)
      run "cd #{current_path}#{app_webroot}/shell && php -f compiler.php -- compile"
    end
  end

  desc <<-DESC
    Enable the Magento compiler
  DESC
  task :enable_compiler, :roles => [:web, :app] do
    run "cd #{current_path}#{app_webroot}/shell && php -f compiler.php -- enable"
  end

  desc <<-DESC
    Disable the Magento compiler
  DESC
  task :disable_compiler, :roles => [:web, :app] do
    run "cd #{current_path}#{app_webroot}/shell && php -f compiler.php -- disable"
  end

  desc <<-DESC
    Run the Magento indexer
  DESC
  task :indexer, :roles => [:web, :app] do
    run "cd #{current_path}#{app_webroot}/shell && php -f indexer.php -- reindexall"
  end

  desc <<-DESC
    Clean the Magento logs
  DESC
  task :clean_log, :roles => [:web, :app] do
    run "cd #{current_path}#{app_webroot}/shell && php -f log.php -- clean"
  end

  namespace :files do
    desc <<-DESC
      Pull magento media catalog files (from remote to local with rsync)
    DESC
    task :pull, :roles => :app, :except => { :no_release => true } do
      remote_files_dir = "#{current_path}#{app_webroot}/#{app_relative_media_dir}"
      first_server = find_servers_for_task(current_task).first

      run_locally("rsync --recursive --times --rsh=ssh --compress --human-readable --progress #{user}@#{first_server.host}:#{remote_files_dir} #{local_files_dir}")
    end

    desc <<-DESC
      Push magento media catalog files (from local to remote)
    DESC
    task :push, :roles => :app, :except => { :no_release => true } do
      remote_files_dir = "#{current_path}#{app_webroot}/#{app_relative_media_dir}"
      first_server = find_servers_for_task(current_task).first

      if !interactive_mode || Capistrano::CLI.ui.agree("Do you really want to replace remote files by local files? (y/N)")
        run_locally("rsync --recursive --times --rsh=ssh --compress --human-readable --progress --delete #{local_files_dir} #{user}@#{first_server.host}:#{remote_files_dir}")
      end
    end
  end
  
    namespace :db do
    desc <<-DESC
    Synchronises remote Magento-Database with local Magento-instance.
    DESC
    task :sync, :roles => [:web, :app] do

      dump

      pull

      cleanup

      import

      anonymize

    end
    desc <<-DESC
    Executes a custom sql-script for anonymization of current local Magento-database.
    DESC
    task :anonymize do

      if  File.exist?(local_anonymize_sql_file)
        local_db_dbname, local_db_host, local_db_pass, local_db_username = init_local_variables()

        `#{local_mysql_command} -u#{local_db_username} -p#{local_db_pass} -h#{local_db_host} #{local_db_dbname} < #{local_anonymize_sql_file}`

      end
    end
    desc <<-DESC
    Downloads remote Magento-database-dump.
    DESC
    task :pull, :roles => [:web, :app] do
      download remote_dump_filename + ".gz", local_dump_filename + ".gz"
    end
    desc <<-DESC
    Imports downloaded database-dump into local database configured by local.xml.
    DESC
    task :import, :roles => [:web, :app] do
      local_db_dbname, local_db_host, local_db_pass, local_db_username = init_local_variables()

      `gunzip < #{local_dump_filename}.gz | #{local_mysql_command} -u#{local_db_username} -p#{local_db_pass} -h#{local_db_host} #{local_db_dbname}`

    end

    desc <<-DESC
    Removes remote database-dump from server.
    DESC
    task :cleanup, :roles => [:web, :app] do
      if db_dump_cleanup
        run "rm #{remote_dump_filename}.gz"
      end
    end

    desc <<-DESC
    Dumps remote database into *.sql.gz-File. Ignores Tables specified in :db_dump_ignore_tables-Variable.
    DESC
    task :dump, :roles => [:web, :app] do

      db_dbname, db_host, db_pass, db_username = init_remote_variables()

      ignore = ''
      db_dump_ignore_tables.each do |table|
        ignore += "--ignore-table=#{db_dbname}.#{table} "
      end

      run "echo \"SET FOREIGN_KEY_CHECKS=0;\" > #{remote_dump_filename}"
      run "#{remote_mysqldump_command} -u#{db_username} -p -h#{db_host} --no-data #{db_dbname} >> #{remote_dump_filename}" do |ch, _, out|
        if out =~ /^Enter password: /
          ch.send_data "#{db_pass}\n"
        else
          puts out
        end
      end
      run "#{remote_mysqldump_command} -u#{db_username} -p -h#{db_host} --no-create-info #{ignore} #{db_dbname} >> #{remote_dump_filename}" do |ch, _, out|
        if out =~ /^Enter password: /
          ch.send_data "#{db_pass}\n"
        else
          puts out
        end
      end
      run "echo \"SET FOREIGN_KEY_CHECKS=1;\" >> #{remote_dump_filename}"
      run "gzip #{remote_dump_filename}"
    end

  end
  
end

after   'deploy:setup', 'mage:setup'
after   'deploy:finalize_update', 'mage:finalize_update'
after   'deploy:create_symlink', 'mage:compiler'
