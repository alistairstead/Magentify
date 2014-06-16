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
_cset :interactive_mode, true

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
      local_files_dir = app_relative_media_dir
      first_server = find_servers_for_task(current_task).first

      run_locally("rsync --recursive --times --rsh=ssh --compress --human-readable --progress #{user}@#{first_server.host}:#{remote_files_dir} #{local_files_dir}")
    end

    desc <<-DESC
      Push magento media catalog files (from local to remote)
    DESC
    task :push, :roles => :app, :except => { :no_release => true } do
      remote_files_dir = "#{current_path}#{app_webroot}/#{app_relative_media_dir}"
      local_files_dir = app_relative_media_dir
      first_server = find_servers_for_task(current_task).first

      if !interactive_mode || Capistrano::CLI.ui.agree("Do you really want to replace remote files by local files? (y/N)")
        run_locally("rsync --recursive --times --rsh=ssh --compress --human-readable --progress --delete #{local_files_dir} #{user}@#{first_server.host}:#{remote_files_dir}")
      end
    end
  end
end

after   'deploy:setup', 'mage:setup'
after   'deploy:finalize_update', 'mage:finalize_update'
after   'deploy:create_symlink', 'mage:compiler'
