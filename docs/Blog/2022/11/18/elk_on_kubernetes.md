# (UNFINISHED) Deploy Elasticsearch Cluster & Kibaba On Kubernetes

## Preface

Nowadays maybe the most advanced and widly used log management and analizis system is the ELK stack. I have to  mention Graylog and Grafana Loki which are also great and advanced tools for montioring your environments and collect log files from them.

There is another enterprise ready and feature rich log management system which based on Elasticsearch and Kibana: OpenSearch. If you are looking for a free alternaive to Elasticsearch you may want to give OpenSearch a try. I'm going to post about OpenSearch as well, but at this time I want to show you a method to install Elasticsearch & Kibana on your Kubernetes cluster.

## Requirements

* A working Kubernetes cluster. The current version of my cluster: v1.24.4
* Kubectl cli tool
* Installed and ready to use Persistent Volume solution (Example Longhorn, OpenEBS, rook, etc)
* At least 2GB of free memory for Elasticsearch instances.

### Set `vm.max_map_count` To At Least 262144

This is a strict requirements of Elasticsearch.
You have to set this value on each node you are planning to run Elasticsearch. You can select the nodes where to run Elasticsearch with nodeselectors and node labels.

Add the following line to `/etc/sysctl.conf` file:

```plain
vm.max_map_count=262144
```

To apply the setting on a live system, run:

```bash
sysctl -w vm.max_map_count=262144
```


## Prepareing

The first and most important thing is to choose a names of your Elasticsearch cluster and Instances. 
We will deploy Elasticsearch cluster as StatefulSet, so the name of instances will be sequential.

### Create Certificates

* Create a directory for your certificates:

```bash
mkdir /tmp/es-certs
chown 1000:1000 /tmp/es-certs
```

* Create the `instances.yml` file.

```bash linenums="1"
cat <<EOF>/tmp/es-certs/instances.yml
instances:
- name: elastic-0
  dns:
    - elastic-0.es-cluster
    - localhost
    - es-cluster
  ip:
    - 127.0.0.1
- name: elastic-1
  dns:
    - elastic-1.es-cluster
    - localhost
    - es-cluster
  ip:
    - 127.0.0.1
- name: elastic-2
  dns:
    - elastic-3.es-cluster
    - localhost
    - es-cluster
  ip:
    - 127.0.0.1
EOF
```

!!! Important
    
    The `- name: elastic-0` is must mach the StatefulSet name plus the sequence number appended by dash.
    The DNS (`- name: elastic-1 ... elastic-n`) name must mach the name of StatfulSet: `metadata.name: elastic` and the headless service name. [STATFULSET_NAME]-[NUMBER].[STATEFUL_SERVICE_NAME]
    The third DNS record is the neme of the Kubernetes (headless) Service. This will be used for Kubernetes internal use, for example for Kibana.
    

* Generate the certificates

Run a temporary contianer to work in it:

```bash
docker run -v /tmp/es-certs:/usr/share/elasticsearch/config/certs -it --rm docker.elastic.co/elasticsearch/elasticsearch:8.5.1 /bin/sh
```

Run the following commands inside the container:


```bash linenums="1"
# Generate CA certificates
bin/elasticsearch-certutil ca --silent --pem -out config/certs/ca.zip
unzip config/certs/ca.zip -d config/certs

# Generate Elasticsearch Certificates
bin/elasticsearch-certutil cert --silent --pem -out config/certs/certs.zip --in config/certs/instances.yml --ca-cert config/certs/ca/ca.crt --ca-key config/certs/ca/ca.key
unzip config/certs/certs.zip -d config/certs
```

Exit from the container.

After the certificate generation your folder and file should look like that:

```plain
/tmp/es-certs/
/tmp/es-certs/certs.zip
/tmp/es-certs/elastic-2
/tmp/es-certs/elastic-2/elastic-2.key
/tmp/es-certs/elastic-2/elastic-2.crt
/tmp/es-certs/ca.zip
/tmp/es-certs/elastic-0
/tmp/es-certs/elastic-0/elastic-0.key
/tmp/es-certs/elastic-0/elastic-0.crt
/tmp/es-certs/instances.yml
/tmp/es-certs/elastic-1
/tmp/es-certs/elastic-1/elastic-1.crt
/tmp/es-certs/elastic-1/elastic-1.key
/tmp/es-certs/ca
/tmp/es-certs/ca/ca.key
/tmp/es-certs/ca/ca.crt
```

