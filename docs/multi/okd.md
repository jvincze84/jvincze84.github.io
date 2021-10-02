# Role & ServiceAccount

## ClusterRole

Először csinálálni kell egy ClusterRole-t, amit majd a user-hez rendelünk.
Mentsük le az alábbit egy file-ba. (pl.: `01-create-cluster-role.yaml`)

```yaml
kind: ClusterRole
apiVersion: rbac.authorization.k8s.io/v1beta1
metadata:
  name: descheduler-cluster-role
rules:
- apiGroups: [""]
  resources: ["nodes"]
  verbs: ["get", "watch", "list"] 
- apiGroups: [""]
  resources: ["pods"]
  verbs: ["get", "watch", "list", "delete"] 
- apiGroups: [""]
  resources: ["pods/eviction"] 
  verbs: ["create"]
```

Majd futtasuk az `oc create` parancsot:

```bash
oc create -f 01-create-cluster-role.yaml
clusterrole.rbac.authorization.k8s.io/descheduler-cluster-role created
```

Ellenőrzés:
```bash
oc get clusterrole | grep desc
descheduler-cluster-role
```

## User (service account)

A JOB-nak a helye a RedHat leírása alapján a **kube-system** -ben van.

```bash
oc create sa descheduler-sa -n kube-system
```

Ezzel megvan a kis **`descheduler-sa`** service account-unk. 


## Cluster Role Binding

User már van, ClusterRole is van. Már csak valahogyan össze kellene rendelni a kettőt. 

```bash
oc create clusterrolebinding descheduler-cluster-role-binding \
    --clusterrole=descheduler-cluster-role \
    --serviceaccount=kube-system:descheduler-sa
```
* **descheduler-cluster-role-binding** : A ClusterRoleBinding neve.
* **descheduler-cluster-role** : A cluster role neve amit a yaml-ben adtunk meg (`name: descheduler-cluster-role`).
* **kube-system:descheduler-sa** : A namespace és a kettőspont után a user amit előbb csináltunk.

==Futtatás:==
```bash
oc create clusterrolebinding descheduler-cluster-role-binding \
>     --clusterrole=descheduler-cluster-role \
>     --serviceaccount=kube-system:descheduler-sa
clusterrolebinding.rbac.authorization.k8s.io/descheduler-cluster-role-binding created
```

==Ellenőrzés:==
```bash
oc describe clusterrolebinding/descheduler-cluster-role-binding
Name:			descheduler-cluster-role-binding
Created:		Less than a second ago
Labels:			<none>
Annotations:		<none>
Role:			/descheduler-cluster-role
Users:			<none>
Groups:			<none>
ServiceAccounts:	kube-system/descheduler-sa
Subjects:		<none>
Verbs			Non-Resource URLs	Resource Names	API Groups	Resources
[get list watch]	[]			[]		[]		[nodes]
[delete get list watch]	[]			[]		[]		[pods]
[create]		[]			[]		[]		[pods/eviction]
```

Tehát eddig minden ok. :)

# Create Config Map(s)

A majdani job(ok) configmap(ek)ből fogják kiolvasni, hogy mit csináljanak.

Itt van egy komplett példa:
```yaml
apiVersion: "descheduler/v1alpha1"
kind: "DeschedulerPolicy"
strategies:
  "RemoveDuplicates":
     enabled: false
  "LowNodeUtilization":
     enabled: true
     params:
       nodeResourceUtilizationThresholds:
         thresholds:
           "cpu" : 20
           "memory": 20
           "pods": 20
         targetThresholds:
           "cpu" : 50
           "memory": 50
           "pods": 50
         numberOfNodes: 3
  "RemovePodsViolatingInterPodAntiAffinity":
     enabled: true
 ```
 
**Három stratégia van:**
* Remove duplicate pods (*RemoveDuplicates*)
* Move pods to underutilized nodes (*LowNodeUtilization*)
* Remove pods that violate anti-affinity rules (*RemovePodsViolatingInterPodAntiAffinity*).
 
Ez mind a három fel van sorolva a fenti példában.


## Config Map létrehozása

```bash
oc create configmap descheduler-policy-configmap-allinone \
     -n kube-system --from-file=05-allinone-configmap.yaml
```
(Nekem a file neve: `05-allinone-configmap.yaml`)


# Crete (run) Job

Job definíció:

```yaml
apiVersion: batch/v1
kind: Job
metadata:
  name: descheduler-job-03
  namespace: kube-system
spec:
  parallelism: 1
  completions: 1
  template:
    metadata:
      name: descheduler-pod 
      annotations:
        scheduler.alpha.kubernetes.io/critical-pod: "true" 
    spec:
        containers:
        - name: descheduler
          image: itdevarepotst.vodafone.hu/docker-remote-quay/openshift/origin-descheduler:v3.11
          volumeMounts: 
          - mountPath: /policy-dir
            name: policy-volume
          command:
          - "/bin/sh"
          - "-ec"
          - |
            /bin/descheduler --policy-config-file /policy-dir/05-allinone-configmap.yaml
        restartPolicy: "Never"
        serviceAccountName: descheduler-sa 
        volumes:
        - name: policy-volume
          configMap:
            name: descheduler-policy-configmap-allinone
```

