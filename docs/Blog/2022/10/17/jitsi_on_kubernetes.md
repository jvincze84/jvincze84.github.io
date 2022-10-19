# How To Install Jitsi On Kubernetes

## Preface

Jitsi can be installed several way, maybe the easiest way is using docker-compose.

Link: [https://jitsi.github.io/handbook/docs/devops-guide/devops-guide-docker/](https://jitsi.github.io/handbook/docs/devops-guide/devops-guide-docker/)

But if you have a Kubernetes cluster you may want to install Jitsi on you cluster. 

I found another article about thist topic, but it is a little different from my solution: [https://sesamedisk.com/video-conferencing-with-jitsi-on-k8s/](https://sesamedisk.com/video-conferencing-with-jitsi-on-k8s/)
The most notifable different that I use only one deployment for all component (web, prosody, jicofo and jvb). (One pod, multiple container.) However this way make almost impossible to scale your jitsi instance, but far enough for minimal deployment. Running multiple instance of Jitsi is not in my scope at this time. 
Unfortunately the Official Jitsi documentation does not say too much about scaling: [https://jitsi.github.io/handbook/docs/devops-guide/devops-guide-manual](https://jitsi.github.io/handbook/docs/devops-guide/devops-guide-manual) 

Kubernetes sclaing article: [https://blog.mi.hdm-stuttgart.de/index.php/2021/03/11/how-to-scale-jitsi-meet/](https://blog.mi.hdm-stuttgart.de/index.php/2021/03/11/how-to-scale-jitsi-meet/)
I have never tried to scale jitsi, maybe later i give it a try.

I don't want to write a lot of unnecessary lines here, so let's see how I deployed Jitsi on my K8S cluster.

## Configmap

Create a config maps which contains all the necessary environment variables.

```yaml
kind: ConfigMap
apiVersion: v1
metadata:
  name: jitsi-envs
  namespace: matrix
data:
  ETHERPAD_DEFAULT_PAD_TEXT: '"Welcome to Web Chat!\n\n"'
  ETHERPAD_SKIN_NAME: colibris
  ETHERPAD_SKIN_VARIANTS: '"super-light-toolbar super-light-editor light-background full-width-editor"'
  ETHERPAD_TITLE: Video Chat
  HTTPS_PORT: '443'
  HTTP_PORT: '80'
  JIBRI_RECORDER_PASSWORD: 57969777b35e6040791212b1aa26ff36
  JIBRI_XMPP_PASSWORD: 38f7da1f75c78e27f7cf93fe772a79c1
  JICOFO_AUTH_PASSWORD: fcd121582ec8322f5fc262a398fe7c8e
  JIGASI_XMPP_PASSWORD: b984fb9c2509d4831419a1fa7e477dec
  JVB_ADVERTISE_IPS: 23.82.62.51,138.42.98.6
  JVB_AUTH_PASSWORD: 6ea25fdc9611b6df32a0dfac49fa773f
  JVB_PORT: '30300'
  PUBLIC_URL: https://jitsi.customdomain.com
  TURN_CREDENTIALS: jr00QMMfECtfMCwKewZTPh23sdf3m3DeusUPkgQfFRTzUg1VC6KsBIiqiFFeP
  TURN_HOST: 23.88.60.51
  TURN_PORT: '3478'
  TZ: Europe/Budapest
  XMPP_BOSH_URL_BASE: http://127.0.0.1:5280
  XMPP_SERVER: localhost
```

* **JVB_ADVERTISE_IPS & JVB_PORT**

These options are really important. I have two kubernetes nodes with public, static ip addresses, and I'm using NodePort Service to access JVB service. That's why you can see two IP addresses in my example configuration. By default `JVB_PORT` is 10000, but NodePorts are between 30000 and 32767 by default, so you need to use port from this range. (And you should open this port on your firewall)

* **PUBLIC_URL**

This is the public URL of your Jitsi instance. This domain will be set in the Kubernetes Ingress.

* **TURN_CREDENTIALS & TURN_HOST & TURN_PORT**

These setting are for devices behind NAT. If you have your own TURN server, configure these values accordingly. If you don't have TURN server you may find a free one by a little Googling. At the and of this post I will share you an example coturn configuration.

* **XMPP_BOSH_URL_BASE & XMPP_SERVER**

Since we will have only one POD and multiple containers inside it, we should use localhost to reach another component.
If you have multiple containers inside a POD, you have to use localhost to reach one container from another. So contained inside the POD cannot bind the same port.

Link: [https://kubernetes.io/docs/tasks/access-application-cluster/communicate-containers-same-pod-shared-volume/](https://kubernetes.io/docs/tasks/access-application-cluster/communicate-containers-same-pod-shared-volume/)

If you experiencing connection timeout error messages, check the nginx configuration in the web container. 

```
# BOSH
location = /http-bind {
    proxy_set_header X-Forwarded-For $remote_addr;
    proxy_set_header Host meet.jitsi;

    proxy_pass http://127.0.0.1:5280/http-bind?prefix=$prefix&$args;
}


# xmpp websockets
location = /xmpp-websocket {
    tcp_nodelay on;

    proxy_http_version 1.1;
    proxy_set_header Connection $connection_upgrade;
    proxy_set_header Upgrade $http_upgrade;
    proxy_set_header Host meet.jitsi;
    proxy_set_header X-Forwarded-For $remote_addr;

    proxy_pass http://127.0.0.1:5280/xmpp-websocket?prefix=$prefix&$args;
}
```

Don't modify the nginx confuguration by hand, insted double check the XMPP_BOSH_URL_BASE & XMPP_SERVER system environments.


## Persistent Volume

The Jitsi Deployment needs a persistent volume. 

```yaml
kind: PersistentVolumeClaim
apiVersion: v1
metadata:
  name: jitsi-conf
  namespace: matrix
spec:
  accessModes:
    - ReadWriteOnce
  resources:
    requests:
      storage: 1Gi
  storageClassName: # <-- Your storageclass name goes here
  volumeMode: Filesystem
```

!!! note
    
    We can use only one persistent volume for all component, since all containers are running in the same pod. Otherwise you need a volume that supports ReadWriteMany access mode, or shedule all pods to the same node, or have separate PVC for all component.

## Deployment

```title="Jitsi Deployment"
--8<-- ".files/Deplyoment-jitsi.yaml"
```


**Common parts:**

* System environments

All containers use the same ConfigMap as System Environments. It should not cause any problem because there is no overlap across the containers. (There is no container using tha same property, but different value)

```yaml
          envFrom:
            - configMapRef:
                name: jitsi-envs
```


* Peristent Volume

We use the same PersistentVolume, but different Subpath:

  * Web
  
```yaml
          volumeMounts:
            - name: jitsi-conf
              mountPath: /config
              subPath: web-config
            - name: jitsi-conf
              mountPath: /var/spool/cron/crontabs
              subPath: crontabs
            - name: jitsi-conf
              mountPath: /usr/share/jitsi-meet/transcripts
              subPath: transcripts
```

  * Prosody
  
```yaml
          volumeMounts:
            - name: jitsi-conf
              mountPath: /config
              subPath: prosody-config
            - name: jitsi-conf
              mountPath: /prosody-plugins-custom
              subPath: prosody-plugins-custom
```

  * Jicofo
  
```yaml
          volumeMounts:
            - name: jitsi-conf
              mountPath: /config
              subPath: jicofo-config
```

  * Jvb

```yaml
          volumeMounts:
            - name: jitsi-conf
              mountPath: /config
              subPath: jvb-config
```              

## Services

### Web

```yaml
apiVersion: v1
kind: Service
metadata:
  name: jitsi-web
  namespace: matrix
spec:
  internalTrafficPolicy: Cluster
  ipFamilies:
  - IPv4
  ipFamilyPolicy: SingleStack
  ports:
  - name: http
    port: 80
    protocol: TCP
    targetPort: 80
  - name: https
    port: 443
    protocol: TCP
    targetPort: 443
  selector:
    k8s-app: jitsi
  sessionAffinity: None
  type: ClusterIP

```

### JVB (NodePort)

```yaml
apiVersion: v1
kind: Service
metadata:
  name: jitsi-jvb
  namespace: matrix
spec:
  externalTrafficPolicy: Cluster
  internalTrafficPolicy: Cluster
  ipFamilyPolicy: SingleStack
  ports:
  - nodePort: 30300
    port: 30300
    protocol: UDP
    targetPort: 30300
  selector:
    k8s-app: jitsi
  sessionAffinity: None
  type: NodePort
```


## Ingress

```yaml
kind: Ingress
apiVersion: networking.k8s.io/v1
metadata:
  name: jitsi-web
  namespace: matrix
  annotations:
    cert-manager.io/cluster-issuer: letsencrypt-prod
    kubernetes.io/ingress.class: nginx
    nginx.ingress.kubernetes.io/proxy-connect-timeout: '3600'
    nginx.ingress.kubernetes.io/proxy-read-timeout: '3600'
    nginx.ingress.kubernetes.io/proxy-send-timeout: '3600'
    nginx.ingress.kubernetes.io/server-snippet: |
      location / {
      proxy_set_header Upgrade $http_upgrade;
      proxy_http_version 1.1;
      proxy_set_header X-Forwarded-Host $http_host;
      proxy_set_header X-Forwarded-Proto $scheme;
      proxy_set_header X-Forwarded-For $remote_addr;
      proxy_set_header Host $host;
      proxy_set_header Connection "upgrade";
      proxy_cache_bypass $http_upgrade;
      }
spec:
  tls:
    - hosts:
        - jitsi.customdomain.com
      secretName: jitsi-https
  rules:
    - host: jitsi.customdomain.com
      http:
        paths:
          - pathType: ImplementationSpecific
            backend:
              service:
                name: jitsi-web
                port:
                  name: http
```      

!!! note

    The ingress should work without the `nginx.ingress.kubernetes.io/server-snippet` annotation, but I leave it here for example.

## Matrix Element Integration

If you have Synapse Matrix server, you can use your newly create Jitsi deployment for conference calls, if you are using Elemnt clients.

Link: [https://element.io/get-started](https://element.io/get-started)

You need to add the following annotations to the Ingress of the Matrix server:

```yaml
    nginx.ingress.kubernetes.io/server-snippet: |
      location /.well-known/matrix/client {
        return 200 '{"m.homeserver":{"base_url":"https://matrix.customdomain.com"},"im.vector.riot.jitsi":{"preferredDomain": "jitsi.customdomain.com"}}';
        default_type application/json;
        add_header Access-Control-Allow-Origin *;
      }
```

This server-snippet will instruct the Element client (web/ios/android) to use your Jitsi URL insted of the default one. 
Android and IOS clients may required to reinstall.

Related docs:

* [https://github.com/vector-im/element-web/blob/develop/docs/jitsi.md](https://github.com/vector-im/element-web/blob/develop/docs/jitsi.md)
* [https://github.com/vector-im/element-android/issues/7230](https://github.com/vector-im/element-android/issues/7230)

## [Bonus] - Coturn Configuration

### Install

```bash
apt install coturn
mkdir /var/log/turn
chown -R turnserver:turnserver /var/log/turn
```


### /etc/turnserver.conf

```plain
listening-ip=123.118.161.21
use-auth-secret
static-auth-secret=jr00QMMfECtfMCwKewZTPh23sdf3m3DeusUPkgQfFRTzUg1VC6KsBIiqiFFeP
total-quota=1200
no-tls
no-dtls
no-tcp-relay
log-file=/var/log/turn/turn.log
new-log-timestamp
no-multicast-peers
denied-peer-ip=10.0.0.0-10.255.255.255
denied-peer-ip=0.0.0.0-0.255.255.255
denied-peer-ip=100.64.0.0-100.127.255.255
denied-peer-ip=127.0.0.0-127.255.255.255
denied-peer-ip=169.254.0.0-169.254.255.255
denied-peer-ip=192.0.0.0-192.0.0.255
denied-peer-ip=192.0.2.0-192.0.2.255
denied-peer-ip=192.88.99.0-192.88.99.255
denied-peer-ip=198.18.0.0-198.19.255.255
denied-peer-ip=198.51.100.0-198.51.100.255
denied-peer-ip=203.0.113.0-203.0.113.255
denied-peer-ip=240.0.0.0-255.255.255.255
```



