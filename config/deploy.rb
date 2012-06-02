# config/deploy.rb
require "bundler/capistrano"
require 'capistrano_colors'

# This program is free software. It comes without any warranty, to
# the extent permitted by applicable law. You can redistribute it
# and/or modify it under the terms of the Do What The Fuck You Want
# To Public License, Version 2, as published by Sam Hocevar. See
# http://sam.zoy.org/wtfpl/COPYING for more details.

set :application, "cloudsdale"
set :scm,         :git
set :repository,  "git@github.com:IOMUSE/Cloudsdale-Faye.git"
set :branch,      "master"

set :ssh_options,     { :forward_agent => true }

set :deploy_via,  :remote_cache
set :deploy_to,   "/opt/app/#{application}"
set :node_path,   "/usr/bin/node"
set :node_script, "server.js"

set :user,  "deploy"
set :group, "deploy"
set :use_sudo, true
set :default_run_options, :pty => true

role :app,  "push01.cloudsdale.org", :primary => true

set :shared_children, %w(log node_modules)

set(:latest_release)  { fetch(:current_path) }
set(:release_path)    { fetch(:current_path) }
set(:current_release) { fetch(:current_path) }

set(:current_revision)  { capture("cd #{current_path}; git rev-parse --short HEAD").strip }
set(:latest_revision)   { capture("cd #{current_path}; git rev-parse --short HEAD").strip }
set(:previous_revision) { capture("cd #{current_path}; git rev-parse --short HEAD@{1}").strip }

default_environment["NODE_ENV"]     = "production"
default_environment["PATH"]         = "/usr/local/rvm/gems/ruby-1.9.3-p194/bin:/usr/local/rvm/gems/ruby-1.9.3-p194@global/bin:/usr/local/rvm/rubies/ruby-1.9.3-p194/bin:/usr/local/rvm/bin:/usr/local/bin:/usr/bin:/bin:/usr/local/games:/usr/games"
default_environment["GEM_HOME"]     = "/usr/local/rvm/gems/ruby-1.9.3-p194"
default_environment["GEM_PATH"]     = "/usr/local/rvm/gems/ruby-1.9.3-p194:/usr/local/rvm/gems/ruby-1.9.3-p194@global"
default_environment["RUBY_VERSION"] = "ruby-1.9.3-p194"

default_run_options[:shell] = 'bash'

namespace :deploy do
  task :default do
    update
    start
  end

  task :cold do
    update
    start
  end
  
  task :setup, :expect => { :no_release => true } do
    dirs  = [deploy_to, releases_path, shared_path]
    dirs += shared_children.map { |d| File.join(shared_path, d) }
    run "mkdir -p #{dirs.join(' ')}"
    run "chmod g+w #{dirs.join(' ')}" if fetch(:group_writable, true)
  end
  
  task :finalize_update, :except => { :no_release => true } do
    run "chmod -R g+w #{latest_release}" if fetch(:group_writable, true)
    run <<-CMD
      rm -rf #{latest_release}/log #{latest_release}/node_modules &&
      ln -s #{shared_path}/log #{latest_release}/log &&
      ln -s #{shared_path}/node_modules #{latest_release}/node_modules
    CMD
  end
  
  task :start, :roles => :app do
    run "#{sudo} restart #{application} || #{sudo} start #{application}"
  end

  task :stop, :roles => :app do
    run "#{sudo} stop #{application}"
  end

  task :restart, :roles => :app do
    start
  end
  
  task :npm, :roles => :app do
    run <<-CMD
      export PATH=#{node_path}:$PATH &&
      cd #{latest_release} &&
      npm install 
    CMD
  end
  
  task :write_upstart_script, :roles => :app do
    upstart_script = <<-UPSTART_SCRIPT
    
      description "#{application} upstart script"
      start on (local-filesystem and net-device-up)
      stop on shutdown
      respawn
      respawn limit 5 60
      script
        chdir #{current_path}
        exec sudo -u #{user} NODE_ENV="production" #{node_path}/node #{node_script} >> log/production.log 2>&1
      end script

    UPSTART_SCRIPT
    
    put upstart_script "/tmp/#{application}.conf"
    run "#{sudo} mv /tmp/#{application}.conf /etc/init"
  end
end

after 'deploy:setup', 'deploy:write_upstart_script'
after 'deploy:finalize_update', 'deploy:npm'