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
  $salep_deploy_key,
  $compose_version      = '1.17.0',
  $miniokey             = '12345',
  $miniosecret          = '12345678',
  $repo_source          = 'git://github.com/naturalis/docker-salep.git',
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
  $timestamp = strftime("%Y-%m-%d")

  Exec {
    path => '/usr/local/bin/',
    cwd  => "${role_salep::repo_dir}",
  }

  file { ['/data','/opt/traefik'] :
    ensure              => directory,
  }

	file { $traefik_toml_file :
		ensure   => file,
		content  => template('role_salep/traefik.toml.erb'),
		require  => File['/opt/traefik'],
		notify   => Exec['Restart containers on change'],
	}

  file { $traefik_acme_json :
		ensure   => present,
		mode     => '0600',
		require  => File['/opt/traefik'],
		notify   => Exec['Restart containers on change'],
	}

  file { "${role_salep::repo_dir}/.env":
		ensure   => file,
		content  => template('role_salep/prod.env.erb'),
    require  => Vcsrepo[$role_salep::repo_dir],
		notify   => Exec['Restart containers on change'],
	}

  class {'docker::compose':
    ensure      => present,
    version     => $role_salep::compose_version
  }

  package { 'git':
    ensure   => installed,
  }

  file { '/opt/salep_deploy_key':
    ensure  => present,
    mode    => '0600',
    content => $salep_deploy_key,
  }

  vcsrepo { $role_salep::repo_dir:
    ensure            => $role_salep::repo_ensure,
    source            => $role_salep::repo_source,
    provider          => 'git',
    user              => 'root',
    identity          => '/opt/salep_deploy_key',
    trust_server_cert =>  true,
    revision          => 'master',
    require           => [
        Package['git'],
        File['/opt/salep_deploy_key']
      ]
  }

	docker_network { 'web':
		ensure   => present,
	}

  docker_compose { "${role_salep::repo_dir}/docker-compose.yml":
    ensure      => present,
#    options			=> "-f ${role_salep::repo_dir}/docker-compose.prod.yml --project-directory ${role_salep::repo_dir}",
    require     => [ 
			Vcsrepo[$role_salep::repo_dir],
			File[$traefik_acme_json],
			File["${role_salep::repo_dir}/.env"],
			File[$traefik_toml_file],
			Docker_network['web']
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
#    command  => 'docker-compose exec -T -d salep bash -c "cd /usr/local/lib/python3.5/dist-packages/ebay_scraper; scrapy crawl ebay_spider -t csv -o /data/csv/$(date +%Y-%m-%d).csv"',
    command  => "docker-compose exec -T -d salep bash -c 'cd /usr/local/lib/python3.5/dist-packages/ebay_scraper; scrapy crawl ebay_spider -t csv -o /data/csv/${timestamp}.csv'",
    schedule => 'weekly',
    logoutput => true,
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

  exec {'Restart containers on change':
	  refreshonly => true,
		command     => 'docker-compose up -d',
		require     => Docker_compose["${role_salep::repo_dir}/docker-compose.yml"],
	}

  # deze gaat per dag 1 keer checken
  # je kan ook een range aan geven, bv tussen 7 en 9 's ochtends
  schedule { 'everyday':
     period  => daily,
     repeat  => 1,
     range => '5-7',
  }

  schedule { 'weekly':
     period  => weekly,
     repeat  => 1,
     range => '10:00-13:00',
     weekday => 'Sun',
  }

}
