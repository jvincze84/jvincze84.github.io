---
title: Yet Another Article About Docker Logging With Fluentd
date: 2021-12-18
---

# Yet Another Article About Docker Logging With Fluentd

## Motivation

I have three hosts with Docker + Portainer:

 * Two VPS server with public IP address
 * A home server behind NAT
 
I want to show all the logs from containers in one place. 

I already have a Kubernetes cluster at home, on which I have Kibana and Elasticsearch deployed for the cluster logging. It is obvious to use my already existing logging solution to collect logs from the Docker hosts.

## Install Fluentd On Docker Hosts

Official Documentation: [https://docs.fluentd.org/installation/install-by-deb](https://docs.fluentd.org/installation/install-by-deb)

Example installation on Debian bullseye:

```bash
curl -fsSL https://toolbelt.treasuredata.com/sh/install-debian-bullseye-td-agent4.sh | sh
```

## Configure Td-Agent

Default config file location: `/etc/td-agent/td-agent.conf`

### Input For Docker Daemon

Documentation: [https://docs.fluentd.org/input/forward](https://docs.fluentd.org/input/forward)

This section is responsible for receiving the logs from the Docker daemon.

```xml
<source>
  @type forward
  port 24224
  bind 0.0.0.0
</source>
```

### Output Configuration

As I mentioned in the short motivation section I want to store the logs in my Elasticsearch cluster.

Documentation: [https://docs.fluentd.org/output/elasticsearch](https://docs.fluentd.org/output/elasticsearch)

Configuration example:

```code
<match {syslog.**,dockerdaemon.**}>
  @type elasticsearch
  suppress_type_name true
  host "10.8.0.30"
  scheme http
  path ""
  port 32367
  include_tag_key true
  reload_connections false
  reconnect_on_error true
  reload_on_failure false
  logstash_format true
  logstash_prefix "vps10"
  <buffer>
    @type file
    path /var/log/td-agent/buffer
    flush_thread_count 8
    flush_interval 5s
    chunk_limit_size 2M
    queue_limit_length 32
    retry_max_interval 30
    retry_forever true
  </buffer>
</match>
```

**Some important settings and its explanation:**


`suppress_type_name`

: In Elasticsearch 7.x, Elasticsearch cluster complains the following types removal warnings  
``` json
  {
  "type": "deprecation",
  "timestamp": "2020-07-03T08:02:20,830Z",
  "level": "WARN",
  "component": "o.e.d.a.b.BulkRequestParser",
  "cluster.name": "docker-cluster",
  "node.name": "70dd5c6b94c3",
  "message": "[types removal] Specifying types in bulk requests is deprecated.",
  "cluster.uuid": "NoJJmtzfTtSzSMv0peG8Wg",
  "node.id": "VQ-PteHmTVam2Pnbg7xWHw"
}
```

`host "10.8.0.30"`

: Elasticsearch hostname or IP address. This VPS server is connecting to Elasticsearch over Wireguard VPN.

`port 32367`

: My Elasticsearch is running on my Kubernetes cluster, and I'm using NodePort to access it. 

`logstash_format`

: This is meant to make writing data into Elasticsearch indices compatible to what Logstash calls them. By doing this, one could take advantage of Kibana. See `logstash_prefix` and `logstash_dateformat` to customize this index name pattern. The index name will be `#{logstash_prefix}-#{formatted_date}`

`reload_connections false`

: You can tune how the elasticsearch-transport host reloading feature works. By default it will reload the host list from the server every 10,000th request to spread the load. This can be an issue if your Elasticsearch cluster is behind a Reverse Proxy, as Fluentd process may not have direct network access to the Elasticsearch nodes.

`reconnect_on_error`

: Indicates that the plugin should reset connection on any error (reconnect on next send). By default it will reconnect only on "host unreachable exceptions". We recommended to set this true in the presence of elasticsearch shield.

`reload_on_failure`

: Indicates that the elasticsearch-transport will try to reload the nodes addresses if there is a failure while making the request, this can be useful to quickly remove a dead node from the list of addresses.

The `reload_connections`, `reconnect_on_error`, `reload_on_failure` setting are needed because may Elasticsearch cluster has only one node and Fluentd connects to it over VPN and `NodePort`. 

### Syslog Input

```conf
<source>
  @type tail
  path /var/log/syslog,/var/log/messages
  pos_file /var/log/td-agent/syslog.pos
  tag syslog.*
  <parse>
    @type syslog
  </parse>
</source>
```

Parser documentation: [https://docs.fluentd.org/parser/syslog](https://docs.fluentd.org/parser/syslog)

### Syslog Filter

```conf
<filter syslog.**>
  @type record_transformer
  <record>
    hostname "#{Socket.gethostname}"
    tag ${tag}
  </record>
</filter>
```

**What does this filter do?**

* Adds the fluentd tag to the json message. (`Line 13`) This can be very useful for debugging, as well.
* Adds hostname field to the json message. (`Line 12`)

Example:
```json hl_lines="12 13" linenums="1"
{
  "_index": "vps10-2021.12.18",
  "_type": "_doc",
  "_id": "KD5Azn0BkfuDokpII8aN",
  "_version": 1,
  "_score": null,
  "_source": {
    "host": "vps10",
    "ident": "tailscaled",
    "pid": "361",
    "message": "netmap diff:",
    "hostname": "vps10",
    "tag": "syslog.var.log.syslog",
    "@timestamp": "2021-12-18T16:54:03.000000000+01:00"
  },
  "fields": {
    "@timestamp": [
      "2021-12-18T15:54:03.000Z"
    ]
  },
  "highlight": {
    "tag": [
      "@kibana-highlighted-field@syslog.var.log.syslog@/kibana-highlighted-field@"
    ]
  },
  "sort": [
    1639842843000
  ]
} 
```

### Docker Filter

```conf
<filter dockerdaemon.**>
  @type record_transformer
  <record>
    tag ${tag}
  </record>
</filter>
```

This is similar to the previous syslog filter.

## Docker Daemon Config

```json  hl_lines="4 5 6" linenums="1"
{
  "log-driver": "fluentd",
  "log-opts": {
    "fluentd-address": "localhost:24224",
    "fluentd-async": "true",
    "tag": "dockerdaemon.{{.Name}}"
  }
} 
```

**Line 4**

: Send logs to fluentd. Related fluentd config: [input-for-docker-daemon](#input-for-docker-daemon)

**Line 5**

: Docker connects to Fluentd in the background. Messages are buffered until the connection is established.  
  Doc: [https://docs.docker.com/config/containers/logging/fluentd/#fluentd-async](https://docs.docker.com/config/containers/logging/fluentd/#fluentd-async)

**Line 6**

: Related Fluentd config: [docker-filter](#docker-filter)  


**Example JSON:**

```json  hl_lines="12" linenums="1"
{
  "_index": "vps10-2021.12.18",
  "_type": "_doc",
  "_id": "JD9Qzn0BkfuDokpI9zL6",
  "_version": 1,
  "_score": null,
  "_source": {
    "source": "stderr",
    "log": "level=info ts=2021-12-18T16:12:27.363614782Z caller=table_manager.go:171 msg=\"uploading tables\"",
    "container_id": "a2afeb9b67029f94c0267f7e1d24adf1fa87fd13e8ab8aa232bcda44a951bff6",
    "container_name": "/loki",
    "tag": "dockerdaemon.loki",
    "@timestamp": "2021-12-18T17:12:27.000000000+01:00"
  },
  "fields": {
    "@timestamp": [
      "2021-12-18T16:12:27.000Z"
    ]
  },
  "highlight": {
    "container_name": [
      "/@kibana-highlighted-field@loki@/kibana-highlighted-field@"
    ]
  },
  "sort": [
    1639843947000
  ]
}
```

!!! warning
    It's not enough to restart the docker daemon to take affects logging settings on containers. Every container have to be recreated. (not just restarted)

## Benefits Of Using Proper Tags

In the examples above all of you containers are tagged with their name. It is useful when you want to parse default type of container logs. 

Another `/etc/docker/daemon.json` example:

```json
{
  "log-driver": "fluentd",
  "log-opts": {
    "fluentd-address": "localhost:24224",
    "fluentd-async": "true",
    "tag": "docker.{{.Name}}.{{.ID}}"
  }
}
```

On this host I have an apache web server container:
```plain
docker ps --filter name=apache
CONTAINER ID   IMAGE     COMMAND                  CREATED       STATUS      PORTS                                      NAMES
d0379e25ca01   httpd     "httpd-foreground -d…"   2 weeks ago   Up 2 days   0.0.0.0:80->80/tcp, 0.0.0.0:443->443/tcp   apache

```

I want to parse the logs from apache container. Thanks to the proper tag settings I can write filter like this:
```conf
<filter docker.apache.**>
  @type parser
  key_name log
  reserve_data true
  emit_invalid_record_to_error false
  <parse>
    @type apache
    expression /^(?<vhost>[^ ]*) (?<host>[^ ]*) [^ ]* (?<user>[^ ]*) \[(?<time>[^\]]*)\] "(?<method>\S+)(?: +(?<path>(?:[^\"]|\\.)*?)(?: +\S*)?)?" (?<code>[^ ]*) (?<size>[^ ]*) (?:"(?<referer>(?:[^\"]|\\.)*)" "(?<agent>(?:[^\"]|\\.)*)")?$/
  </parse>
</filter>
```

Matching apache log format:
```apache
LogFormat "%V:%p %h %l %u %t \"%r\" %>s %O \"%{Referer}i\" \"%{User-Agent}i\"" vhost_combined
```

Example JSON log message:
```json  hl_lines="12-21" linenums="1"
{
  "_index": "nuc-2021.12.18",
  "_type": "_doc",
  "_id": "qj9Yzn0BkfuDokpIOGHF",
  "_version": 1,
  "_score": null,
  "_source": {
    "container_id": "d0379e25ca010ddcaa69890bde9561d2dd64433998cb0d310be47e965a95fbc9",
    "container_name": "/apache",
    "source": "stdout",
    "log": "matrix.k8s.home.vinyosoft.info:443 68.183.156.15 - - [18/Dec/2021:17:20:25 +0100] \"PUT /_matrix/federation/v1/send/1639791664430 HTTP/1.1\" 403 6750 \"-\" \"Synapse/1.49.0\"",
    "vhost": "matrix.k8s.home.vinyosoft.info:443",
    "host": "68.183.156.15",
    "user": "-",
    "method": "PUT",
    "path": "/_matrix/federation/v1/send/1639791664430",
    "code": "403",
    "size": "6750",
    "referer": "-",
    "agent": "Synapse/1.49.0",
    "tag": "docker.apache.d0379e25ca01",
    "@timestamp": "2021-12-18T17:20:25.000000000+01:00"
  },
  "fields": {
    "@timestamp": [
      "2021-12-18T16:20:25.000Z"
    ]
  },
  "highlight": {
    "container_name": [
      "/@kibana-highlighted-field@apache@/kibana-highlighted-field@"
    ]
  },
  "sort": [
    1639844425000
  ]
} 
```

## Complete Fluentd Config


```json title='<a href="https://raw.githubusercontent.com/jvincze84/jvincze84.github.io/master/docs/files/td-agen-20211218.conf" target="_blank">Click Here For Raw Source</a>' linenums="1"
--8<-- "docs/files/td-agen-20211218.conf"
```













