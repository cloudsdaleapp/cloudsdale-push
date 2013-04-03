# config/deploy.rb
require "bundler/capistrano"
require 'capistrano_colors'

# This program is free software. It comes without any warranty, to
# the extent permitted by applicable law. You can redistribute it
# and/or modify it under the terms of the Do What The Fuck You Want
# To Public License, Version 2, as published by Sam Hocevar. See
# http://sam.zoy.org/wtfpl/COPYING for more details.

set :application, "cloudsdale-push"
set :ruby_version,  "ruby-1.9.3-p194"

set :scm,         :git
set :repository,  "git@github.com:IOMUSE/Cloudsdale-Faye.git"
set :branch,      "master"

set :migrate_target,  :current
set :ssh_options,     { :forward_agent => true }

set :deploy_via,  :remote_cache
set :deploy_to,   "/opt/app/#{application}"
set :node_path,   "/opt/node/bin"
set :node_script, "server.js"
set :node_env,    "production"

set :rvm,         "/usr/local/rvm/bin/rvm"

set :user,  "deploy"
set :group, "deploy"
set :use_sudo, false

role :app,  "www.cloudsdale.org", :primary => true

set :shared_children, %w(log node_modules)

default_environment["NODE_ENV"]     = node_env
default_environment["PATH"]         = "/usr/local/rvm/gems/#{ruby_version}/bin:/usr/local/rvm/gems/#{ruby_version}@global/bin:/usr/local/rvm/rubies/#{ruby_version}/bin:/usr/local/rvm/gems/#{ruby_version}@#{application}/bin:/usr/local/rvm/gems/#{ruby_version}@global/bin:/usr/local/rvm/rubies/#{ruby_version}/bin:/usr/local/rvm/bin:/usr/local/bin:/usr/bin:/bin:/usr/local/games:/usr/games:#{node_path}"
default_environment["GEM_HOME"]     = "/usr/local/rvm/gems/#{ruby_version}"
default_environment["GEM_PATH"]     = "/usr/local/rvm/gems/#{ruby_version}@#{application}:/usr/local/rvm/gems/#{ruby_version}@global"
default_environment["RUBY_VERSION"] = "#{ruby_version}"

default_run_options[:shell] = 'bash'
default_run_options[:pty] = true

namespace :deploy do
  task :default do
    update
    stop
  end

  task :cold do
    update
    stop
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
      rm -Rf #{latest_release}/log #{latest_release}/node_modules &&
      ln -s #{shared_path}/log #{latest_release}/log &&
      ln -s #{shared_path}/node_modules #{latest_release}/node_modules
    CMD
  end

  task :start, :roles => :app do
    run "#{sudo} /etc/init.d/faye start"
  end

  task :stop, :roles => :app do
    run "#{sudo} /etc/init.d/faye stop"
  end

  task :restart, :roles => :app do
    stop
  end

  task :npm, :roles => :app do
    run <<-CMD
      echo $USER
    CMD

    run <<-CMD
      cd #{latest_release} &&
      rm #{latest_release}/node_modules &&
      npm install &&
      cd #{latest_release}/node_modules/faye &&
      #{bundle} install &&
      #{bundle} exec jake &&
      cd #{latest_release}
    CMD
  end

end

after 'deploy:finalize_update', 'deploy:npm'

def sudo
  "sudo env PATH=$PATH"
end

def bundle
  "/usr/local/rvm/gems/#{ruby_version}@#{application}/bin/bundle"
end
