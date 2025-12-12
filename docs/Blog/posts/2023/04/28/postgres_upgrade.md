---
title: Upgrade PostgresSQL On Kubernetes With Job
date: 2023-04-28
---


# Upgrade PostgresSQL On Kubernetes With Job

!!! danger
    UNFINISHED POST!!!!

## Preface

Initially I wrote this script & job to myself, but I found that it can be useful for others as well. This article is not a kind of "use as is", and need some deeper knowledge to adapt it to your environment. So use my post as a skeleton, and modify according to your needs.

## Starting Point & Requirements

In order to understand what I'm doing you need to know some detailed information about my environment.

Kubernetes & OS:

* Kuberenets version: `v1.25.6`
* OS: `Debian GNU/Linux 11 (bullseye)`
* Kernel: `5.10.0-21-amd64`
* Container Engine: `containerd://1.6.6`
* Persistent volume provider: `Longhorn v1.4.1`
* Old Postgres Version (docker image): `postgres:12`
* New Postgres Version (docker image): `postgres:14`

### Requirements

* Running both old and new Postgres Deployment
	- I highly recommend to create new PVC for the new cluster.
* Temporary PVC for the dump
	- You can use ephemeral (emptydir) volume for the dump, but you will lose your dump file after the Job finished. 

### Current State & New Postgres

So I have a relatively old Postgres 12 server. 

??? example "Deployment OLD"
    ```yaml
    kind: Deployment
    apiVersion: apps/v1
    metadata:
      name: postgres
      namespace: postgres
    spec:
      replicas: 1
      selector:
        matchLabels:
          k8s-app: postgres
      template:
        metadata:
          name: postgres
          creationTimestamp: null
          labels:
            k8s-app: postgres
        spec:
          volumes:
            - name: pgdata
              persistentVolumeClaim:
                claimName: pgdata
          containers:
            - name: postgres
              image: postgres:12
              env:
                - name: TZ
                  value: Europe/Budapest
                - name: LC_ALL
                  value: C.UTF-8
                - name: POSTGRES_PASSWORD
                  valueFrom:
                    secretKeyRef:
                      name: postgres
                      key: admin-pass
                - name: POSTGRES_USER
                  value: admin
                - name: PGDATA
                  value: /var/lib/postgresql/data/pgdata
              resources: {}
              volumeMounts:
                - name: pgdata
                  mountPath: /var/lib/postgresql/data
              terminationMessagePath: /dev/termination-log
              terminationMessagePolicy: File
              imagePullPolicy: IfNotPresent
              securityContext:
                privileged: false
          restartPolicy: Always
          terminationGracePeriodSeconds: 30
          dnsPolicy: ClusterFirst
          nodeSelector:
            location: vps
          securityContext: {}
          schedulerName: default-scheduler
      strategy:
        type: Recreate
      revisionHistoryLimit: 10
      progressDeadlineSeconds: 600
    ```

As you can this is really simple Postgres deployment. 
My new Postgres Deployment is very similar to this:

??? example "Deployment NEW"
    ```yaml
    kind: Deployment
    apiVersion: apps/v1
    metadata:
      name: postgres-v14
      namespace: postgres
    spec:
      replicas: 1
      selector:
        matchLabels:
          k8s-app: postgres-v14
      template:
        metadata:
          name: postgres-v14
          creationTimestamp: null
          labels:
            k8s-app: postgres-v14
        spec:
          volumes:
            - name: pgdata-v14
              persistentVolumeClaim:
                claimName: pgdata-v14
          containers:
            - name: postgres-v14
              image: postgres:14
              env:
                - name: TZ
                  value: Europe/Budapest
                - name: LC_ALL
                  value: C.UTF-8
                - name: POSTGRES_PASSWORD
                  valueFrom:
                    secretKeyRef:
                      name: postgres
                      key: admin-pass
                - name: POSTGRES_USER
                  value: pg-14-admin
                - name: PGDATA
                  value: /var/lib/postgresql/data/pgdata
              resources: {}
              volumeMounts:
                - name: pgdata-v14
                  mountPath: /var/lib/postgresql/data
              terminationMessagePath: /dev/termination-log
              terminationMessagePolicy: File
              imagePullPolicy: IfNotPresent
              securityContext:
                privileged: false
          restartPolicy: Always
          terminationGracePeriodSeconds: 30
          dnsPolicy: ClusterFirst
          nodeSelector:
            location: vps
          securityContext: {}
          schedulerName: default-scheduler
      strategy:
        type: Recreate
      revisionHistoryLimit: 10
      progressDeadlineSeconds: 600
    ```

For better understanding here are the differences:

