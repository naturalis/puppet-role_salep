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
  include 'stdlib'
  
  Exec {
    path => '/usr/local/bin/',
    cwd  => "${role_salep::repo_dir}",
  }

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

  exec { 'Pull containers' :
    command  => 'docker-compose pull',
    schedule => 'everyday',
  }

  exec { 'Up the containers to resolve updates' :
    command  => 'docker-compose up -d',
    schedule => 'everyday',
    require  => Exec['Pull containers']
  }
 
  exec { 'Run salep job' :
    command  => 'docker-compose exec -d salep bash -c "cd /usr/local/lib/python3.5/dist-packages/ebay_scraper; scrapy crawl ebay_spider"',
    schedule => 'everyday',
    require  => Exec['Up the containers to resolve updates'],
  }

  exec {'Set replicas of kibana to 0':
    command => 'docker-compose exec -T salep bash -c "curl -s -XPUT -H \"Content-Type: application/json\" elasticsearch:9200/_settings -d \'{\"number_of_replicas\": 0}\'"',
    unless  => 'docker-compose exec -T salep bash -c "curl -s elasticsearch:9200/_cat/indices/.kibana?h=rep | grep ^0$"',
  }

  exec {'Copy mapping to salep volume':
    command => '/bin/cp elasticsearch_mapping.json /data/salep/elasticsearch_mapping.json',
    creates => '/data/salep/elasticsearch_mapping.json',
  }

  exec {'Set mapping for salep':
    command => 'docker-compose exec -T salep bash -c "curl -s -XPUT -H \"Content-Type: application/json\" elasticsearch:9200/scrapy -d @/data/elasticsearch_mapping.json "',
    unless  => 'docker-compose exec -T salep bash -c "curl -s elasticsearch:9200/_cat/indices?h=index | grep scrapy"',
    require => Exec['Copy mapping to salep volume'],
  }
  
  # deze gaat per dag 1 keer checken
  # je kan ook een range aan geven, bv tussen 7 en 9 's ochtends
  schedule { 'everyday':
     period  => daily,
     repeat  => 1,
     range => '5-7',
  }
 

}
