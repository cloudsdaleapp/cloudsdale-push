require "pry"

lock "3.2.1"

set :application, "cloudsdale-push"

set :keep_releases, 5

set :repo_url, "git@github.com:cloudsdaleapp/cloudsdale-faye.git"
set :deploy_to, "~/apps/#{ fetch(:application) }"
set :pty, true

namespace :deploy do

  desc "Restart application"
  task :restart do
    on roles(:app), in: :sequence, wait: 5 do
    end
  end

  after :publishing, :restart

  after :restart, :clear_cache do
    on roles(:web), in: :groups, wait: 10 do
    end
  end

end

# namespace :deploy do
#   task :default do
#     update
#     stop
#   end

#   task :cold do
#     update
#     stop
#   end

#   task :setup, :expect => { :no_release => true } do
#     dirs  = [deploy_to, releases_path, shared_path]
#     dirs += shared_children.map { |d| File.join(shared_path, d) }
#     run "mkdir -p #{dirs.join(' ')}"
#     run "chmod g+w #{dirs.join(' ')}" if fetch(:group_writable, true)
#   end

#   task :finalize_update, :except => { :no_release => true } do
#     run "chmod -R g+w #{latest_release}" if fetch(:group_writable, true)
#     run <<-CMD
#       rm -Rf #{latest_release}/log #{latest_release}/node_modules &&
#       ln -s #{shared_path}/log #{latest_release}/log &&
#       ln -s #{shared_path}/node_modules #{latest_release}/node_modules
#     CMD
#   end

#   task :start, :roles => :app do
#     run "#{sudo} /etc/init.d/faye start"
#   end

#   task :stop, :roles => :app do
#     run "#{sudo} /etc/init.d/faye stop"
#   end

#   task :restart, :roles => :app do
#     stop
#   end

#   task :npm, :roles => :app do
#     run <<-CMD
#       echo $USER
#     CMD

#     run <<-CMD
#       cd #{latest_release} &&
#       rm #{latest_release}/node_modules &&
#       npm install &&
#       cd #{latest_release}/node_modules/faye &&
#       #{bundle} install &&
#       #{bundle} exec jake &&
#       cd #{latest_release}
#     CMD
#   end

# end

# after 'deploy:finalize_update', 'deploy:npm'

# def sudo
#   "sudo env PATH=$PATH"
# end

# def bundle
#   "/usr/local/rvm/gems/#{ruby_version}@#{application}/bin/bundle"
# end