```diff
--- old  2023-04-27 13:31:24.633567033 +0200
+++ new  2023-04-27 13:32:21.653176863 +0200
@@ -1,29 +1,29 @@
     kind: Deployment
     apiVersion: apps/v1
     metadata:
-      name: postgres
+      name: postgres-v14
       namespace: postgres
     spec:
       replicas: 1
       selector:
         matchLabels:
-          k8s-app: postgres
+          k8s-app: postgres-v14
       template:
         metadata:
-          name: postgres
+          name: postgres-v14
           creationTimestamp: null
           labels:
-            k8s-app: postgres
+            k8s-app: postgres-v14
         spec:
           volumes:
-            - name: pgdata
+            - name: pgdata-v14
               persistentVolumeClaim:
-                claimName: pgdata
+                claimName: pgdata-v14
           containers:
-            - name: postgres
-              image: postgres:12
+            - name: postgres-v14
+              image: postgres:14
               env:
                 - name: TZ
                   value: Europe/Budapest
                 - name: LC_ALL
                   value: C.UTF-8
@@ -31,16 +31,16 @@
                   valueFrom:
                     secretKeyRef:
                       name: postgres
                       key: admin-pass
                 - name: POSTGRES_USER
-                  value: admin
+                  value: pg-14-admin
                 - name: PGDATA
                   value: /var/lib/postgresql/data/pgdata
               resources: {}
               volumeMounts:
-                - name: pgdata
+                - name: pgdata-v14
                   mountPath: /var/lib/postgresql/data
               terminationMessagePath: /dev/termination-log
               terminationMessagePolicy: File
               imagePullPolicy: IfNotPresent
               securityContext:
```

!!! danger
    Do not use the same `POSTGRES_USER` for the old and new cluster. In my case the old postgres used `md5` auth, but the new `SCRAM-SHA-256`. 
    In this situation you will overwrite the `admin` user's password, and won't be able to load the database, and login. Later in this post I'm going to write some details about this problem.


**Kubernetes `Services`** (namespace: postgres)

```plain
NAME           TYPE           CLUSTER-IP      EXTERNAL-IP    PORT(S)          AGE    SELECTOR
pgadmin        ClusterIP      10.25.29.142    <none>         80/TCP           247d   k8s-app=pgadmin
postgres       LoadBalancer   10.25.155.130   172.16.2.108   5432:32418/TCP   247d   k8s-app=postgres
postgres-v14   ClusterIP      10.25.109.68    <none>         5432/TCP         11d    k8s-app=postgres-v14
```

So I have two services: one for the old and one for the new Postgres:

| Postgres Version |IP Address     | Namespace | Service      | Cluster DNS       | FQDN                                    |
|------------------|---------------|-----------|--------------|-------------------| ----------------------------------------|
| postgres:12      | 10.25.155.130 | postgres  | postgres     | svc.cluster.local | postgres.postgres.svc.cluster.local     |
| postgres:14      | 10.25.109.68  | postgres  | postgres-v14 | svc.cluster.local | postgres-v14.postgres.svc.cluster.local |

## Upgrade Process

### Shell Script

First of all we need to prepare the shell script.

```bash
#!/usr/bin/env bash

if [ "$1" == "dump" ]
then
  echo "Check variables.."
  [[ -z "$PGDUMP_PATH" ]] && { echo "Missing PGDUMP_PATH" ; exit 1 ; }
  echo "PGDUMP_PATH is OK"
  [[ -z "$PG_USER" ]] && { echo "Missing PG_USER" ; exit 1; }
  echo "PG_USER is OK"
  [[ -z "$PG_PASS" ]] && { echo "Missing PG_PASS" ;exit 1 ; }
  echo "PG_PASS is OK"
  [[ -z "$PG_HOST" ]] && { echo "Missing PG_HOST" ; exit 1 ; }
  echo "PG_HOST is OK"
  echo "Prepare .pgpass file"
  echo "${PG_HOST}:5432:*:${PG_USER}:${PG_PASS}" >$HOME/.pgpass
  chmod 600 $HOME/.pgpass

  # Check if pg_dumpall.sql file is already exists or not. If yes skip dump.
  [[ -f $PGDUMP_PATH/pg_dumpall.sql ]] && { echo "$PGDUMP_PATH/pg_dumpall.sql is already exists. Exiting" ; exit 0 ; }
  echo "Dumping Old database to $PGDUMP_PATH/pg_dumpall.sql"

  /usr/bin/pg_dumpall -w -h ${PG_HOST} -U ${PG_USER} >$PGDUMP_PATH/pg_dumpall.sql
  echo "Printing result"
  ls -lah $PGDUMP_PATH
fi

if [ "$1" == "load" ]   
then
  echo "Checking Variables"
  [[ -z "$NEW_PG_HOST" ]] && { echo "Missing NEW_PG_HOST" ; exit 1 ; }
  echo "NEW_PG_HOST is OK"
  NEW_PG_USER="${NEW_PG_USER:-${PG_USER}}"
  NEW_PG_PASS="${NEW_PG_PASS:-${PG_PASS}}"  
  echo "Prepare .pgapss file"
  echo "${NEW_PG_HOST}:5432:*:${NEW_PG_USER}:${NEW_PG_PASS}" >$HOME/.pgpass
  chmod 600 $HOME/.pgpass

  echo "Loading Data Into The New Database"
  psql -h ${NEW_PG_HOST} -U ${NEW_PG_USER} <$PGDUMP_PATH/pg_dumpall.sql
fi
```

