include_recipe 'postgresql::pg_user'
include_recipe 'postgresql::pg_database'

# Create gitlab_ci user

user 'gitlab_ci' do
  comment 'GitLab CI user'
  home '/home/gitlab_ci'
  shell '/bin/bash'
  supports manage_home: true
end

# Create databases

pg_user 'gitlab_ci' do
  privileges superuser: false, createdb: false, login: true
  password 'password'
end

pg_database 'gitlab_ci_production' do
  owner 'gitlab_ci'
end

# GitLab CI

git '/home/gitlab_ci/gitlab-ci' do
  repository 'git://github.com/gitlabhq/gitlab-ci.git'
  branch '3-1-stable'
  user 'gitlab_ci'
end

template '/home/gitlab_ci/gitlab-ci/config/puma.rb' do
  source 'gitlab-ci.puma.rb'
  owner 'gitlab_ci'
end

template '/home/gitlab_ci/gitlab-ci/config/application.yml' do
  source 'gitlab-ci.application.yml'
  owner 'gitlab_ci'
end

template '/home/gitlab_ci/gitlab-ci/config/database.yml' do
  source 'gitlab-ci.database.yml'
  owner 'gitlab_ci'
end

%w{ log tmp tmp/pid tmp/sockets }.each do |dir|
  directory "/home/gitlab_ci/gitlab-ci/#{dir}" do
    mode 00755
    recursive true
    action :create
    owner 'gitlab_ci'
  end
end

# Run bundler

execute 'bundle_gitlab_ci' do
  user 'gitlab_ci'
  cwd '/home/gitlab_ci/gitlab-ci'
  command 'bundle install --deployment --without development test mysql unicorn aws'
end

# Setup the database

execute 'create_gitlab_ci_database' do
  user 'gitlab_ci'
  cwd '/home/gitlab_ci/gitlab-ci'
  command 'bundle exec rake db:setup RAILS_ENV=production'
end

# init.d

file '/home/gitlab_ci/gitlab-ci/lib/support/init.d/gitlab_ci' do
  mode 00755
end

link '/etc/init.d/gitlab_ci' do
  to '/home/gitlab_ci/gitlab-ci/lib/support/init.d/gitlab_ci'
end

service 'gitlab_ci' do
  action [:enable, :start]
end
