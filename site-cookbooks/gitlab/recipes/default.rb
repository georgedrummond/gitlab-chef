include_recipe 'postgresql'

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

remote_file '/tmp/ruby/ruby-2.0.0-p247.tar.gz' do
  source 'http://ftp.ruby-lang.org/pub/ruby/2.0/ruby-2.0.0-p247.tar.gz'
  action :create_if_missing
end

bash 'compile_ruby_from_source' do
  cwd '/tmp/ruby'
  code <<-RUN
    tar zxf ruby-2.0.0-p247.tar.gz
    cd ruby-2.0.0-p247
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

# GitLab shell

git '/home/git/gitlab-shell' do
  repository 'git://github.com/gitlabhq/gitlab-shell.git'
  revision 'v1.7.0'
  user 'git'
end

template '/home/git/gitlab-shell/config.yml' do
  source 'gitlab-shell.config.yml'
end

bash 'run_gitlab_shell_install' do
  cwd '/home/git/gitlab-shell'
  code './bin/install'
end

# GitLab

git '/home/git/gitlab' do
  repository 'git://github.com/gitlabhq/gitlabhq.git'
  revision '5-3-stable'
  user 'git'
end 

template '/home/git/gitlab/config.yml' do
  source 'gitlab.config.yml'
end

%w{ log tmp tmp/pid tmp/sockets public/uploads }.each do |dir|
  directory "/home/git/gitlab/#{dir}" do
    mode 00755
    recursive true
    action :create
  end
end

directory '/home/git/gitlab-satellites' do
  owner 'git'
  action :create
end

template '/home/git/gitlab/config/unicorn.rb' do
  source 'gitlab.unicorn.rb'
end

bash 'configure_git_user' do
  user 'git'
  command <<-RUN
    git config --global user.name "GitLab"
    git config --global user.email "gitlab@localhost"
    git config --global core.autocrlf input
  RUN
end

gem_package 'charlock_holmes' do
  version '0.6.9.4'
end

execute 'bundle_gitlab' do
  user 'git'
  cwd '/home/git/gitlab'
  command 'bundle install --deployment --without development test postgres mysql unicorn aws'
end

# Setup postgresql

%w{ postgresql-9.1 libpq-dev }.each do |pkg|
  package pkg
end

# Create db user



execute 'create_gitlab_database' do
  user 'git'
  command 'bundle exec rake gitlab:setup RAILS_ENV=production force=yes && touch .gitlab-setup'
end


