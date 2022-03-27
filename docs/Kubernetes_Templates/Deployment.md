# Deployments

## Debian With Infinite Loop

``` yaml linenums="1"
apiVersion: apps/v1
kind: Deployment
metadata:
  labels:
    k8s-app: debian-example
  name: replace_me
  namespace: replace_me
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
