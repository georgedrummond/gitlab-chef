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

# GitLab

git '/home/gitlab_ci/gitlab-ci' do
  repository 'git://github.com/gitlabhq/gitlab-ci.git'
  user 'gitlab_ci'
end 

