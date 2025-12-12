---
title: How To Use Mkdocs + Meterial In Kubernetes
date: 2022-10-20
---

# How To Use Mkdocs + Meterial In Kubernetes

## Preface

In this guide I show you how I use mkdocs in my Kubernetes cluster.   
There are uncountable ways to do something similar, but I think this post can be useful for you.  
The main ascpect of my solution is to build the documentation in an init container, and serve the page with nginx. This way the only thing you have to do is rollout the deployment after new version of your mkdocs is released (pushed to your repository).


<!-- more -->


## Required Containers

### Git Downloader

This container aims to download the git repository to the ephemeral storage. If you don't want to use my repository you can build your own image.

#### Dockerfile

```dockerfile title="quay.io/jvincze84/mkdocs-init:v0.7"
FROM alpine:latest
RUN apk add \
bash \
git
ADD run.sh /
CMD ["/run.sh"]
```

As you can see It's a really simple Dockerfile based on the latest alpine image.

#### Shell Scirpt

```bash title="run.sh" linenums="1"
#!/bin/bash
GIT_URL="${GIT_URL:-gogs.vincze.work}"
GIT_REPO="${GIT_REPO:-jvincze/priv-knowledge-mkdocs}"
GIT_USER="${GIT_USER:-jvincze}"
GIT_PASS="${GIT_PASS:-admin}"
GIT_AUTH="${GIT_AUTH:-true}"
USER_UID="${USER_UID:-1000}"

STORAGE="${STORAGE:-/storage}"

echo "=== DEBUG & Avaiable Variables==="
echo "GIT_URL: $GIT_URL"
echo "GIT_REPO: $GIT_REPO"
echo "GIT_USER: $GIT_USER"
echo "GIT_AUTH: $GIT_AUTH"
echo "GIT_PASS: ********"
echo "USER_UID: $USER_UID"

[ ! -d $STORAGE ] && mkdir -p $STORAGE


cd $STORAGE

if [ $GIT_AUTH == "true" ]
then
  git clone https://$GIT_USER:$GIT_PASS@$GIT_URL/$GIT_REPO .
else
  git clone https://$GIT_URL/$GIT_REPO .
fi


echo
echo "--- Setting permissions"
chown -R $USER_UID:$USER_UID $STORAGE

ls -la $STORAGE
echo "Container Done"
```

!!! warning

    You should not modify the `$STORAGE` environment  variable unless you change the Deployment as well. 

!!! important

    When you create the `run.sh` file, don't forget to add the executable bit. (`chmod +x run.sh`)

### Mkdocs Builder

This container will build the site for the nginx web server.

#### Dockerfile

```dockerfile linenums="1" title="quay.io/jvincze84/mkdocs-build:2.14"
FROM python:3-alpine3.14


ARG USER=1000

RUN adduser -h /usr/src/mkdocs -D -u $USER mkdocs \
&& apk add bash \
&& apk add git 

ENV PATH="${PATH}:/usr/src/mkdocs/.local/bin"

USER mkdocs
RUN mkdir -p /usr/src/mkdocs/build
WORKDIR /usr/src/mkdocs/build

RUN pip install --upgrade pip

RUN pip install pymdown-extensions \
&& pip install mkdocs \
&& pip install mkdocs-material \
&& pip install mkdocs-rtd-dropdown \
&& pip install mkdocs-git-revision-date-plugin \
&& pip install mkdocs-git-revision-date-localized-plugin \
&& pip install mkdocs-blog-plugin \
&& pip3 install mkdocs-blogging-plugin

# The following line is bcause of mkdocs build error: Unable to read git logs of
RUN git config --global --add safe.directory '*'

ENTRYPOINT ["/usr/src/mkdocs/.local/bin/mkdocs"]

LABEL mkdocs.image="3-alpine3.14"
```


!!! warning

    The `USER` argument must match with the `USER_UID` in the previous step. (Git Downloader / Shell Scirpt)


You can add extra extension(s) by modifying  the `pip install` section, any other parts of the Dockerfile should not be modified.


## Deployment

Let's see the Depolyment yaml file.

```yaml linenums="1"
kind: Deployment
apiVersion: apps/v1
metadata:
  name: read-the-docs
  namespace: mkdocs
spec:
  replicas: 1
  selector:
    matchLabels:
      k8s-app: mkdocs-priv
  template:
    metadata:
      name: mkdocs-priv
      creationTimestamp: null
      labels:
        k8s-app: mkdocs-priv
    spec:
      volumes:
        - name: shared
          emptyDir: {}
      initContainers:
        - name: git
          image: quay.io/jvincze84/mkdocs-init:v0.7
          env:
            - name: GIT_AUTH
              value: 'false'  
            - name: GIT_REPO
              value: jvincze84/jvincze84.github.io
            - name: GIT_URL
              value: github.com
          resources: {}
          volumeMounts:
            - name: shared
              mountPath: /storage
          terminationMessagePath: /dev/termination-log
          terminationMessagePolicy: File
          imagePullPolicy: IfNotPresent
        - name: build
          image: quay.io/jvincze84/mkdocs-build:2.14
          args:
            - build
            - '--clean'
            - '--site-dir'
            - /usr/src/mkdocs/build/srv
          resources: {}
          volumeMounts:
            - name: shared
              mountPath: /usr/src/mkdocs/build
          terminationMessagePath: /dev/termination-log
          terminationMessagePolicy: File
          imagePullPolicy: IfNotPresent
      containers:
        - name: nginx
          image: nginx:latest
          resources: {}
          volumeMounts:
            - name: shared
              mountPath: /usr/share/nginx/html
              subPath: srv
          terminationMessagePath: /dev/termination-log
          terminationMessagePolicy: File
          imagePullPolicy: Always
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

The following environment variabels in the `git initContainer`  must be set accoring to your Git repository:

* **GIT_AUTH**: `true` or `false`. If your git repository uses auth set to `true` otherwise `false`.
* **GIT_URL**: URL of your repository. (Example: github.com) Only `https` is supported. If you need plain http connection you have to modify the  `run.sh` shell script (git clone).
* **GIT_REPO**: You can copy paste this value from the git URL in your browser. Example: `https://github.com/jvincze84/jvincze84.github.io` --> `jvincze84/jvincze84.github.io`
* **GIT_USER**: Your git username. Mandatory if you set `GIT_AUTH` to `true`.
* **GIT_PASS**: Your git password or token. Mandatory if you set `GIT_AUTH` to `true`. 

Additionally you may want to use kuberntes secret for storing the git password. In this case you have to add the following lines to the Deployment:

```yaml
          env:
            - name: GIT_PASS
              valueFrom:
                secretKeyRef:
                  name: gitpass
                  key: gitpass
```

You can create the secret with the following command:

```bash
kubectl -n mkdocs create secret generic gitpass --from-literal=gitpass=1234
```

!!! info

    * The Deployment uses ephemeral storage (`emptyDir: {}`) so every time you deploy a new version or rollout the deployment the entire webpage is regenerated and the previous version won't be kept
    * `volumeMounts`, `mountPath` and `subPath` should not be modified, unless you know what, how and why you do that.

!!! tip

    After you have done with the modification on your docs and pushed back to git, you can rollout the deployment with this command: `kubectl rollout restart -n mkdocs deployment read-the-docs`. Or simply delete the pod. :)
