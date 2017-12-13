puppet-role_salep
===================

Puppet role definition for deployment of salep webcrawler using docker

Parameters
-------------
Sensible defaults for Naturalis in init.pp

```
  $minio_key                              = '123456',
  $minio_secret                           = '12345678',

```


Classes
-------------
- role_salep::init

Dependencies
-------------
gareth/docker


Puppet code
```
class { role_salep: }
```
Result
-------------
Salep webcrawler deployment using docker-compose which should result in running python salep crawler logging to elasticsearch, visible in kibana and data extractable using minio.


Limitations
-------------
This module has been built on and tested against Puppet 4 and higher.

The module has been tested on:
- Ubuntu 16.04LTS

Dependencies releases tested: 
- gareth/docker 5.3.0







Authors
-------------
Author Name <hugo.vanduijn@naturalis.nl>

