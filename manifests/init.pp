# == Class: role_salep
#
# === Authors
#
# Author Name <foppe.pieters@naturalis.nl>
#
# === Copyright
#
# Apache2 license 2017.
#
class role_salep (
  $miniokey             = '123456',
  $miniosecret          = '12345678',
){

  file { '/data' :
    ensure              => directory,
  }

  class { 'docker' :
    version             => 'latest',
  }
  ->
  docker_network { 'docker-net':
    ensure              => present,
    subnet              => '172.10.0.0/16',
  }

  class { 'role_salep::salep' :
    require             => Class['docker']
  }

}
