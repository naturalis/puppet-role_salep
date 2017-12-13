# == Class: role_salep
#
# === Authors
#
# Author Name <hugo.vanduijn@naturalis.nl>
#
# === Copyright
#
# Apache2 license 2017.
#
class role_salep (
  $compose_version      = '1.17.0',
  $miniokey             = '123456',
  $miniosecret          = '12345678',
  $repo_source          = 'https://github.com/naturalis/docker-salep.git',
  $repo_ensure          = 'latest',
  $repo_dir             = '/opt/salep',
){

  include 'docker'

  file { '/data' :
    ensure              => directory,
  }

  class {'docker::compose': 
    ensure      => present,
    version     => $role_salep::compose_version
  }

  package { 'git':
    ensure   => installed,
  }

  vcsrepo { $role_salep::repo_dir:
    ensure    => $role_salep::repo_ensure,
    source    => $role_salep::repo_source,
    provider  => 'git',
    user      => 'root',
    revision  => 'master',
    require   => Package['git'],
  }

  docker_compose { "${role_salep::repo_dir}/docker-compose.yml":
    ensure      => present,
    require     => Vcsrepo[$role_salep::repo_dir]
  }

}