The script has two modes depend on the first argument:

* **``dump``**
    - Dump the old database. 
* **``load``**
    - Load the previously created dump to the new database.

#### Variables

`PGDUMP_PATH`

: **Mandatory** varible.
  
  * Used by: dump & load
  * Where the dump file will be saved to, and load from.
  * Must match in dump and load container.

`PG_USER | PG_PASS | PG_HOST`

: **Mandatory** varibles.

  * Used by: dump
  * Related to the old database.
  * You may want to use Kubernetes `secret` instead of plain text here.

`NEW_PG_HOST`

: **Mandatory** varible.

  * Used by: load
  * Releted to the new database

`NEW_PG_USER | NEW_PG_PASS`

: **Optional But Recommended** variables.

  * Used by: load
  * Related to the new database
  * If you skip to define these variables the script will use the `PG_USER | PG_PASS`. Despite I don't recommend to use the same user, you can do it if you know what you are doing.
    - `NEW_PG_USER="${NEW_PG_USER:-${PG_USER}}"`
    - `NEW_PG_PASS="${NEW_PG_PASS:-${PG_PASS}}"`

**Note About `PGDUMP_PATH` Usage**

As I mentioned earlier `PGDUMP_PATH` can be either a Persistent Volume or Ephemeral mount. If your Postgres instance consumes only a few hundreds of megabytes ephemeral volume can be suitable for you. But keep in mind that the contetns of the ephemeral volume will be destroyed after the job finished, regardless of success or failure.
I think createing a new Persistent Volume for the migration process is better choice. This way you can keep your dump file. You can see that the scirpt always create the `pg_dumpall.sql` file, and check if it is existst, and if yes, skip the dump process. This behavior can be useful when the dump is successfull but you need to rerun the load process, for some reason. Of course feel free to modify the script according to your needs.

#### Create ConfigMap

You will see in the next section that the Job using Configmap as source of the script. So first we need to create this CM.

Save the script to `/tmp/pg_dump.sh`, and run:

```bash
kubectl -n postgres create cm pg-dump-script --from-file=pg_dump.sh=/tmp/pg_dump.sh
```

!!! note
    You can use other name for the cm and script, but if you do this, don't forget modify the Job as well.


### Kubernetes Job

```yaml
apiVersion: batch/v1
kind: Job
metadata:
  name: pg-update
spec:
  template:
    spec:
      restartPolicy: Never
      backoffLimit: 0
      initContainers:
        - name: prepare-script
          image: busybox
          command:
            - /bin/sh
            - -c
          args: 
            - |
              echo "Copy pg_dump.sh From CM to Ephemeral Storage And Change Permission"
              cp /tmp/pg_dump.sh /ephemeral/pg_dump.sh
              chmod +x /ephemeral/pg_dump.sh
              echo "Done"
          volumeMounts:
            - name: script-cm
              mountPath: /tmp/pg_dump.sh
              subPath: pg_dump.sh
            - name: ephemeral
              mountPath: /ephemeral
        - name: pgdump
          image: postgres:12
          command: ["/ephemeral/pg_dump.sh"]
          args:
            - dump
          env:
            - name: TZ
              value: Europe/Budapest
            - name: PGDUMP_PATH
              value: /pg-migrate
            - name: PG_USER
              value: admin
            - name: PG_PASS
              value: siXddddddMuhWS0PSXfa
            - name: PG_HOST
              value: postgres.postgres.svc.cluster.local
          volumeMounts:
            - name: ephemeral
              mountPath: /ephemeral
            - name: pg-migrate
              mountPath: /pg-migrate
      containers:
        - name: new-db
          image: postgres:14
          volumeMounts:
            - name: ephemeral
              mountPath: /ephemeral
            - name: pg-migrate
              mountPath: /pg-migrate              
          command: ["/ephemeral/pg_dump.sh"]
          args:
            - load
          env:
            - name: TZ
              value: Europe/Budapest
            - name: PGDUMP_PATH
              value: /pg-migrate
            - name: PG_PASS
              valueFrom:
                secretKeyRef:
                  name: postgres
                  key: admin-pass
            - name: NEW_PG_USER
              value: pg-14-admin
            - name: NEW_PG_HOST
              value: postgres-v14.postgres.svc.cluster.local
      volumes:
        - name: ephemeral
          emptyDir: {}   
        - name: script-cm
          configMap:
            name: pg-dump-script
            items:
              - key: pg_dump.sh
                path: pg_dump.sh
        - name: pg-migrate
          persistentVolumeClaim:
            claimName: pgdata-migrate
```