Egy kis magyarázkodás:
* **`scheduler.alpha.kubernetes.io/critical-pod: "true"`**
It is important to note that there are a number of core components, such as DNS, that are critical to a fully functional cluster, but, run on a regular cluster node rather than the master. A cluster may stop working properly if the component is evicted. To prevent the descheduler from removing these pods, configure the pod as a critical pod by adding the scheduler.alpha.kubernetes.io/critical-pod annotation to the pod specification.

* **`image: itdevarepotst.vodafone.hu/docker-remote-quay/openshift/origin-descheduler:v3.11`**
Én itt találtam meg a descheduler docker image-t. Seregély Dávid megtalálta egy másik helyen is: [https://microbadger.com/images/openshift/origin-descheduler:v3.11.0](https://microbadger.com/images/openshift/origin-descheduler:v3.11.0) Valószínáleg még több helyen is meg lehet találni. :) A teszt Artifactory-ban a **docker-remote-quay** egy remote repo, ami ide mutat: [https://quay.io](https://quay.io)

* **`name: descheduler-policy-configmap-lownodeutilization`** és **`--policy-config-file /policy-dir/04-test-configmap.yaml`**
Ezek mindkettetten a Configmap-ből jönnek.
Itt, így lehet megtalálni (Name, Data) :
```bash
Name:         descheduler-policy-configmap-allinone
Namespace:    kube-system
Labels:       <none>
Annotations:  <none>

Data
====
05-allinone-configmap.yaml:
----
apiVersion: "descheduler/v1alpha1"
kind: "DeschedulerPolicy"
strategies:
  "RemoveDuplicates":
     enabled: false
  "LowNodeUtilization":
     enabled: true
     params:
       nodeResourceUtilizationThresholds:
         thresholds:
           "cpu" : 20
           "memory": 20
           "pods": 20
         targetThresholds:
           "cpu" : 50
           "memory": 50
           "pods": 50
         numberOfNodes: 3
  "RemovePodsViolatingInterPodAntiAffinity":
     enabled: true

Events:  <none>

```

Run Job:

Ezt már a legegyszerűbb része, vagy `oc apply` vagy `oc create` parancs.

```bash
oc apply -f 03-CreateJob.yaml
```

Ellenőrzés:
```bash
oc get job
NAME                 DESIRED   SUCCESSFUL   AGE
descheduler-job-03   1         1            9s
```

Ez a szerencsétlen sajnos semmi logot nem ír:
```plain
janos.vincze@MCC013625:/storage/janos.vincze/x-Temp/20200317/Guide$ oc logs job/descheduler-job-03
janos.vincze@MCC013625:/storage/janos.vincze/x-Temp/20200317/Guide$
janos.vincze@MCC013625:/storage/janos.vincze/x-Temp/20200317/Guide$ oc logs pod/descheduler-job-03-8f5hb
janos.vincze@MCC013625:/storage/janos.vincze/x-Temp/20200317/Guide$
```

Így ellenőrizni csak a `describe` vagy `oc get events` paranccsal lehet.

Újrafuttatni a job-ot így lehet:
```plain
janos.vincze@MCC013625:/storage/janos.vincze/x-Temp/20200317/Guide$ oc delete -f 03-CreateJob.yaml
job.batch "descheduler-job-03" deleted
janos.vincze@MCC013625:/storage/janos.vincze/x-Temp/20200317/Guide$ oc apply -f 03-CreateJob.yaml
job.batch/descheduler-job-03 created
janos.vincze@MCC013625:/storage/janos.vincze/x-Temp/20200317/Guide$
```

**Vagy** a job definíciós file-be átírod a nevét:
```yaml
apiVersion: batch/v1
kind: Job
metadata:
  name: descheduler-job-03
  namespace: kube-system
spec:
```

Pl. `descheduler-job-03` --> `descheduler-job-04`

És így már két job lesz SUCCESSFUL state-ben:
```plain
janos.vincze@MCC013625:/storage/janos.vincze/x-Temp/20200317/Guide$ oc get jobs
NAME                 DESIRED   SUCCESSFUL   AGE
descheduler-job-03   1         1            1m
descheduler-job-04   1         1            26s
```


# Tesztelés
Kettes lábat kiszedtem a forgalomból:

`oc adm manage-node itdevkubtstapp2.vodafone.hu --schedulable=false`

És evakuáltam:

`oc adm manage-node itdevkubtstapp2.vodafone.hu --evacuate`

Parancs kimenete: [evaculate.txt](:/f4f17ca0444242328d24e3f0e084805a)

Így gyakorlatilag nem maradt rajta POD: 

```plain
janos.vincze@MCC013625:/storage/janos.vincze/x-Temp/20200317/Guide$ oc get pods --all-namespaces -o wide --field-selector=spec.nodeName=itdevkubtstapp2.vodafone.hu
NAMESPACE                NAME                                READY     STATUS              RESTARTS   AGE       IP              NODE                          NOMINATED NODE
app-storage              glusterfs-storage-nzshm             0/1       Pending             0          3s        <none>          itdevkubtstapp2.vodafone.hu   <none>
application-monitoring   prom-0                              3/4       CrashLoopBackOff    64         5h        192.168.1.103   itdevkubtstapp2.vodafone.hu   <none>
ent-arch-dbms            mysql-master-6-r57qm                0/1       Terminating         327        1d        192.168.1.98    itdevkubtstapp2.vodafone.hu   <none>
microserviceproject      microservice-kitchen-sin-10-fcj2q   1/1       Terminating         0          1d        192.168.1.39    itdevkubtstapp2.vodafone.hu   <none>
openshift-logging        logging-fluentd-g455f               0/1       ContainerCreating   0          31s       <none>          itdevkubtstapp2.vodafone.hu   <none>
openshift-monitoring     node-exporter-zb7cv                 0/2       ContainerCreating   0          29s       172.17.64.45    itdevkubtstapp2.vodafone.hu   <none>
openshift-node           sync-c6smk                          0/1       ContainerCreating   0          39s       172.17.64.45    itdevkubtstapp2.vodafone.hu   <none>
openshift-sdn            ovs-pfcvz                           0/1       ContainerCreating   0          34s       172.17.64.45    itdevkubtstapp2.vodafone.hu   <none>
openshift-sdn            sdn-nrd5j                           0/1       ContainerCreating   0          33s       172.17.64.45    itdevkubtstapp2.vodafone.hu   <none>
```


Ezután visszaállítottam a "schedulable" flag-et:

`oc adm manage-node itdevkubtstapp2.vodafone.hu --schedulable=true`

Egyébként ellenőrizni így (is) lehet:

```
janos.vincze@MCC013625:/storage/janos.vincze/x-Temp/20200317/Guide$ oc describe node/itdevkubtstapp2.vodafone.hu | grep Unschedulable
Unschedulable: true
```

Érdemes figyelni mert ellentétes a két cuccos: schedulable <--> Unschedulable

Ezzel a beállítással teszteltem:

```yaml
apiVersion: "descheduler/v1alpha1"
kind: "DeschedulerPolicy"
strategies:
  "RemoveDuplicates":
     enabled: false
  "LowNodeUtilization":
     enabled: true
     params:
       nodeResourceUtilizationThresholds:
         thresholds:
           "pods": 20
         targetThresholds:
           "pods": 50
  "RemovePodsViolatingInterPodAntiAffinity":
     enabled: true
```

És itt látni, hogy mi történt:

```plain
janos.vincze@MCC013625:/storage/janos.vincze/x-Temp/20200317/Guide$ oc get pods --all-namespaces -o wide --field-selector=spec.nodeName=itdevkubtstapp2.vodafone.hu | wc -l
15
janos.vincze@MCC013625:/storage/janos.vincze/x-Temp/20200317/Guide$ oc delete cm/descheduler-policy-configmap-allinone
configmap "descheduler-policy-configmap-allinone" deleted
janos.vincze@MCC013625:/storage/janos.vincze/x-Temp/20200317/Guide$ oc create configmap descheduler-policy-configmap-allinone -n kube-system --from-file=05-allinone-configmap.yaml
configmap/descheduler-policy-configmap-allinone created
janos.vincze@MCC013625:/storage/janos.vincze/x-Temp/20200317/Guide$ oc delete -f 03-CreateJob.yaml
job.batch "descheduler-job-04" deleted
janos.vincze@MCC013625:/storage/janos.vincze/x-Temp/20200317/Guide$ oc apply -f 03-CreateJob.yaml
job.batch/descheduler-job-04 created
janos.vincze@MCC013625:/storage/janos.vincze/x-Temp/20200317/Guide$ oc get pods --all-namespaces -o wide --field-selector=spec.nodeName=itdevkubtstapp2.vodafone.hu | wc -l
21
janos.vincze@MCC013625:/storage/janos.vincze/x-Temp/20200317/Guide$ oc get pods --all-namespaces -o wide --field-selector=spec.nodeName=itdevkubtstapp2.vodafone.hu | wc -l
21
```

Látni, hogy a job futása előtt csak ~15 POD volt rajta, utána pedig ~21 darab.

