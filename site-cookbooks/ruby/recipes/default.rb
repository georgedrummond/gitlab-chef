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