* Move all files to the `/tmp/es-certs/`

```bash linenums="1"
cd /tmp/es-certs
find . -mindepth 2 -maxdepth 2 -type f -ls -exec mv "{}" . \;
find . -mindepth 1 -maxdepth 1 -type d -ls -exec rmdir "{}" \;
```

Now your folder should be similar to this:

```plain linenums="1"
total 56
drwxr-xr-x  2 vinyo vinyo 4096 Nov 18 14:07 .
drwxrwxrwt 25 root  root  4096 Nov 18 14:08 ..
-rw-rw-r--  1 vinyo root  1200 Nov 18 14:02 ca.crt
-rw-rw-r--  1 vinyo root  1679 Nov 18 14:02 ca.key
-rw-------  1 vinyo root  2519 Nov 18 14:02 ca.zip
-rw-------  1 vinyo root  7851 Nov 18 14:04 certs.zip
-rw-rw-r--  1 vinyo root  1220 Nov 18 14:04 elastic-0.crt
-rw-rw-r--  1 vinyo root  1679 Nov 18 14:04 elastic-0.key
-rw-rw-r--  1 vinyo root  1220 Nov 18 14:04 elastic-1.crt
-rw-rw-r--  1 vinyo root  1679 Nov 18 14:04 elastic-1.key
-rw-rw-r--  1 vinyo root  1220 Nov 18 14:04 elastic-2.crt
-rw-rw-r--  1 vinyo root  1675 Nov 18 14:04 elastic-2.key
-rw-r--r--  1 vinyo vinyo  299 Nov 18 14:04 instances.yml
```

### Create Kubernetes Secrets & Namespace

* Certificates

```bash linenums="1"
# Create the Namespace
kubectl create ns logging

# Delete the secret if it is already exists:
# kubectl -n logging delete secret es-certs
kubectl -n logging create secret generic es-certs --from-file=/tmp/es-certs
```

* Elastic Password

```bash
kubectl -n logging create secret generic elastic-password --from-literal=elastic=Admin1234
```
You shoud replace `Admin1234` (of course).

You will use this username/password to login to Kiabana.


## ElasticSearch StatefulSet & Service

### StatefulSet 

```yaml linenums="1" title="statefulset.yaml"
--8<-- "files/es-statefulset.yaml"
```

### Headless Service

```yaml linenums="1"
kind: Service
apiVersion: v1
metadata:
  name: es-cluster
  namespace: logging
spec:
  ports:
    - name: rest
      protocol: TCP
      port: 9200
      targetPort: 9200
    - name: inter-node
      protocol: TCP
      port: 9300
      targetPort: 9300
  selector:
    k8s-app: elastic
  clusterIP: None
  type: ClusterIP
  sessionAffinity: None
  ipFamilies:
    - IPv4
  ipFamilyPolicy: SingleStack
  internalTrafficPolicy: Cluster
```


### Important Parts Of The Manifests

#### PersistentVolumeClaim

```yaml
  volumeClaimTemplates:
    - kind: PersistentVolumeClaim
      apiVersion: v1
      metadata:
        name: es-data
        creationTimestamp: null
      spec:
        accessModes:
          - ReadWriteOnce
        resources:
          requests:
            storage: 1Gi
        storageClassName: local-hostpath
        volumeMode: Filesystem
```

I really recommend to use some kind of hostpath volume, for example OpenEBS, since Elasticsearch operations can be IO heavy. If you decide to use OpenEBS hostpath all the POD will be scheduled to the same host all the time.


#### Environment Variables

```yaml
            - name: NODENAME
              valueFrom:
                fieldRef:
                  apiVersion: v1
                  fieldPath: metadata.name
```

This variable is not used direrctly by the pod itself. It is just for this manifest. The value is the name of the StatefulSet.
It's purpose to use in other variables. (`metadata.name` could not be nested)

---

```yaml
            - name: SERVICENAME
              value: es-cluster
```

This must mach with the `serviceName: es-cluster` in this manifest, and the neme of the headless Service.

---

```yaml
            - name: node.name
              value: $(NODENAME).$(SERVICENAME)
```

Each Elasticsearch instance created by the StatefulSet get the node name like elastic-0.es-clsuster, elastic-1.es-clsuster, etc.
This is really important for the next parameters:

