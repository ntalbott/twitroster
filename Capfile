load 'deploy'
require "spacesuit/recipes/common"
require 'spacesuit/recipes/terralien'

set :client, "terralien"
set :application, "twitroster"

default_run_options[:pty] = true
set :scm, "git"
set :repository,  "git@github.com:terralien/twitroster.git"
set :deploy_via, :remote_cache
set :keep_releases, 10
set :git_enable_submodules, 1
set :ssh_options, {:forward_agent => true}

set :user, client

set :deploy_to, "/var/www/#{client}/#{application}"
set :domain, "#{application}.com"

role :web, domain
role :app, domain
role :db,  domain, :primary => true

namespace :deploy do
  desc "No migrations to run."
  task :default do
    transaction do
      update_code
      web.disable
      symlink
    end
    restart
    web.enable
    cleanup
  end
end

namespace :terralien do
  task :post_deploy do
  end
end

after 'deploy:symlink' do
  run "mkdir -p #{shared_path}/cache"
  run "ln -nfs #{shared_path}/cache #{release_path}/cache"
end