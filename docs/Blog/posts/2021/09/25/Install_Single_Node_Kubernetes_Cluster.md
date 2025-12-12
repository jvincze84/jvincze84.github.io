---
title: Install A Single Node Kubernetes "Cluster"
date: 2021-09-25
---

# Install A Single Node Kubernetes "Cluster"

In this article we will install a single node kubernetes cluster on Debian 11 (bullseye). I will walk through step by step all the commands and configurations.

## Prerequisite

I'm using a really old system for this demonstration:

* CPU: Intel(R) Core(TM)2 CPU 6400  @ 2.13GHz (Dell Optiplex 745)
* Mem: 4 GB
* Disk: 500 GB HDD
* OS: Debian GNU/Linux 11 (bullseye)

After successfully installation of my Debian system, install some necessary tools:

```bash
apt-get install vim mc net-tools sudo jq
```

* (Optional) Change sudoers file:

```diff
--- /etc/sudoers-orig 2021-10-11 10:14:00.276397052 +0200
+++ /etc/sudoers  2021-10-11 10:14:20.832894911 +0200
@@ -20,7 +20,7 @@
 root ALL=(ALL:ALL) ALL
 
 # Allow members of group sudo to execute any command
-%sudo  ALL=(ALL:ALL) ALL
+%sudo  ALL=(ALL:ALL) NOPASSWD:ALL
 
 # See sudoers(5) for more information on "@include" directives:
```

* Add user to `sudo` group (`/usr/sbin/visudo`)

```bash
/usr/sbin/usermod -aG sudo kube
```

## Install Container Runtime

