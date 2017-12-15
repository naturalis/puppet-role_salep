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
  $miniokey             = '12345',
  $miniosecret          = '12345678',
  $repo_source          = 'https://github.com/naturalis/docker-salep.git',
  $repo_ensure          = 'latest',
  $repo_dir             = '/opt/salep',
	$kibana_auth          = 'traefik.frontend.auth.basic=kibana:$$apr1$$ftqdhhqs$$rkzzoj02m.k3eq4qkn3re/',
	$minio_url            = 'salep-minio.naturalis.nl',
	$kibana_url						= 'salep-kibana.naturalis.nl',
  $lets_encrypt_mail    = 'mail@example.com',
	$traefik_toml_file    = '/opt/traefik/traefik.toml',
	$traefik_acme_json    = '/opt/traefik/acme.json'

){

  include 'docker'
  include 'stdlib'

  Exec {
    path => '/usr/local/bin/',
    cwd  => "${role_salep::repo_dir}",
  }

  file { ['/data','/data/traefik'] :
    ensure              => directory,
  }

	file { $traefik_toml_file :
		ensure   => file,
		content  => template('role_salep/traefik.toml.erb'),
		require  => File['/data/traefik'],
	}

  file { $traefik_acme_json :
		ensure   => present,
		require  => File['/data/traefik'],
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
    options			=> "-f docker-compose.prod.yml --project-directory ${role_salep::repo_dir}",
    require     => [ 
			Vcsrepo[$role_salep::repo_dir],
			File[$traefik_acme_json],
			File[$traefik_toml_file]
		]
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
		require => Docker_compose["${role_salep::repo_dir}/docker-compose.yml"],
  }

  exec {'Copy mapping to salep volume':
    command => '/bin/cp elasticsearch_mapping.json /data/salep/elasticsearch_mapping.json',
    creates => '/data/salep/elasticsearch_mapping.json',
		require => Docker_compose["${role_salep::repo_dir}/docker-compose.yml"],
  }

  exec {'Set mapping for salep':
    command => 'docker-compose exec -T salep bash -c "curl -s -XPUT -H \"Content-Type: application/json\" elasticsearch:9200/scrapy -d @/data/elasticsearch_mapping.json "',
    unless  => 'docker-compose exec -T salep bash -c "curl -s elasticsearch:9200/_cat/indices?h=index | grep scrapy"',
    require => [
			Exec['Copy mapping to salep volume'],
			Docker_compose["${role_salep::repo_dir}/docker-compose.yml"]
			]
  }
  
  # deze gaat per dag 1 keer checken
  # je kan ook een range aan geven, bv tussen 7 en 9 's ochtends
  schedule { 'everyday':
     period  => daily,
     repeat  => 1,
     range => '5-7',
  }
 

}
