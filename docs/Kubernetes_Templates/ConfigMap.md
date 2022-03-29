# ConfigMap


## Create Config Map

First create an example property file:

```bash
cat <<EOF>/tmp/cm.txt
MYSQL_HOST=mysql.default.cluster.svc
MYSQL_PORT=3306
WEB_ADMIN=false
EXT_URL=https://external.web.local
EOF
```

```bash
kubectl -n default create configmap app-props --from-env-file=/tmp/cm.txt
```

How is it look like?

```yaml linenums="1" hl_lines="3-6"
apiVersion: v1
data:
  EXT_URL: https://external.web.local
  MYSQL_HOST: mysql.default.cluster.svc
  MYSQL_PORT: "3306"
  WEB_ADMIN: "false"
kind: ConfigMap
metadata:
  creationTimestamp: "2022-03-29T11:59:18Z"
  name: app-props
  namespace: default
  resourceVersion: "130190991"
  uid: 4170dcea-dc38-43de-aaaa-28b1fd958ed9
```

## Use As System Environments

### Entire Configmap

#### Patch File

```yaml linenums="1"
cat <<EOF>/tmp/patch.yaml
spec:
  template:
    spec:
      containers:
        - name: debian-example
          envFrom:
            - configMapRef:
                name: app-props
EOF
```

#### Apply

```bash
kubectl -n default patch deployment debian-test --patch-file /tmp/patch.yaml
```

### Specify Single Env

You can use only the specific key, value pair.

#### Patch File

```yaml linenums="1"
cat <<EOF>/tmp/patch.yaml
spec:
  template:
    spec:
      containers:
        - name: debian-example
          env:
            - name: EXT_URL_SINGLE
              valueFrom:
                configMapKeyRef:
                  name: app-props
                  key: EXT_URL
EOF
```


#### Apply

```bash
kubectl -n default patch deployment debian-test --patch-file /tmp/patch.yaml
```

## Use Case: Apache Config

### Get The Necessary File

```bash
docker run --rm httpd:latest cat /usr/local/apache2/conf/httpd.conf >httpd-custom.conf
docker run --rm httpd:latest cat /usr/local/apache2/conf/mime.types >mime-custom.types
```

### Create Configmap From These Files

```bash
kubectl -n default create configmap apache-custom \
--from-file=httpd-custom.conf \
--from-file=mime-custom.types
```

### Attach These Files To The Container

#### Patch File

```yaml linenums="1" hl_lines="10-13 18-23"
cat <<EOF>/tmp/patch.yaml
spec:
  template:
    spec:
      volumes:
        - name: apache-custom-config
          configMap:
            name: apache-custom
            items:
              - key: httpd-custom.conf
                path: httpd.conf
              - key: mime-custom.types
                path: mime.types
            defaultMode: 420    	
      containers:
        - name: httpd
          volumeMounts:
            - name: apache-custom-config
              mountPath: /usr/local/apache2/conf/httpd.conf
              subPath: httpd.conf          	
            - name: apache-custom-config
              mountPath: /usr/local/apache2/conf/mime.types 
              subPath: mime.types         	              
EOF
```

#### Create Sample Deployment

```bash
kubectl -n default create deployment httpd-test --image=httpd:latest --replicas=1
```

#### Apply The Patch File

```bash
kubectl -n default patch deployment httpd-test --patch-file /tmp/patch.yaml
```

!!! caution
    A container using a ConfigMap as a subPath volume will not receive ConfigMap updates.


## Mount Confgimap Into Directory


### Patch File

```yaml linenums="1" hl_lines="8 13 14"
cat <<EOF>/tmp/patch.yaml
spec:
  template:
    spec:
      volumes:
        - name: apache-custom-config
          configMap:
            name: apache-custom
            defaultMode: 420    	
      containers:
        - name: httpd
          volumeMounts:
            - name: apache-custom-config
              mountPath: /sampe-config
EOF
```

### Apply The Patch File

```bash
kubectl -n default patch deployment httpd-test --patch-file /tmp/patch.yaml
```

!!! warning
    This will replace everything inside the original `/sampe-config` directory.
    