I always recommend to follow the official installation guide: [https://kubernetes.io/docs/setup/production-environment/container-runtimes](https://kubernetes.io/docs/setup/production-environment/container-runtimes)
Everything is well docomented and easy to follow. 

Kubernetes will leave Docker support so we will use Containerd as container runtime. 

!!! info
    Read more about Docker vs Kubernetes: [https://kubernetes.io/blog/2020/12/02/dont-panic-kubernetes-and-docker/](https://kubernetes.io/blog/2020/12/02/dont-panic-kubernetes-and-docker/)

Before you start you may want to check the official Docker installation page: [https://docs.docker.com/engine/install/debian/](https://docs.docker.com/engine/install/debian/)

!!! info
    I know that I post a lot of link as references, but it is really important to understand how important is it to always read the official documentation.  
    Almost all these installation steps are copy-pasted from the official sites. 

* Install requirements

```bash
sudo bash

apt-get install \
    apt-transport-https \
    ca-certificates \
    curl \
    gnupg \
    lsb-release
```

* Add GPG key

```bash
curl -fsSL https://download.docker.com/linux/debian/gpg |  gpg --dearmor -o /usr/share/keyrings/docker-archive-keyring.gpg

echo \
  "deb [arch=$(dpkg --print-architecture) signed-by=/usr/share/keyrings/docker-archive-keyring.gpg] https://download.docker.com/linux/debian \
  $(lsb_release -cs) stable" |  tee /etc/apt/sources.list.d/docker.list > /dev/null
```

* Install Docker & containerd

```bash
apt-get update
apt-get install docker-ce docker-ce-cli containerd.io
```

* Check the installtion

```bash
docker info
docker run hello-world
```

* Prepare Containerd for Kubernetes

```bash
cat <<EOF |  tee /etc/modules-load.d/containerd.conf
overlay
br_netfilter
EOF
```

```bash
modprobe overlay
modprobe br_netfilter
```

```bash
cat <<EOF | tee /etc/sysctl.d/99-kubernetes-cri.conf
net.bridge.bridge-nf-call-iptables  = 1
net.ipv4.ip_forward                 = 1
net.bridge.bridge-nf-call-ip6tables = 1
EOF

sysctl --system

mkdir -p /etc/containerd
containerd config default | tee /etc/containerd/config.toml


systemctl restart containerd
systemctl status containerd
```

* Using the systemd cgroup drive

```bash
cp /etc/containerd/config.toml /etc/containerd/config.toml-orig
```

**Edit the `/etc/containerd/config.toml` file**

```diff
--- /etc/containerd/config.toml-orig  2021-10-11 10:33:39.603577510 +0200
+++ /etc/containerd/config.toml 2021-10-11 10:35:01.753393462 +0200
@@ -94,6 +94,7 @@
           privileged_without_host_devices = false
           base_runtime_spec = ""
           [plugins."io.containerd.grpc.v1.cri".containerd.runtimes.runc.options]
+            SystemdCgroup = true
     [plugins."io.containerd.grpc.v1.cri".cni]
       bin_dir = "/opt/cni/bin"
       conf_dir = "/etc/cni/net.d"
```

### Fix `crictl` error

```text hl_lines="1" linenums="1"
crictl ps
FATA[0010] failed to connect: failed to connect: context deadline exceeded
```

Fix:

```bash
cat <<EOF>/etc/crictl.yaml
runtime-endpoint: unix:///run/containerd/containerd.sock
image-endpoint: unix:///run/containerd/containerd.sock
timeout: 2
debug: false
pull-image-on-create: false
EOF
```

Reference: [https://github.com/cri-o/cri-o/issues/1922#issuecomment-828275332](https://github.com/cri-o/cri-o/issues/1922#issuecomment-828275332)



## Install Kubernetes

Follow the steps described here: [https://kubernetes.io/docs/setup/production-environment/tools/kubeadm/](https://kubernetes.io/docs/setup/production-environment/tools/kubeadm/)

### Installing kubeadm

```bash
cat <<EOF |  tee /etc/modules-load.d/k8s.conf
br_netfilter
EOF

cat <<EOF |  tee /etc/sysctl.d/k8s.conf
net.bridge.bridge-nf-call-ip6tables = 1
net.bridge.bridge-nf-call-iptables = 1
EOF

sysctl --system
```

```bash
apt-get update
apt-get install -y apt-transport-https ca-certificates curl

# The URL has been changed! curl -fsSLo /usr/share/keyrings/kubernetes-archive-keyring.gpg https://packages.cloud.google.com/apt/doc/apt-key.gpg
curl -fsSL https://pkgs.k8s.io/core:/stable:/v1.28/deb/Release.key |  gpg --dearmor -o /etc/apt/keyrings/kubernetes-apt-keyring.gpg

# Deprecated : echo "deb [signed-by=/usr/share/keyrings/kubernetes-archive-keyring.gpg] https://apt.kubernetes.io/ kubernetes-xenial main" |  tee /etc/apt/sources.list.d/kubernetes.list
echo 'deb [signed-by=/etc/apt/keyrings/kubernetes-apt-keyring.gpg] https://pkgs.k8s.io/core:/stable:/v1.28/deb/ /' |  tee /etc/apt/sources.list.d/kubernetes.list

apt-get update
```

!!! warning
    Location of the keyring and the source has been changed. If you need older version please modify the url accordingly.
    Example: `deb [signed-by=/etc/apt/keyrings/kubernetes-apt-keyring.gpg] https://pkgs.k8s.io/core:/stable:/v1.27/deb/ /'`



Now we do some extra steps before installing the kubeadm. In the world of Kubernetes it is important to install the same version of kubeadm kubelet and kubectl. So fist we check the avaiable versions:

```bash title="Command"
# apt-cache madison kubeadm | egrep '(1.22|1.21)'
apt-cache madison kubeadm
```
```text title="Output"
   kubeadm | 1.28.2-1.1 | https://pkgs.k8s.io/core:/stable:/v1.28/deb  Packages
   kubeadm | 1.28.1-1.1 | https://pkgs.k8s.io/core:/stable:/v1.28/deb  Packages
   kubeadm | 1.28.0-1.1 | https://pkgs.k8s.io/core:/stable:/v1.28/deb  Packages
```


We won't install the latest version in order to be able to show you an update process as well.

```bash
apt-get install -y kubelet=1.28.1-1.1  kubeadm=1.28.1-1.1  kubectl=1.28.1-1.1 
apt-mark hold kubelet kubeadm kubectl
```

!!! info
    We don't want to update kubeadm, kubeclt and kubelet with system (os) updates (apt-get update & upgrade). Kubernetes update has its own process. Always be careful when update you base system, and never update these packages alongside with the underlying os.

**Check the installed version**
```bash title="Command"
kubeadm version -o yaml
```
```text title="Output"
clientVersion:
  buildDate: "2023-08-24T11:21:51Z"
  compiler: gc
  gitCommit: 8dc49c4b984b897d423aab4971090e1879eb4f23
  gitTreeState: clean
  gitVersion: v1.28.1
  goVersion: go1.20.7
  major: "1"
  minor: "28"
  platform: linux/amd64
```


### Init the cluster

Check the breif help of the `kubeadm init` command:

```bash
kubeadm init --help
```

!!! caution
    Disable SWAP before you start, otherwise you will get this error: `ERROR Swap]: running with swap on is not supported. Please disable swap`  
    To do this remove the corresponding line from `/etc/fstab` and run `swapoff --all` command.

**Options**

* `--cri-socket /var/run/containerd/containerd.sock` --> We want to use Containerd as container runtime insted of the default docker.
* `--service-cidr 10.22.0.0/16` and  `--pod-network-cidr 10.23.0.0/16` --> Really important to size well your internal Kubernets network. Be sure that none of these IP address ranges don't overlap your phisical network, VPN connection or each other. Since this is only a demo system it will be enough about 250 IP address for PODS and Services. 

!!! warning
    W0914 09:42:57.948845    4568 initconfiguration.go:120] **Usage of CRI endpoints without URL scheme is deprecated** and can cause kubelet errors in the future. Automatically prepending scheme "unix" to the "criSocket" with value "/var/run/containerd/containerd.sock". Please update your configuration!


```bash linenums="1" title="Command"
kubeadm init \
--cri-socket unix:///var/run/containerd/containerd.sock \
--service-cidr 10.22.0.0/16 \
--pod-network-cidr 10.23.0.0/16
```
```text title="Output" linenums="1" hl_lines="57-63"
[init] Using Kubernetes version: v1.28.2
[preflight] Running pre-flight checks
[preflight] Pulling images required for setting up a Kubernetes cluster
[preflight] This might take a minute or two, depending on the speed of your internet connection
[preflight] You can also perform this action in beforehand using 'kubeadm config images pull'
W0914 09:45:09.492639    6161 checks.go:835] detected that the sandbox image "registry.k8s.io/pause:3.6" of the container runtime is inconsistent with that used by kubeadm. It is recommended that using "registry.k8s.io/pause:3.9" as the CRI sandbox image.
[certs] Using certificateDir folder "/etc/kubernetes/pki"
[certs] Generating "ca" certificate and key
[certs] Generating "apiserver" certificate and key
[certs] apiserver serving cert is signed for DNS names [kubernetes kubernetes.default kubernetes.default.svc kubernetes.default.svc.cluster.local singlek8s] and IPs [10.22.0.1 172.16.1.70]
[certs] Generating "apiserver-kubelet-client" certificate and key
[certs] Generating "front-proxy-ca" certificate and key
[certs] Generating "front-proxy-client" certificate and key
[certs] Generating "etcd/ca" certificate and key
[certs] Generating "etcd/server" certificate and key
[certs] etcd/server serving cert is signed for DNS names [localhost singlek8s] and IPs [172.16.1.70 127.0.0.1 ::1]
[certs] Generating "etcd/peer" certificate and key
[certs] etcd/peer serving cert is signed for DNS names [localhost singlek8s] and IPs [172.16.1.70 127.0.0.1 ::1]
[certs] Generating "etcd/healthcheck-client" certificate and key
[certs] Generating "apiserver-etcd-client" certificate and key
[certs] Generating "sa" key and public key
[kubeconfig] Using kubeconfig folder "/etc/kubernetes"
[kubeconfig] Writing "admin.conf" kubeconfig file
[kubeconfig] Writing "kubelet.conf" kubeconfig file
[kubeconfig] Writing "controller-manager.conf" kubeconfig file
[kubeconfig] Writing "scheduler.conf" kubeconfig file
[etcd] Creating static Pod manifest for local etcd in "/etc/kubernetes/manifests"
[control-plane] Using manifest folder "/etc/kubernetes/manifests"
[control-plane] Creating static Pod manifest for "kube-apiserver"
[control-plane] Creating static Pod manifest for "kube-controller-manager"
[control-plane] Creating static Pod manifest for "kube-scheduler"
[kubelet-start] Writing kubelet environment file with flags to file "/var/lib/kubelet/kubeadm-flags.env"
[kubelet-start] Writing kubelet configuration to file "/var/lib/kubelet/config.yaml"
[kubelet-start] Starting the kubelet
[wait-control-plane] Waiting for the kubelet to boot up the control plane as static Pods from directory "/etc/kubernetes/manifests". This can take up to 4m0s
[apiclient] All control plane components are healthy after 4.002225 seconds
[upload-config] Storing the configuration used in ConfigMap "kubeadm-config" in the "kube-system" Namespace
[kubelet] Creating a ConfigMap "kubelet-config" in namespace kube-system with the configuration for the kubelets in the cluster
[upload-certs] Skipping phase. Please see --upload-certs
[mark-control-plane] Marking the node singlek8s as control-plane by adding the labels: [node-role.kubernetes.io/control-plane node.kubernetes.io/exclude-from-external-load-balancers]
[mark-control-plane] Marking the node singlek8s as control-plane by adding the taints [node-role.kubernetes.io/control-plane:NoSchedule]
[bootstrap-token] Using token: m8tywn.9f3xegmdoa30d8v4
[bootstrap-token] Configuring bootstrap tokens, cluster-info ConfigMap, RBAC Roles
[bootstrap-token] Configured RBAC rules to allow Node Bootstrap tokens to get nodes
[bootstrap-token] Configured RBAC rules to allow Node Bootstrap tokens to post CSRs in order for nodes to get long term certificate credentials
[bootstrap-token] Configured RBAC rules to allow the csrapprover controller automatically approve CSRs from a Node Bootstrap Token
[bootstrap-token] Configured RBAC rules to allow certificate rotation for all node client certificates in the cluster
[bootstrap-token] Creating the "cluster-info" ConfigMap in the "kube-public" namespace
[kubelet-finalize] Updating "/etc/kubernetes/kubelet.conf" to point to a rotatable kubelet client certificate and key
[addons] Applied essential addon: CoreDNS
[addons] Applied essential addon: kube-proxy

Your Kubernetes control-plane has initialized successfully!

To start using your cluster, you need to run the following as a regular user:

  mkdir -p $HOME/.kube
  sudo cp -i /etc/kubernetes/admin.conf $HOME/.kube/config
  sudo chown $(id -u):$(id -g) $HOME/.kube/config

Alternatively, if you are the root user, you can run:

  export KUBECONFIG=/etc/kubernetes/admin.conf

You should now deploy a pod network to the cluster.
Run "kubectl apply -f [podnetwork].yaml" with one of the options listed at:
  https://kubernetes.io/docs/concepts/cluster-administration/addons/

Then you can join any number of worker nodes by running the following on each as root:

kubeadm join 172.16.1.70:6443 --token m8tywn.9f3xegmdoa30d8v4 \
        --discovery-token-ca-cert-hash sha256:4ee5a244df12c803c78ba4bf55518d6c0f7ef84e655d4bce1cb40f8c967d60c2
```

Beleve or not our Single node Kubernetes cluster is almost ready. :)

Check it:

```bash linenums="1"
mkdir -p $HOME/.kube
sudo cp -i /etc/kubernetes/admin.conf $HOME/.kube/config
sudo chown $(id -u):$(id -g) $HOME/.kube/config
export KUBECONFIG=/etc/kubernetes/admin.conf

kubectl get nodes -o wide
```

Output looks like this:
```plain linenums="1"
NAME        STATUS   ROLES                  AGE   VERSION   INTERNAL-IP   EXTERNAL-IP   OS-IMAGE                         KERNEL-VERSION   CONTAINER-RUNTIME
singlek8s   Ready    control-plane,worker   21m   v1.28.1   172.16.1.70   <none>        Debian GNU/Linux 12 (bookworm)   6.1.0-12-amd64   containerd://1.6.22
```

It is beutiful, isn't it?


### Why my node is in `NotReady` state?

I can say that this behavior is normal in case of newly installed Kubernetes cluster. Check the reaseon:


```bash title="Command"
kubectl get pods --all-namespaces -o wide
```
```text title="Output"
NAMESPACE     NAME                                READY   STATUS    RESTARTS        AGE    IP            NODE        NOMINATED NODE   READINESS GATES
kube-system   coredns-5dd5756b68-756n6            0/1     Pending   0               18s    <none>        <none>      <none>           <none>
kube-system   coredns-5dd5756b68-l82qm            0/1     Pending   0               18s    <none>        <none>      <none>           <none>
kube-system   etcd-singlek8s                      1/1     Running   3 (2m20s ago)   106s   172.16.1.70   singlek8s   <none>           <none>
kube-system   kube-apiserver-singlek8s            1/1     Running   4 (59s ago)     106s   172.16.1.70   singlek8s   <none>           <none>
kube-system   kube-controller-manager-singlek8s   1/1     Running   4 (78s ago)     106s   172.16.1.70   singlek8s   <none>           <none>
kube-system   kube-proxy-rkqnk                    1/1     Running   1 (25s ago)     89s    172.16.1.70   singlek8s   <none>           <none>
kube-system   kube-scheduler-singlek8s            1/1     Running   4 (78s ago)     106s   172.16.1.70   singlek8s   <none>           <none>
```

You can see that the coredns pods are in pending state. These pods are responsible for internal DNS queries inside the Cluster Network. What should be the problem? We don't have any network plugin installed in the cluster....

Links: 

 * [https://kubernetes.io/docs/concepts/extend-kubernetes/compute-storage-net/network-plugins/](https://kubernetes.io/docs/concepts/extend-kubernetes/compute-storage-net/network-plugins/)
 * [https://kubevious.io/blog/post/comparing-kubernetes-container-network-interface-cni-providers](https://kubevious.io/blog/post/comparing-kubernetes-container-network-interface-cni-providers)

As you can see that there are a lot of varions of network plugins. For this little home environment I chose weave: [https://www.weave.works/docs/net/latest/kubernetes/kube-addon/#install](https://www.weave.works/docs/net/latest/kubernetes/kube-addon/#install)

It is really simple to install, can be achieved with only one command:

```bash title="Command"
# Depreaceted: kubectl apply -f "https://cloud.weave.works/k8s/net?k8s-version=$(kubectl version | base64 | tr -d '\n')"
kubectl apply -f https://github.com/weaveworks/weave/releases/download/v2.8.1/weave-daemonset-k8s.yaml

```
```text title="Output"
serviceaccount/weave-net created
clusterrole.rbac.authorization.k8s.io/weave-net created
clusterrolebinding.rbac.authorization.k8s.io/weave-net created
role.rbac.authorization.k8s.io/weave-net created
rolebinding.rbac.authorization.k8s.io/weave-net created
daemonset.apps/weave-net created
```

Check again the cluster:

```bash title="Command"
kubectl get pods --all-namespaces -o wide
```
```text title="Output"
NAMESPACE     NAME                                READY   STATUS    RESTARTS        AGE     IP            NODE        NOMINATED NODE   READINESS GATES
kube-system   coredns-5dd5756b68-756n6            1/1     Running   2 (6m11s ago)   17m     10.32.0.1     singlek8s   <none>           <none>
kube-system   coredns-5dd5756b68-l82qm            1/1     Running   1 (9m29s ago)   17m     10.32.0.3     singlek8s   <none>           <none>
kube-system   etcd-singlek8s                      1/1     Running   6 (3m55s ago)   19m     172.16.1.70   singlek8s   <none>           <none>
kube-system   kube-apiserver-singlek8s            1/1     Running   8 (3m13s ago)   19m     172.16.1.70   singlek8s   <none>           <none>
kube-system   kube-controller-manager-singlek8s   1/1     Running   9 (5m52s ago)   19m     172.16.1.70   singlek8s   <none>           <none>
kube-system   kube-proxy-rkqnk                    1/1     Running   7 (4m7s ago)    19m     172.16.1.70   singlek8s   <none>           <none>
kube-system   kube-scheduler-singlek8s            1/1     Running   9 (7m30s ago)   19m     172.16.1.70   singlek8s   <none>           <none>
kube-system   weave-net-68qbb                     2/2     Running   0               8m36s   172.16.1.70   singlek8s   <none>           <none>
```

```bash title="Command"
kubectl get nodes -o wide
```
```text title="Output"
NAME        STATUS   ROLES                  AGE   VERSION   INTERNAL-IP    EXTERNAL-IP   OS-IMAGE                         KERNEL-VERSION   CONTAINER-RUNTIME
kube-test   Ready    control-plane,master   18m   v1.21.5   172.16.1.214   <none>        Debian GNU/Linux 11 (bullseye)   5.10.0-9-amd64   containerd://1.4.11
```


Now we really have a working single node Kubernetes cluster. 

Before jump to the next section take a look at the node role: `control-plane,master`  
This means the only node we hava acts as control-plane and master, since we won't have any other worker nodes this nodes must have worker role as well:

```bash
kubectl label node singlek8s node-role.kubernetes.io/worker=
```

But this is not enoguh because the master nodes have taint by default: [https://kubernetes.io/docs/concepts/scheduling-eviction/taint-and-toleration/](https://kubernetes.io/docs/concepts/scheduling-eviction/taint-and-toleration/)

You can check the taint with `kubectl get node kube-test -o yaml` command:

```plain
...
  taints:
  - effect: NoSchedule
    key: node-role.kubernetes.io/control-plane
```

Remove this taint:
```bash
kubectl taint nodes kube-test node-role.kubernetes.io/master=:NoSchedule-
kubectl taint nodes singlek8s node-role.kubernetes.io/control-plane-
```

## Post Installation Steps

### Scale Down The CoreDNS Deployment

Remember we have only one node in this demo cluster. It's not neccessary to have multiple instance of our applications, because all of them will run on this single node, and this behaviour doesn't give us any extras. 

```bash
kubectl edit -n kube-system deployment coredns
```

Change the replicas to 1:
```yaml
spec:
  progressDeadlineSeconds: 600
  replicas: 1
  revisionHistoryLimit: 10
  selector:
    matchLabels:
```

**Check**
```bash title="Command"
kubectl -n kube-system get pods
```
```text title="Output"
NAME                                READY   STATUS    RESTARTS   AGE
coredns-558bd4d5db-l6gtq            1/1     Running   0          32m
etcd-kube-test                      1/1     Running   0          33m
kube-apiserver-kube-test            1/1     Running   0          33m
kube-controller-manager-kube-test   1/1     Running   0          33m
kube-proxy-nhm2h                    1/1     Running   0          32m
kube-scheduler-kube-test            1/1     Running   0          33m
weave-net-l8xkh                     2/2     Running   1          16m
```

### Install Kuberntes Metrics Server

In order to get basic performance information about our cluster or pods we have to install Kubernetes Metrics Server:

* [https://github.com/kubernetes-sigs/metrics-server](https://github.com/kubernetes-sigs/metrics-server)

```bash
kubectl apply -f https://github.com/kubernetes-sigs/metrics-server/releases/latest/download/components.yaml
```

You probalby will get the following error:

```bash
kubectl -n kube-system logs metrics-server-6775f684f6-gxpcz
```

Output: 

```log
E1011 09:43:22.529064       1 scraper.go:139] "Failed to scrape node" err="Get \"https://172.16.1.214:10250/stats/summary?only_cpu_and_memory=true\": x509: cannot validate certificate for 172.16.1.214 because it doesn't contain any IP SANs" node="kube-test"
```

Edit the deployment `kubectl -n kube-system edit  deployment metrics-server` and add this lint to `args`:


```yaml
      containers:
      - args:
        - --kubelet-insecure-tls
```

**Check**
```bash title="Command"
kubectl -n kube-system top pods
```
```text title="Output"
NAME                                CPU(cores)   MEMORY(bytes)   
coredns-558bd4d5db-l6gtq            3m           18Mi            
etcd-kube-test                      16m          41Mi            
kube-apiserver-kube-test            76m          333Mi           
kube-controller-manager-kube-test   12m          60Mi            
kube-proxy-nhm2h                    1m           20Mi            
kube-scheduler-kube-test            4m           25Mi            
metrics-server-6775f684f6-gxpcz     6m           18Mi            
weave-net-l8xkh                     2m           61Mi
```


### Install (Nginx) Ingress Controller

Maybe this it the most interesting part of this article as for now. You can chose from various ingress controller to install. Check the official documentation for more details:

* [https://kubernetes.io/docs/concepts/services-networking/ingress-controllers/](https://kubernetes.io/docs/concepts/services-networking/ingress-controllers/)

For this demo I choose the NGinx Ingress Controller. I think it is easy to install and maybe some of your already have experience with NGinx on bare metal. I can't tell you any other news than checking the official docs: [https://kubernetes.github.io/ingress-nginx/deploy/](https://kubernetes.github.io/ingress-nginx/deploy/) 

We are going to follow the Bare Metal installation: [https://kubernetes.github.io/ingress-nginx/deploy/#bare-metal](https://kubernetes.github.io/ingress-nginx/deploy/#bare-metal)

```bash
# Old version: kubectl apply -f https://raw.githubusercontent.com/kubernetes/ingress-nginx/controller-v0.49.3/deploy/static/provider/baremetal/deploy.yaml
kubectl apply -f https://raw.githubusercontent.com/kubernetes/ingress-nginx/controller-v1.8.2/deploy/static/provider/cloud/deploy.yaml


# Check The Install Process: 

kubectl get pods -n ingress-nginx \
  -l app.kubernetes.io/name=ingress-nginx --watch
```

!!! warning
    Do NOT deploy the latest version (v1.0.3)! It won't work with hostNetwork on Bare Metal installation. The address field will be blank even if you specify `--report-node-internal-ip-address` command line arguments. I've tried a lot of settings but none of them worked.

Wait for this line:
```plain
ingress-nginx-controller-6c68f5b657-hvfn9   1/1     Running             0          60s
```

This is the default installation process. But at this point we have only NodePort service for incomming traffic:

```bash title="Command"
kubectl -n ingress-nginx get services
```
```text title="Ouptut"
NAME                                 TYPE        CLUSTER-IP    EXTERNAL-IP   PORT(S)                      AGE
ingress-nginx-controller             NodePort    10.22.0.78    <none>        80:30016/TCP,443:32242/TCP   104s
ingress-nginx-controller-admission   ClusterIP   10.22.0.242   <none>        443/TCP                      104s
```

!!! warning
    Please read very carefully this documentation: [https://kubernetes.github.io/ingress-nginx/deploy/baremetal/](https://kubernetes.github.io/ingress-nginx/deploy/baremetal/)

This NodePort means that our NGinx ingress controller is accessible on every node in the cluster on `30016/TCP` and `32242/TCP`. It is OK if you planning to use these ports to access the applications inside the cluster.  
Or you can install a reverse proxy somewehere in you physical network. This can be the Kubernetes host itself. Configuring a reverse proxy could be a pain, and it is not the subject of this article.

**Check**

To check the NGinx Ingress Controller you should use another machine in your network. Most of the time I use curl to check if web server is running or not, but you can use your browser instead.

```bash title="Command"
curl -i http://172.16.1.214:30016 
```
```text title="Output"
HTTP/1.1 404 Not Found
Date: Mon, 11 Oct 2021 10:11:40 GMT
Content-Type: text/html
Content-Length: 146
Connection: keep-alive

<html>
<head><title>404 Not Found</title></head>
<body>
<center><h1>404 Not Found</h1></center>
<hr><center>nginx</center>
</body>
</html>
```

```bash title="Command"
curl -ik https://172.16.1.214:32242
```
```text title="Ouptut"
HTTP/2 404 
date: Mon, 11 Oct 2021 10:12:13 GMT
content-type: text/html
content-length: 146
strict-transport-security: max-age=15724800; includeSubDomains

<html>
<head><title>404 Not Found</title></head>
<body>
<center><h1>404 Not Found</h1></center>
<hr><center>nginx</center>
</body>
</html>
```


This is not the desired stat I want, I want to access my Ingresss Controller over the standard 80(http) and 443(https) ports, so choose the hostPort: [https://kubernetes.github.io/ingress-nginx/deploy/baremetal/#via-the-host-network](https://kubernetes.github.io/ingress-nginx/deploy/baremetal/#via-the-host-network)

!!! caution
    This setup absolutely not suitable for Production environment, but just enough for this demo.

```bash
kubectl patch deployment/ingress-nginx-controller -n ingress-nginx \
-p '{ "spec": { "template": { "spec": { "hostNetwork": true } } } }'
```
!!! info
    This command does't not effects the `Service`. If you want to check the config describe your pod with `kubectl -n ingress-nginx describe  $(kubectl -n ingress-nginx get pods -o name | grep  "ingress-nginx-controller")` command and look for this line `Host Ports:    80/TCP, 443/TCP, 8443/TCP`


**Check**

```text hl_lines="1 8" linenums="1"
curl -ikI https://172.16.1.70
HTTP/2 404 
date: Mon, 11 Oct 2021 10:29:13 GMT
content-type: text/html
content-length: 146
strict-transport-security: max-age=15724800; includeSubDomains

curl -ikI http://172.16.1.70
HTTP/1.1 404 Not Found
Date: Mon, 11 Oct 2021 10:29:16 GMT
Content-Type: text/html
Content-Length: 146
Connection: keep-alive
```

#### Deploy An Application And Create Service And Ingress For It

For demonstration we deploy a Ghost (blog) instance.

```bash
# kubectl create deployment ghost-test --image=ghost:latest
kubectl create deployment nginx-test --image=nginx:latest
```

!!! note
    Without explicitly specifying the namespace the pod will be created in the `default` namespace.

At this point we have a POD running, but we could not access it. First we need to create a `Service` object.

```bash
#kubectl create service clusterip ghost-test --tcp=2368:2368
kubectl create service clusterip nginx-test --tcp=80:80
```

!!! important
    Use the same name as the Deployment (ghost-test)! This will create the appropiate selector.

**Check the Service:**

```bash title="Command"
kubectl describe svc nginx-test
```
```text title="Output"
Name:              nginx-test
Namespace:         default
Labels:            app=nginx-test
Annotations:       <none>
Selector:          app=nginx-test
Type:              ClusterIP
IP Family Policy:  SingleStack
IP Families:       IPv4
IP:                10.22.103.28
IPs:               10.22.103.28
Port:              80-80  80/TCP
TargetPort:        80/TCP
Endpoints:         10.32.0.5:80
Session Affinity:  None
Events:            <none>
```


The most important thing here is the Endpoints:

```plain
Endpoints:          10.32.0.5:80
```

The IP address should point to the IP address of the Ghost POD:

```bash title="Command"
kubectl get pods -o wide
```
```text title="Output"
NAME                          READY   STATUS    RESTARTS   AGE   IP          NODE        NOMINATED NODE   READINESS GATES
nginx-test-5f4c58bccc-l5p9s   1/1     Running            0              82s     10.32.0.5   singlek8s   <none>           <none>
```


**The last step is to create the `Ingress` object.**

The `yaml` file:
```yaml
cat <<EOF>nginx-ingress.yaml
kind: Ingress
apiVersion: networking.k8s.io/v1
metadata:
  name: nginx-web
  namespace: default
spec:
  ingressClassName: nginx
  rules:
  - host: nginx-test.example.local
    http:
      paths:
      - pathType: ImplementationSpecific
        backend:
          service:
            name: nginx-test
            port:
              number: 80
EOF
```

Apply the yaml:

```bash
kubectl apply -f nginx-ingress.yaml
```

**Check the ingress**

```bash title="Command"
kubectl describe ingress nginx-web 
```
```text title="Ouptut"
Name:             nginx-web
Labels:           <none>
Namespace:        default
Address:
Ingress Class:    nginx
Default backend:  <default>
Rules:
  Host                      Path  Backends
  ----                      ----  --------
  nginx-test.example.local
                               nginx-test:80 (10.32.0.5:80)
Annotations:                <none>
Events:
  Type    Reason  Age                    From                      Message
  ----    ------  ----                   ----                      -------
  Normal  Sync    2m26s (x3 over 4m19s)  nginx-ingress-controller  Scheduled for sync
```  

**Check With `curl`**

```bash
curl  -H  'Host: nginx-test.example.local' http://172.16.1.70
```

#### DNS Entries

The above example works only if you overwrite the HTTP Host header with `'Host: ghost-test.example.local'`. This is because the `ghost-test.example.local` domain name does not exist. At this point we have to decide how to manage the DNS. The Kubernetes Igress works the best if we have a wildcard DNS entry. I don't want to get deep insude the DNS problem, but give you some tips:

* If your home router support static DNS entries you can define one, for example: `*.k8s.test.local`. My **Mikrotik** router has this function, so I can easily create a local wildcard DNS. Example `/ip dns static add address=172.16.1.214 regexp=.k8s-test.loc`
* You can use your existing domain, or buy a new one. For example I have vinczejanos.info domain registered at Godaddy. I can add a wildcard DNS record which points to the IP address of the Kubernetes machine. (`*.local.k8s.vinczejanos.info`) Be aware that this can be a security risk, everybody on the public Internet can resolve this host name, and it points to a private IP address.
* You can set up your own DNS server. Maybe the easiest way is the DNSMasq, but Bind9 can be also a good alternative. (Bind maybe a bit robust for this purpose.) In this case you have to configure all of your clients to use the new DNS server. 
* Since this is only a demo environment, a suitable solution can be to use your `hosts` file, but keep in mind that hosts file doesn't support wildcards, so you have to specify all host names one-by-one. The hosts file must be updated on all the host from where you want to access your Kubernetes Cluster.

??? example
    Hosts file location:

    * Linux: `/etc/hosts`
    * Windows: `Windows\System32\drivers\etc`  
    

Now, we have a fully functional Single Node Kubernetes Cluster. 

## Install Kubernetes Dashboard

Link: [https://kubernetes.io/docs/tasks/access-application-cluster/web-ui-dashboard/](https://kubernetes.io/docs/tasks/access-application-cluster/web-ui-dashboard/)

```bash
#kubectl apply -f https://raw.githubusercontent.com/kubernetes/dashboard/v2.3.1/aio/deploy/recommended.yaml
kubectl apply -f https://raw.githubusercontent.com/kubernetes/dashboard/v3.0.0-alpha0/charts/kubernetes-dashboard.yaml
```

Check if the pods are fine.

```bash title="Command"
kubectl -n kubernetes-dashboard get pods
```
```text title="Output"
NAME                                                    READY   STATUS    RESTARTS   AGE
kubernetes-dashboard-api-8586787f7-hmhmn                1/1     Running   0          35s
kubernetes-dashboard-metrics-scraper-6959b784dc-669wh   1/1     Running   0          35s
kubernetes-dashboard-web-6b6d549b4-8bwhm                1/1     Running   0          35s
```

### Create An Ingress

**Check The Service**

```bash title="Command"
kubectl -n kubernetes-dashboard describe  svc kubernetes-dashboard
```
```text title="Output"
Name:              kubernetes-dashboard-web
Namespace:         kubernetes-dashboard
Labels:            app.kubernetes.io/component=web
                   app.kubernetes.io/name=kubernetes-dashboard-web
                   app.kubernetes.io/part-of=kubernetes-dashboard
                   app.kubernetes.io/version=v1.0.0
Annotations:       <none>
Selector:          app.kubernetes.io/name=kubernetes-dashboard-web,app.kubernetes.io/part-of=kubernetes-dashboard
Type:              ClusterIP
IP Family Policy:  SingleStack
IP Families:       IPv4
IP:                10.22.216.140
IPs:               10.22.216.140
Port:              web  8000/TCP
TargetPort:        8000/TCP
Endpoints:         10.32.0.7:8000
Session Affinity:  None
Events:            <none>
```


**The Ingress `yaml`**

```yaml
cat <<EOF>kubernetes-dashboard-ingress.yaml
kind: Ingress
apiVersion: networking.k8s.io/v1
metadata:
  name: kubernetes-dashboard-v3
  namespace: kubernetes-dashboard
  labels:
    app.kubernetes.io/name: nginx-ingress
    app.kubernetes.io/part-of: kubernetes-dashboard
  annotations:
spec:
  ingressClassName: nginx
  tls:
    - hosts:
        - k8s-dashboard.vincze.work
      secretName: k8s-dashboardv3-certs
  rules:
    - host: dashboard.k8s-test.loc
      http:
        paths:
          - path: /
            pathType: Prefix
            backend:
              service:
                name: kubernetes-dashboard-web
                port:
                  name: web
          - path: /api
            pathType: Prefix
            backend:
              service:
                name: kubernetes-dashboard-api
                port:
                  name: api
EOF
```

Apply the ingress:

```bash
kubectl apply -f kubernetes-dashboard-ingress.yaml
```

Now I can access the Kubernetes Dashboard at [https://dashboard.k8s-test.loc](https://dashboard.k8s-test.loc)

### The Token

When you see the login screen, you are asked for the token or kubeconfig file. I choose the simpier way and use token.

**Create the token:**

```bash
kubectl apply -f - <<EOF
apiVersion: v1
kind: Secret
metadata:
  name: kubernetes-dashboard-token
  namespace: kubernetes-dashboard
  annotations:
    kubernetes.io/service-account.name: kubernetes-dashboard
type: kubernetes.io/service-account-token
EOF
```

**Get The Token**
```bash
kubectl -n kubernetes-dashboard get secret/kubernetes-dashboard-token -o json | jq -r '.data.token' | base64 -d ;echo
```

### Fix Permission

You will see a lot of error message like this:

```log
namespaces is forbidden: User "system:serviceaccount:kubernetes-dashboard:kubernetes-dashboard" cannot list resource "namespaces" in API group "" at the cluster scope
```

**Screenshot:**

![Error](/assets/images/DeepinScreenshot_select-area_20211011165036.png)

I don't want to bother with roles and rolebindigns at this article. I want quick win, so edit the `kubernetes-dashboard` ClusterRole.

```bash
kubectl  edit  clusterrole kubernetes-dashboard
```

And modify:
```diff
 rules:
 - apiGroups:
-  - metrics.k8s.io
+  - '*'
   resources:
-  - pods
-  - nodes
+  - '*'
   verbs:
-  - get
-  - list
-  - watch
+  - '*'
+- nonResourceURLs:
+  - '*'
+  verbs:
+  - '*'
```

It should look like this (`kubectl  get clusterrole kubernetes-dashboard -o yaml`):
```yaml
apiVersion: rbac.authorization.k8s.io/v1
kind: ClusterRole
metadata:
  annotations:
    kubectl.kubernetes.io/last-applied-configuration: |
      {"apiVersion":"rbac.authorization.k8s.io/v1","kind":"ClusterRole","metadata":{"annotations":{},"labels":{"k8s-app":"kubernetes-dashboard"},"name":"kubernetes-dashboard"},"rules":[{"apiGroups":["metrics.k8s.io"],"resources":["pods","nodes"],"verbs":["get","list","watch"]}]}
  creationTimestamp: "2021-10-11T14:33:17Z"
  labels:
    k8s-app: kubernetes-dashboard
  name: kubernetes-dashboard
  resourceVersion: "15040"
  uid: 26495412-c50f-48fb-b3ce-448d42dff15b
rules:
- apiGroups:
  - '*'
  resources:
  - '*'
  verbs:
  - '*'
- nonResourceURLs:
  - '*'
  verbs:
  - '*'
```

!!! caution
    Do NOT do this in Production system! This way you give cluster-admin role to kubernetes-dashboard ServiceAccount. Everybody who knows the token can do anything with your Kubernetes cluster!

## CheatSheet

Finally I write here some command I'm using in daily basis.

#### List And Delete `Completed` PODS

  When a Job finishes it's work, the container is left as `Completed`. A lot of PODS in `Completed` statw can be disturbing, and they can be safely deleted.

List: 

```bash
kubectl get pods --all-namespaces --field-selector=status.phase=Succeeded
```

Delete:

```bash
kubectl delete pods --all-namespaces --field-selector=status.phase=Succeeded
```

#### Check Container Logs

```bash
# List PODS
kubectl -n default get pods

# Show the logs:
kubectl -n default logs ghost-test-66846549b5-qgcl8

# Or follow the logs:
kubectl -n default logs ghost-test-66846549b5-qgcl8 -f

# Or follow without showing only the logs written from now.
kubectl -n default logs ghost-test-66846549b5-qgcl8 -f --tail=0
```

#### Get Into The Container

Sometimes you need to see what happens inside a container. In this case you can get a shell inside the container.

```bash
kubectl -n default exec -it ghost-test-66846549b5-qgcl8 -- /bin/bash

# Or if no bash installed, you can try sh
kubectl -n default exec -it ghost-test-66846549b5-qgcl8 -- /bin/sh
```          

#### Pending PODS (nginx ingress)

Example:
```plain
NAME                                        READY   STATUS    RESTARTS   AGE
ingress-nginx-controller-5f7bb7476d-2nhqc   0/1     Pending   0          4s
ingress-nginx-controller-745c7c9f6c-m9q5q   1/1     Running   2          128m
```

Events:
```bash title="Command"
kubectl -n ingress-nginx get events
```
```text title="Output"
LAST SEEN   TYPE      REASON              OBJECT                                           MESSAGE
34s         Warning   FailedScheduling    pod/ingress-nginx-controller-5f7bb7476d-2nhqc    0/1 nodes are available: 1 node(s) didn't have free ports for the requested pod ports.
35s         Normal    SuccessfulCreate    replicaset/ingress-nginx-controller-5f7bb7476d   Created pod: ingress-nginx-controller-5f7bb7476d-2nhqc
36s         Normal    ScalingReplicaSet   deployment/ingress-nginx-controller              Scaled up replica set ingress-nginx-controller-5f7bb7476d to 1
```

The problem: `0/1 nodes are available: 1 node(s) didn't have free ports for the requested pod ports.`

NGinx Ingress Controller (the POD) uses hostPort, and RollingUpdate strategy. This means that Kubernetes tries to start a new instance, and after the new instance is Running and healthy stop the "old" one. But in this case it is not possible because two container can not bind the same ports (80,443). 

The easiest way to solve this is to delete the old pod manually. ( `ingress-nginx-controller-745c7c9f6c-m9q5q` )

```bash
kubectl -n ingress-nginx delete pod ingress-nginx-controller-745c7c9f6c-m9q5q
```

Permanent solution could be changing the strategy to ReCreate.

```bash
kubectl patch deployment/ingress-nginx-controller -n ingress-nginx  -p '{ "spec": { "strategy":{ "$retainKeys": ["type"],"type": "Recreate"}}}'
```

Show pretty print Json
```json
{
  "spec": {
    "strategy": {
      "$retainKeys": [
        "type"
      ],
      "type": "Recreate"
    }
  }
}
```

Reference: 

* [Use strategic merge patch to update a Deployment using the retainKeys strategy](https://kubernetes.io/docs/tasks/manage-kubernetes-objects/update-api-object-kubectl-patch/#use-strategic-merge-patch-to-update-a-deployment-using-the-retainkeys-strategy)
* [https://blog.container-solutions.com/kubernetes-deployment-strategies](https://blog.container-solutions.com/kubernetes-deployment-strategies)


#### Get All / All Namespaces

```bash
kubectl -n ingress-nginx get all

# Get all ingress in the cluster

kubectl get ingress --all-namespaces -o wide
```

#### Print Join Command (Add Worker Node)

```bash
kubeadm token create --print-join-command
```

#### Get All Resources / Get Help

```bash
kubectl api-resources

# Explain

kubectl explain pod
kubectl explain pod.spec
kubectl explain pod.spec.tolerations
```

#### Copy Dir / File From Container

```bash
# File 

kubectl -n default cp ghost-test-66846549b5-qgcl8:/var/lib/ghost/config.production.json  config.production.json

# Directory
kubectl -n default cp ghost-test-66846549b5-qgcl8:/var/lib/ghost .
```

??? warning
    `kubectl -n default cp ghost-test-66846549b5-qgcl8:/var/lib/ghost .` <-- This will copy the conents of the directory. If you want to create the 'ghost' directory on the destination use: 

    `kubectl -n default cp ghost-test-66846549b5-qgcl8:/var/lib/ghost ghost`
