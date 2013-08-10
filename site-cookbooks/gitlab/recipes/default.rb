include_recipe 'postgresql::pg_user'
include_recipe 'postgresql::pg_database'

# Install required apt packages

%w{ build-essential zlib1g-dev libyaml-dev libssl-dev libgdbm-dev libreadline-dev 
    libncurses5-dev libffi-dev curl git-core openssh-server redis-server checkinstall 
    libxml2-dev libxslt-dev libcurl4-openssl-dev libicu-dev python postfix }.each do |pkg|
  package pkg
end

# Remove system ruby and install ruby-2.0.0-p247

package 'ruby' do
  action :remove
end

directory '/tmp/ruby' do
  action :create
end

remote_file '/tmp/ruby/ruby-1.9.3-p392.tar.gz' do
  source 'http://ftp.ruby-lang.org/pub/ruby/1.9/ruby-1.9.3-p392.tar.gz'
  action :create_if_missing
end

bash 'compile_ruby_from_source' do
  cwd '/tmp/ruby'
  code <<-RUN
    tar zxf ruby-1.9.3-p392.tar.gz
    cd ruby-1.9.3-p392
    ./configure
    make
    make install
  RUN
  creates '/usr/local/bin/ruby'
end

# Install bundler

gem_package 'bundler' do
  action :install
end

# Create git user

user 'git' do
  comment 'GitLab user'
  home '/home/git'
  shell '/bin/bash'
  supports manage_home: true
end

# Create databases

pg_user 'git' do
  privileges superuser: false, createdb: false, login: true
  password 'password'
end

pg_database 'gitlabhq_production' do
  owner 'git'
end

# GitLab shell

git '/home/git/gitlab-shell' do
  repository 'git://github.com/gitlabhq/gitlab-shell.git'
  revision 'v1.5.0'
  user 'git'
end

template '/home/git/gitlab-shell/config.yml' do
  source 'gitlab-shell.config.yml'
  owner 'git'
end

bash 'run_gitlab_shell_install' do
  cwd '/home/git/gitlab-shell'
  code './bin/install'
  user 'git'
end

# GitLab

git '/home/git/gitlab' do
  repository 'git://github.com/gitlabhq/gitlabhq.git'
  revision '5-4-stable'
  user 'git'
end 

%w{ log tmp tmp/pid tmp/sockets public/uploads }.each do |dir|
  directory "/home/git/gitlab/#{dir}" do
    mode 00755
    recursive true
    action :create
    owner 'git'
  end
end

directory '/home/git/gitlab-satellites' do
  owner 'git'
  action :create
end

template '/home/git/gitlab/config/unicorn.rb' do
  source 'gitlab.unicorn.rb'
  owner 'git'
end

template '/home/git/gitlab/config/gitlab.yml' do
  source 'gitlab.gitlab.yml'
  owner 'git'
end

template '/home/git/gitlab/config/puma.rb' do
  source 'gitlab.puma.rb'
  mode 00755
  owner 'git'
end

template '/home/git/gitlab/config/resque.yml' do
  source 'gitlab.resque.yml'
  owner 'git'
end

bash 'configure_git_user' do
  user 'git'
  command <<-RUN
    git config --global user.name "GitLab"
    git config --global user.email "gitlab@localhost"
  RUN
end

gem_package 'charlock_holmes' do
  version '0.6.9.4'
end

execute 'bundle_gitlab' do
  user 'git'
  cwd '/home/git/gitlab'
  command 'bundle install --deployment --without development test mysql unicorn aws'
end

# Run GitLab setup

template '/home/git/gitlab/config/database.yml' do
  source 'gitlab.database.yml'
  user 'git'
end

execute 'create_gitlab_database' do
  user 'git'
  cwd '/home/git/gitlab'
  command 'bundle exec rake gitlab:setup RAILS_ENV=production force=yes && touch .gitlab-setup'
end

# Setup GitLab daemon

file '/home/git/gitlab/lib/support/init.d/gitlab' do
  mode 00755
end

link '/etc/init.d/gitlab' do
  to '/home/git/gitlab/lib/support/init.d/gitlab'
end

service 'gitlab' do
  action [:enable, :start]
end

# sudo cp lib/support/nginx/gitlab /etc/nginx/sites-available/gitlab
# sudo ln -s /etc/nginx/sites-available/gitlab /etc/nginx/sites-enabled/gitlab

template '/etc/nginx/sites-available/gitlab' do
  source 'gitlab.nginx.conf'
end

link '/etc/nginx/sites-enabled/gitlab' do
  to '/etc/nginx/sites-available/gitlab'
end

service 'nginx' do
  action :restart
end