--- 

```yaml
            - name: discovery.seed_hosts
              value: elastic-0.es-cluster,elastic-1.es-cluster,elastic-3.es-cluster
            - name: cluster.initial_master_nodes
              value: elastic-0.es-cluster,elastic-1.es-cluster,elastic-3.es-cluster
```

!!! important

    Now you can see that how important to decide the names of each component. 
    As I wrote above the DNS names in the `instances.yml` must mach these names.
    `elastic-0.es-cluster` means the [POD_NAME].[HEADLESS_SERVICE:metadata.name]. In our case the pod name is always the name of the StatefulSet + sequence number (because of the StatefulSet). This way the `elastic-[n].es-cluster` always points to the actual IP address of the pods create by the StatefulSet. 

!!! note

    You can increase or decrease the number of Elasticsearch instances, but keep in mind to modify these values:
    
    * Certificate generation: Modify the `instances.yml`, and regenerate the certificates, but only `certs.zip` not the CA! Don't forget to update the Kubernetes secret.
    * StatefulSet: 
        * `spec.replicas` 
        * Variables: `discovery.seed_hosts` & `cluster.initial_master_nodes` According to the `instances.yml` file.
    
---

```yaml
            - name: xpack.security.http.ssl.key
              value: certs/$(NODENAME).key
            - name: xpack.security.http.ssl.certificate
              value: certs/$(NODENAME).crt
```

Every node has its own certificate. That's why we need the `$(NODENAME)` variable. This way the `certs/$(NODENAME).crt` will be `certs/elastic-0.crt` for the first pod and `certs/elastic-1.crt` for the second one, etc.

!!! note

    You can create a single certificate which holds all of the DNS record for all nodes, but it is antipattern and not recommended for security reason.

---

```yaml
            - name: ELASTIC_PASSWORD
              valueFrom:
                secretKeyRef:
                  name: elastic-password
                  key: elastic
```

This is the password for the built-in `elastic` superuser.


* Volumes

```yaml
          volumeMounts:
            ...
            ...
            - name: es-certs
              readOnly: true
              mountPath: /usr/share/elasticsearch/config/certs
```              

Here we mount the previously created Kubernetes secret which contains all of the necessary certificates.


## Checks

Get into the `elastic-0` pod:

```bash
kubectl -n logging exec -it elastic-0 -- /bin/sh
```

And run the following commands:

```bash
curl -i -k  -XGET https://localhost:9200/_cat/nodes?v -u 'elastic:Admin1234'
```

```plain title="ouptut"
HTTP/1.1 200 OK
X-elastic-product: Elasticsearch
content-type: text/plain; charset=UTF-8
content-length: 302

ip          heap.percent ram.percent cpu load_1m load_5m load_15m node.role   master name
10.26.6.107           14          83   1    1.57    1.83     1.59 cdfhilmrstw -      elastic-0.es-cluster
10.26.4.230           37          83   2    0.58    0.76     0.62 cdfhilmrstw *      elastic-1.es-cluster
```

```bash
curl -i -k  -XGET https://localhost:9200/_cat/allocation?v -u 'elastic:Admin1234'
```

```plain title="output"
HTTP/1.1 200 OK
X-elastic-product: Elasticsearch
content-type: text/plain; charset=UTF-8
content-length: 314

shards disk.indices disk.used disk.avail disk.total disk.percent host        ip          node
     4       39.9mb    19.2gb     89.3gb    108.5gb           17 10.26.4.230 10.26.4.230 elastic-1.es-cluster
     4       39.8mb    65.8gb     50.2gb    116.1gb           56 10.26.6.107 10.26.6.107 elastic-0.es-cluster
```

!!! hint

    As you can see I have only two nodes at the moment. But everything looks fine.

## Deploy Kibana

### Prepare

First prepare the `kibana_system` built-in user password:

!!! important

    Run the following command inside one of your elastic pod!!!

```bash
curl -k -i -X POST -u "elastic:Admin1234" -H "Content-Type: application/json" https://localhost:9200/_security/user/kibana_system/_password -d "{\"password\":\"Admin123\"}" 
```

```plain title="output"
HTTP/1.1 200 OK
X-elastic-product: Elasticsearch
content-type: application/json
content-length: 2

{}
```