!!! danger "READ IT CAREFULLY"
    **ALWAYS DOUBLE CHECK `PG_HOST` AND `NEW_PG_HOST` VARIABLES!!! MAYBE THIS IS THE ONLY MISTAKE WITH WHICH YOU CAN DESTROY YOUR LIVE DATABASE!**
    To avoid overwriting the database you may want to create and use a readonly user.

!!! tip
    If the import process is failed for some reason, the easiest way to start over, is "reset" the new database:
    * Scale the deployment to 0
    * Delete the PVC
    * Recreate the PVC
    * Scale the deployment to 1

#### Containers

* `prepare-script` initContainer

The purpose of this container to prepare the shell script for running: copy to ephemeral volume and set executable permission.
This step is not necessary if you mount the CM with `defaultMode 0555` option. 

* `pgdump` initContainer

You have to modify the `image` to match your old postgres version.
This will run the script with "dump" parameter:

```yaml
          command: ["/ephemeral/pg_dump.sh"]
          args:
            - dump
```

* `new-db` container

You have to modify the `image` to match your new postgres version.
And will run the script with "load" parameter:

```yaml
          command: ["/ephemeral/pg_dump.sh"]
          args:
            - load
```

#### Volumes

* name: ephemeral

Out of the box my soultion use this volume only for store the bash script, but you can use it to store the dump file as well.

* name: script-cm

The Configmap itself which contains the bash script.

* name: pg-migrate

I use this PersistentVolume to store the dump file. 

!!! info
    You can vary the ephemeral and pvc, but you need at least one of them. 

I think the Job is pretty straighforward, but you need to be extra careful to match all paths and volumes across the containers. 


#### Why You Should Not Use The Same Username?

First of all, you must know your environment. 
In my case the old Postgres is relatively old (v12), and uses md5 hashing to store the password.

Get into the old database, and check config:

```bash linenums="1" hl_lines="10"
root@host:~# kubectl -n postgres exec -it postgres-795d9f59db-gl8rg -- /bin/bash
root@postgres-795d9f59db-gl8rg:/# cd /var/lib/postgresql/data/pgdata/
root@postgres-795d9f59db-gl8rg:/var/lib/postgresql/data/pgdata# cat pg_hba.conf  | grep -v \# | grep -v ^$
local   all             all                                     trust
host    all             all             127.0.0.1/32            trust
host    all             all             ::1/128                 trust
local   replication     all                                     trust
host    replication     all             127.0.0.1/32            trust
host    replication     all             ::1/128                 trust
host all all all md5
```

Do the same on the database:

```bash linenums="1" hl_lines="10"
root@vps11:~# kubectl -n postgres exec -it postgres-v14-6659c6f47c-4jpzs -- /bin/bash
root@postgres-v14-6659c6f47c-4jpzs:/# cd /var/lib/postgresql/data/pgdata/
root@postgres-v14-6659c6f47c-4jpzs:/var/lib/postgresql/data/pgdata# cat pg_hba.conf  | grep -v \# | grep -v ^$
local   all             all                                     trust
host    all             all             127.0.0.1/32            trust
host    all             all             ::1/128                 trust
local   replication     all                                     trust
host    replication     all             127.0.0.1/32            trust
host    replication     all             ::1/128                 trust
host all all all scram-sha-256
```

Note the difference in the last line!
If you are in the same situation I pretty sure your import process will fail, thats why you should you different admin usernames.

Unfortunately I faild to find a soultion for in-place convert passwords from md5 to scram-sha-256. As I see you have two options:

* Modify the `pg_hba.conf` to accept old `md5` passwords (at least for already existing users.) 
* Alter all user's password. Example:
    - `ALTER USER admin WITH PASSWORD 'sdfgdfgdfgd';`
    - I think this is the preffered way, because this will be an issue on every further updates, and because of security reasons.

Example of changeing password:

```bash
root@host:~# kubectl -n postgres exec -it postgres-v14-6659c6f47c-4jpzs -- /bin/bash
root@postgres-v14-6659c6f47c-4jpzs:/# psql -U admin
psql (14.7 (Debian 14.7-1.pgdg110+1))
Type "help" for help.

admin=# ALTER USER admin WITH PASSWORD 'siXtEKffdduhWS0PSXfa';
ALTER ROLE
admin=#
\q
root@postgres-v14-6659c6f47c-4jpzs:/#
exit
```

## After The Upgrade

You can configure all your apps to use the new database host, or modify the selector of the old `Service`. 

## Conclusion

I don't think this is the best solution ever, but worked in my case.  Although this method should not hurt the old database, please use the `job` with extra care. 

