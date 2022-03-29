# StatefulSet

## Example: Elasticsearch Cluster

```yaml linenums="1" hl_lines="24 70"
kind: StatefulSet
apiVersion: apps/v1
metadata:
  name: es-cluster
  namespace: kibana
spec:
  replicas: 5
  selector:
    matchLabels:
      k8s-app: es-cluster
  template:
    metadata:
      name: es-cluster
      labels:
        k8s-app: es-cluster
    spec:
      containers:
        - resources:
            requests:
              cpu: '1'
              memory: 5G
          name: es-cluster
          env:
            - name: NODENAME
              valueFrom:
                fieldRef:
                  apiVersion: v1
                  fieldPath: metadata.name
            - name: SERVICENAME
              value: es-cluster
            - name: node.name
              value: $(NODENAME).$(SERVICENAME)
            - name: cluster.name
              value: es-cluster
            - name: ES_JAVA_OPTS
              value: '-Xms4g -Xmx4g'
            - name: discovery.seed_hosts
              value: >-
                es-cluster-0.es-cluster,es-cluster-1.es-cluster,es-cluster-2.es-cluster,es-cluster-3.es-cluster,es-cluster-4.es-cluster
            - name: cluster.initial_master_nodes
              value: >-
                es-cluster-0.es-cluster,es-cluster-1.es-cluster,es-cluster-2.es-cluster,es-cluster-3.es-cluster,es-cluster-4.es-cluster
          ports:
            - name: http
              containerPort: 9200
              protocol: TCP
            - name: tcp
              containerPort: 9300
              protocol: TCP
          imagePullPolicy: Always
          volumeMounts:
            - name: es-data
              mountPath: /usr/share/elasticsearch/data
              subPath: etc
          image: 'docker.elastic.co/elasticsearch/elasticsearch:7.16.2'
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
            storage: 20Gi
        storageClassName: cephfs-ec
        volumeMode: Filesystem
  serviceName: es-cluster
  podManagementPolicy: OrderedReady
  updateStrategy:
    type: RollingUpdate
    rollingUpdate:
      partition: 0
  revisionHistoryLimit: 10
```

`- name: NODENAME`	
:	<a href="https://kubernetes.io/docs/tasks/inject-data-application/downward-api-volume-expose-pod-information/#the-downward-api" target="_blank">The Downward API</a> 


`serviceName: es-cluster`
:   **serviceName:** serviceName is the name of the service that governs this StatefulSet. This
    service must exist before the StatefulSet, and is responsible for the
    network identity of the set. Pods get DNS/hostnames that follow the
    pattern: pod-specific-string.serviceName.default.svc.cluster.local where
    "pod-specific-string" is managed by the StatefulSet controller.