!!! warning

    Do not use the cli tools (/usr/share/elasticsearch/bin/elasticsearch-*) to update/reseet paswword. .
    This will create a file inside the /usr/share/elasticsearch/config directory, and after the pod restart this file will be gone.
    

!!! note

    Please note that the password (`elastic:Admin1234`) comes from the `ELASTIC_PASSWORD` environment variable (pre-created secret).


Create a Kuernetes secret:

```bash
kubectl -n logging create secret generic kibanasystem --from-literal=kibana_system=Admin123
```

### Manifest

```yaml linenums="1"
kind: Deployment
apiVersion: apps/v1
metadata:
  name: kibana
  namespace: logging
spec:
  replicas: 1
  selector:
    matchLabels:
      k8s-app: kibana
  template:
    metadata:
      name: kibana
      creationTimestamp: null
      labels:
        k8s-app: kibana
    spec:
      volumes:
        - name: es-certs
          secret:
            secretName: es-certs
            defaultMode: 420
      containers:
        - name: kibana
          image: kibana:8.5.1
          env:
            - name: ELASTICSEARCH_HOSTS
              value: https://es-cluster:9200
            - name: ELASTICSEARCH_USERNAME
              value: kibana_system
            - name: ELASTICSEARCH_PASSWORD
              valueFrom:
                secretKeyRef:
                  name: kibanasystem
                  key: kibana_system
            - name: SERVER_PUBLICBASEURL
              value: https://kibana.vincze.work
            - name: ELASTICSEARCH_SSL_CERTIFICATEAUTHORITIES
              value: config/certs/ca.crt
          resources: {}
          volumeMounts:
            - name: es-certs
              readOnly: true
              mountPath: /usr/share/kibana/config/certs
          terminationMessagePath: /dev/termination-log
          terminationMessagePolicy: File
          imagePullPolicy: IfNotPresent
          securityContext:
            privileged: false
      restartPolicy: Always
      terminationGracePeriodSeconds: 30
      dnsPolicy: ClusterFirst
      securityContext: {}
      schedulerName: default-scheduler
  strategy:
    type: Recreate
  revisionHistoryLimit: 10
  progressDeadlineSeconds: 600
```

Noticeable parts:

* Kibana use the same secret to mount the certificate as  Elasticsearch. (volumeMounts: es-certs), but different mountPath: /usr/share/kibana/config/certs
* Set `SERVER_PUBLICBASEURL` to the hostname that you will use in your ingress. If you miss this step Kibana will warn you to correct this.
* `ELASTICSEARCH_HOSTS`: This value points to the headless service. That's why we need to add `es-cluster` as DNS record in `instances.yml`.
* `ELASTICSEARCH_USERNAME`: Do NOT modify this value. Older versions of Elasticsearch used `kibana`, but it is deprecated. The username should be `kibana_system`.


### Service

```yaml linenums="1"
kind: Service
apiVersion: v1
metadata:
  name: kibana
  namespace: logging
spec:
  ports:
    - name: web
      protocol: TCP
      port: 5601
      targetPort: 5601
  selector:
    k8s-app: kibana
  type: ClusterIP
  sessionAffinity: None
  ipFamilies:
    - IPv4
  internalTrafficPolicy: Cluster
```

### Ingress

```yaml linenums="1"
kind: Ingress
apiVersion: networking.k8s.io/v1
metadata:
  name: kibana
  namespace: logging
  annotations:
    cert-manager.io/cluster-issuer: letsencrypt-prod
    kubernetes.io/ingress.class: nginx
    nginx.ingress.kubernetes.io/proxy-body-size: 100m
spec:
  tls:
    - hosts:
        - kibana.vincze.work
      secretName: kibana-https
  rules:
    - host: kibana.vincze.work
      http:
        paths:
          - pathType: ImplementationSpecific
            backend:
              service:
                name: kibana
                port:
                  name: web
```

This is only an example ingress, so modify according to your needs.

## References

* [https://www.elastic.co/guide/en/kibana/8.5/docker.html](https://www.elastic.co/guide/en/kibana/8.5/docker.html)
* [https://www.elastic.co/guide/en/elasticsearch/reference/current/docker.html](https://www.elastic.co/guide/en/elasticsearch/reference/current/docker.html)
* [https://hub.docker.com/_/elasticsearch](https://hub.docker.com/_/elasticsearch)
