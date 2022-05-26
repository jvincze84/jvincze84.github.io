#Deployments

## Debian With Infinite Loop

```yaml linenums="1"
apiVersion: apps/v1
kind: Deployment
metadata:
  labels:
    k8s-app: debian-example
  name: replace_me #(1)
  namespace: replace_me # (2)
spec:
  replicas: 1
  revisionHistoryLimit: 10
  selector:
    matchLabels:
      k8s-app: debian-example
  strategy:
    type: Recreate 
  template:
    metadata:
      labels:
        k8s-app: debian-example
      name: debian-example
    spec:
      containers:
      - args:
        - -c
        - while true; do echo "$(date +%F\ %T) - hello"; sleep 10;done
        command:
        - /bin/sh
        image: debian:latest
        imagePullPolicy: Always
        name: debian-example
        securityContext:
          privileged: false
```

1.  Name Of The Deployment
2.  Namespace name where you want to Deploy.

## Minio Deployment With hostPath

```yaml linenums="1"
apiVersion: apps/v1
kind: Deployment
metadata:
  labels:
    k8s-app: minio
  name: minio-server
  namespace: minio
spec:
  replicas: 1
  revisionHistoryLimit: 10
  selector:
    matchLabels:
      k8s-app: minio
  strategy:
    type: Recreate 
  template:
    metadata:
      labels:
        k8s-app: minio
      name: minio
    spec:
      nodeName: k8s-admin.loc
      volumes:
        - name: minio-storage
          hostPath:
            type: Directory
            path: /srv/raid5_safe/k8s_storage/minio    
      containers:
        - name: minio-server
          env:
            - name: MINIO_ROOT_USER
              value: admin
            - name: MINIO_ROOT_PASSWORD
              valueFrom:
                secretKeyRef:
                  key: adminpassword
                  name: minio-admin-user 
          image: bitnami/minio:2022.5.23
          imagePullPolicy: Always
          securityContext:
            privileged: false
          volumeMounts:
            - name: minio-storage
              mountPath: /data      
```

### Bonus - Secret

```bash
kubectl -n minio create secret generic minio-admin-user --from-literal=adminpassword=IvoTSZW8Fr4kjkdRsL36
```

### Bobus - Service & Ingress (For Web Access)

```yaml linenums="1"
apiVersion: v1
kind: Service
metadata:
  name: mini-web
  namespace: minio
spec:
  ports:
  - port: 80
    targetPort: 9000
    name: http
  selector:
     k8s-app: minio
  type: ClusterIP
```

```yaml linenums="1"
apiVersion: networking.k8s.io/v1
kind: Ingress
metadata:
  name: mini-web
  namespace: minio
spec:
  ingressClassName: nginx
  rules:
  - host: # Replace 
    http:
      paths:
      - backend:
          service:
            name: mini-web
            port:
              name: http
        pathType: ImplementationSpecific
```

### Bonus - MetalLB Service

```yaml linenums="1"
apiVersion: v1
kind: Service
metadata:
  name: minio
  namespace: minio
  annotations:
    metallb.universe.tf/address-pool: default
spec:
  ports:
  - port: 9000
    targetPort: 9000
    name: tcp-9000
  - port: 
    targetPort: 9001
    port: 9001
    name: web
  selector:
     k8s-app: minio
  type: LoadBalancer
```

