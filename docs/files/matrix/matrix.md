# Install Matrix Home Server 
sMessaging Server On Kubernetes

## Preface

**What is Matrix?**

!!! quote
    Matrix is an open standard for interoperable, decentralised, real-time communication over IP. It can be used to power Instant Messaging, VoIP/WebRTC signalling, Internet of Things communication - or anywhere you need a standard HTTP API for publishing and subscribing to data whilst tracking the conversation history.

Link: [https://matrix.org/faq/#what-is-matrix%3F](https://matrix.org/faq/#what-is-matrix%3F)

So we are about to install a private realtime messaging (Chat) server. It can be useful for you if you want to replace Whatsapp, Telegram, FB messanger, Viber, etc, or just want an own messaging server. Or if you don't trust in these services and want a serive which focus on your privacy. Another question is how your partners with whom you want to chat trust your server. 

I'm wondering if you have ever thought  about having an own messaging server. If the answer is yes, it's time to build one. I hope you will easily achieve  this with the help of this article.

## Requirements

* First and most important to have a valid domain name. If you don't have any you ca pick up one free from [DuckDNS](https://www.duckdns.org)
* Installed Kubernets cluster
* Public Internet access. 
* At least 2 GB of free RAM. 

I assume you build this server for your family and frieds, and don't want to share with the whole World. For some tens of people you don't need to purchase  expensive server, but according to the number of attachments (file, pictures, videos,etc) you may need some hundreds of GB disk space.

## Docker Compose

Maybe the easies way to install everything all together is wiritng a Docker compose file. The compose file below can be used with `docker-compose` command or as Stack in [Portainer](https://www.portainer.io).  Later in this artcie we will use this compose file as reference for writing the Kubernetes manifest files (cm, deployment, sevice, pvc, etc).


<pre class="line-numbers" data-src="https://raw.githubusercontent.com/jvincze84/jvincze84.github.io/master/docs/files/matrix/docker-compose.yaml"><code class="language-yaml"></code></pre>

You can see that we have 3 services:

* **matrix** : The Matrix server
* **caddy** : Web server for use as reverse proxy. 
    - You can use any other web server you like (eg.: Apache httpd, Nginx)
    - I chose Caddy because it is super easy to configure as reverse proxy and supports automtic SSL certificate genereation and maintance.
* **postgres** : Database engine.
    - You can skip this if you want to use the default sqlite engine, but it is not recommended for daily (production) use.

Before you `up` this compose file create the neccessary directories:

```bash
mkdir -p /opt/docker/matrix/config
mkdir /opt/docker/matrix/data
mkdir /opt/docker/matrix/caddy
mkdir /opt/docker/matrix/caddy/srv
mkdir /opt/docker/matrix/caddy/data
mkdir /opt/docker/matrix/caddy/config
mkdir /opt/docker/matrix/postgres
```

Matrix process run as `991` userID and groupID so we need to run `chown` command:

```bash
chown -R 991:991 /opt/docker/matrix
```

### Generate The Matrix Config File

For generating the initial config files please follow these steps:

<pre class="command-line" data-user="root" data-host="matrix-host" data-output="6-23,26,28-32"><code class="language-bash">docker run -it --rm \
    --mount type=bind,src=/opt/docker/matrix/config,dst=/data \
    -e SYNAPSE_SERVER_NAME=matrix.vincze.work \
    -e SYNAPSE_REPORT_STATS=yes \
    matrixdotorg/synapse:latest generate
Unable to find image 'matrixdotorg/synapse:latest' locally
latest: Pulling from matrixdotorg/synapse
7d63c13d9b9b: Pull complete
7c9d54bd144b: Pull complete
6c659176d5c8: Pull complete
31bfadeaf52b: Pull complete
b0be2954cd61: Pull complete
24d50aa74e2c: Pull complete
1816510873a0: Pull complete
227c613c4a00: Pull complete
097ac90fbed0: Pull complete
Digest: sha256:2c74baa38d3241aaf4a059a7e7c01786ba51ac5fe6fcf473ede3eb148f9358ba
Status: Downloaded newer image for matrixdotorg/synapse:latest
Creating log config /data/matrix.vincze.work.log.config
Generating config file /data/homeserver.yaml
Generating signing key file /data/matrix.vincze.work.signing.key
A config file has been generated in '/data/homeserver.yaml' for server name 'matrix.vincze.work'. Please review this file and customise it to your needs.

cd /opt/docker/matrix
mv ./config/matrix.vincze.work.signing.key ./config/matrix.vincze.work.log.config ./data

find data/ config/
data/
data/matrix.vincze.work.signing.key
data/matrix.vincze.work.log.config
config/
config/homeserver.yaml</code></pre>

!!! important
    You have to change `SYNAPSE_SERVER_NAME` to point to your own domain.

### Inititalize The Database


* Start the a postgres instance

```bash
docker run -d \
--name postgres-init \
--env POSTGRES_PASSWORD=rootpass \
--env POSTGRES_USER=root \
--env PGDATA=/data \
--env TZ=Europe/Budapest \
-v /opt/docker/matrix/postgres:/data \
postgres:14.0-alpine
```

!!! important
    Use the same environment values as in the compose file!

You may want to check the logs:

```bash
docker logs postgres-init -f
```

You should see the following lines:
```log
PostgreSQL init process complete; ready for start up.

2021-10-22 13:20:19.900 CEST [1] LOG:  starting PostgreSQL 14.0 on x86_64-pc-linux-musl, compiled by gcc (Alpine 10.3.1_git20210424) 10.3.1 20210424, 64-bit
2021-10-22 13:20:19.900 CEST [1] LOG:  listening on IPv4 address "0.0.0.0", port 5432
2021-10-22 13:20:19.900 CEST [1] LOG:  listening on IPv6 address "::", port 5432
2021-10-22 13:20:19.974 CEST [1] LOG:  listening on Unix socket "/var/run/postgresql/.s.PGSQL.5432"
2021-10-22 13:20:20.042 CEST [51] LOG:  database system was shut down at 2021-10-22 13:20:19 CEST
2021-10-22 13:20:20.077 CEST [1] LOG:  database system is ready to accept connections
```

* Get into the container and create the user and database

<pre class="command-line" data-user="root" data-host="matrix-host" data-output=""><code class="language-bash">docker exec -it postgres-init /bin/bash
createuser --pwprompt synapse_user
Enter password for new role:
Enter it again:
createdb --encoding=UTF8 --locale=C --template=template0 --owner=synapse_user synapse
exit</code></pre>

!!! info
    If you use another user than `root` (`POSTGRES_USER=root`) add `-U [USERNAME]` paramter at the and of the commands. `createuser --pwprompt synapse_user -U [USERNAME]`

!!! warning
    Note your provided password, you will need it when configuring Matrix!


* Remove The Container

```bash
docker stop postgres-init
docker rm postgres-init
```

!!! info
    If something went wrong you can simply stop and remove the container and delete the content of the database directory. 

    `rm -rf /opt/docker/matrix/postgres/*`

    And you can start over the init process of the database.

### Edit `homeserver.yaml`

```diff
--- homeserver.yaml-org 2021-10-22 13:43:26.753645597 +0200
+++ homeserver.yaml     2021-10-22 13:45:27.948188284 +0200
@@ -742,25 +742,25 @@
 #
 # Example Postgres configuration:
 #
-#database:
-#  name: psycopg2
-#  txn_limit: 10000
-#  args:
-#    user: synapse_user
-#    password: synapse
-#    database: synapse
-#    host: localhost
-#    port: 5432
-#    cp_min: 5
-#    cp_max: 10
+database:
+  name: psycopg2
+  txn_limit: 10000
+  args:
+    user: synapse_user
+    password: 12345678
+    database: synapse
+    host: matrix-postgres
+    port: 5432
+    cp_min: 5
+    cp_max: 10
 #
 # For more information on using Synapse with Postgres,
 # see https://matrix-org.github.io/synapse/latest/postgres.html.
 #
-database:
-  name: sqlite3
-  args:
-    database: /data/homeserver.db
+#database:
+#  name: sqlite3
+#  args:
+#    database: /data/homeserver.db


 ## Logging ##
```

!!! caution
    Don't forget to remove sqlite3 related lines as the example shows.


### Inititalize The Caddyfile

```bash
cd /opt/docker/matrix/caddy
docker  run -it  --entrypoint=/bin/sh  caddy:latest -c "cat /etc/caddy/Caddyfile"  >Caddyfile
```

This will create a minimal `Caddyfile` example. Actually this command does nothing than copy the `Caddyfile` from the container to the directory where you are.

**Edit this file**

============================================================





root@kube-test:/opt/docker/caddy-buiild# cat Dockerfile
FROM caddy:2.4.5-builder-alpine AS builder

RUN xcaddy build \
    --with github.com/caddy-dns/duckdns


FROM caddy:2.4.5-alpine

COPY --from=builder /usr/bin/caddy /usr/bin/caddy

root@kube-test:/opt/docker/matrix# cat caddy/Caddyfile
*.matrix-kub-test.duckdns.org:443 {
        # Set this path to your site's directory.
        root * /usr/share/caddy

        # Enable the static file server.
        file_server

        # Another common task is to set up a reverse proxy:
        # reverse_proxy localhost:8080

        # Or serve a PHP site through php-fpm:
        # php_fastcgi localhost:9000
        tls {
                dns duckdns bd1e84b5-e44a-4a43-b28e-06d3ec32d705 {
                 override_domain matrix-kub-test.duckdns.org
              }
        }
}



