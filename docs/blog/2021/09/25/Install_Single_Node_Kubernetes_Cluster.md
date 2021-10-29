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

* Change sudoers file:

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

Kubernetes will leave Docker support so we will user Containerd as container runtime. 

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
curl -fsSL https://download.docker.com/linux/debian/gpg | sudo gpg --dearmor -o /usr/share/keyrings/docker-archive-keyring.gpg

echo \
  "deb [arch=$(dpkg --print-architecture) signed-by=/usr/share/keyrings/docker-archive-keyring.gpg] https://download.docker.com/linux/debian \
  $(lsb_release -cs) stable" | sudo tee /etc/apt/sources.list.d/docker.list > /dev/null
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
cat <<EOF | sudo tee /etc/modules-load.d/containerd.conf
overlay
br_netfilter
EOF
```

```bash
modprobe overlay
modprobe br_netfilter
```

```bash
cat <<EOF | sudo tee /etc/sysctl.d/99-kubernetes-cri.conf
net.bridge.bridge-nf-call-iptables  = 1
net.ipv4.ip_forward                 = 1
net.bridge.bridge-nf-call-ip6tables = 1
EOF

sudo sysctl --system

sudo mkdir -p /etc/containerd
containerd config default | sudo tee /etc/containerd/config.toml


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

<pre class="command-line" data-user="root" data-host="mkdocs" data-output="2"><code class="language-bash">crictl ps
FATA[0010] failed to connect: failed to connect: context deadline exceeded </code></pre>

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
cat <<EOF | sudo tee /etc/modules-load.d/k8s.conf
br_netfilter
EOF

cat <<EOF | sudo tee /etc/sysctl.d/k8s.conf
net.bridge.bridge-nf-call-ip6tables = 1
net.bridge.bridge-nf-call-iptables = 1
EOF
sudo sysctl --system
```

```bash
apt-get update
apt-get install -y apt-transport-https ca-certificates curl

curl -fsSLo /usr/share/keyrings/kubernetes-archive-keyring.gpg https://packages.cloud.google.com/apt/doc/apt-key.gpg
echo "deb [signed-by=/usr/share/keyrings/kubernetes-archive-keyring.gpg] https://apt.kubernetes.io/ kubernetes-xenial main" |  tee /etc/apt/sources.list.d/kubernetes.list

sudo apt-get update
```

Now we do some extra steps before installing the kubeadm. In the world of Kubernetes it is important to install the same version of kubeadm kubelet and kubectl. So fist we check the avaiable versions:

<pre class="command-line" data-user="root" data-host="mkdocs" data-output="2-10"><code class="language-bash">apt-cache madison kubeadm | egrep '(1.22|1.21)'
   kubeadm |  1.22.2-00 | https://apt.kubernetes.io kubernetes-xenial/main amd64 Packages
   kubeadm |  1.22.1-00 | https://apt.kubernetes.io kubernetes-xenial/main amd64 Packages
   kubeadm |  1.22.0-00 | https://apt.kubernetes.io kubernetes-xenial/main amd64 Packages
   kubeadm |  1.21.5-00 | https://apt.kubernetes.io kubernetes-xenial/main amd64 Packages
   kubeadm |  1.21.4-00 | https://apt.kubernetes.io kubernetes-xenial/main amd64 Packages
   kubeadm |  1.21.3-00 | https://apt.kubernetes.io kubernetes-xenial/main amd64 Packages
   kubeadm |  1.21.2-00 | https://apt.kubernetes.io kubernetes-xenial/main amd64 Packages
   kubeadm |  1.21.1-00 | https://apt.kubernetes.io kubernetes-xenial/main amd64 Packages
   kubeadm |  1.21.0-00 | https://apt.kubernetes.io kubernetes-xenial/main amd64 Packages</code></pre>


We won't install the latest version in order to be able to show you an update process as well.

```bash
apt-get install -y kubelet=1.21.5-00 kubeadm=1.21.5-00 kubectl=1.21.5-00
apt-mark hold kubelet kubeadm kubectl
```

!!! info
    We don't want to update kubeadm, kubeclt and kubelet with system (os) updates (apt-get update & upgrade). Kubernetes update has its own process. Always be careful when update you base system, and never update these packages alongside with the underlying os.

**Check the installed version**
<pre class="command-line" data-user="root" data-host="mkdocs" data-output="2-11"><code class="language-bash">kubeadm version -o yaml
clientVersion:
  buildDate: "2021-09-15T21:09:27Z"
  compiler: gc
  gitCommit: aea7bbadd2fc0cd689de94a54e5b7b758869d691
  gitTreeState: clean
  gitVersion: v1.21.5
  goVersion: go1.16.8
  major: "1"
  minor: "21"
  platform: linux/amd64</code></pre>


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

<pre class="command-line" data-user="kube" data-host="kube-test" data-output="5-74"><code class="language-bash">kubeadm init \
--cri-socket /var/run/containerd/containerd.sock \
--service-cidr 10.22.0.0/16 \
--pod-network-cidr 10.23.0.0/16
I1011 10:54:59.868163    6330 version.go:254] remote version is much newer: v1.22.2; falling back to: stable-1.21
[init] Using Kubernetes version: v1.21.5
[preflight] Running pre-flight checks
[preflight] Pulling images required for setting up a Kubernetes cluster
[preflight] This might take a minute or two, depending on the speed of your internet connection
[preflight] You can also perform this action in beforehand using 'kubeadm config images pull'
[certs] Using certificateDir folder "/etc/kubernetes/pki"
[certs] Generating "ca" certificate and key
[certs] Generating "apiserver" certificate and key
[certs] apiserver serving cert is signed for DNS names [kube-test kubernetes kubernetes.default kubernetes.default.svc kubernetes.default.svc.cluster.local] and IPs [10.22.0.1 172.16.1.214]
[certs] Generating "apiserver-kubelet-client" certificate and key
[certs] Generating "front-proxy-ca" certificate and key
[certs] Generating "front-proxy-client" certificate and key
[certs] Generating "etcd/ca" certificate and key
[certs] Generating "etcd/server" certificate and key
[certs] etcd/server serving cert is signed for DNS names [kube-test localhost] and IPs [172.16.1.214 127.0.0.1 ::1]
[certs] Generating "etcd/peer" certificate and key
[certs] etcd/peer serving cert is signed for DNS names [kube-test localhost] and IPs [172.16.1.214 127.0.0.1 ::1]
[certs] Generating "etcd/healthcheck-client" certificate and key
[certs] Generating "apiserver-etcd-client" certificate and key
[certs] Generating "sa" key and public key
[kubeconfig] Using kubeconfig folder "/etc/kubernetes"
[kubeconfig] Writing "admin.conf" kubeconfig file
[kubeconfig] Writing "kubelet.conf" kubeconfig file
[kubeconfig] Writing "controller-manager.conf" kubeconfig file
[kubeconfig] Writing "scheduler.conf" kubeconfig file
[kubelet-start] Writing kubelet environment file with flags to file "/var/lib/kubelet/kubeadm-flags.env"
[kubelet-start] Writing kubelet configuration to file "/var/lib/kubelet/config.yaml"
[kubelet-start] Starting the kubelet
[control-plane] Using manifest folder "/etc/kubernetes/manifests"
[control-plane] Creating static Pod manifest for "kube-apiserver"
[control-plane] Creating static Pod manifest for "kube-controller-manager"
[control-plane] Creating static Pod manifest for "kube-scheduler"
[etcd] Creating static Pod manifest for local etcd in "/etc/kubernetes/manifests"
[wait-control-plane] Waiting for the kubelet to boot up the control plane as static Pods from directory "/etc/kubernetes/manifests". This can take up to 4m0s
[kubelet-check] Initial timeout of 40s passed.
[apiclient] All control plane components are healthy after 42.005098 seconds
[upload-config] Storing the configuration used in ConfigMap "kubeadm-config" in the "kube-system" Namespace
[kubelet] Creating a ConfigMap "kubelet-config-1.21" in namespace kube-system with the configuration for the kubelets in the cluster
[upload-certs] Skipping phase. Please see --upload-certs
[mark-control-plane] Marking the node kube-test as control-plane by adding the labels: [node-role.kubernetes.io/master(deprecated) node-role.kubernetes.io/control-plane node.kubernetes.io/exclude-from-external-load-balancers]
[mark-control-plane] Marking the node kube-test as control-plane by adding the taints [node-role.kubernetes.io/master:NoSchedule]
[bootstrap-token] Using token: gvcye3.n7xemwaq8a94t8bs
[bootstrap-token] Configuring bootstrap tokens, cluster-info ConfigMap, RBAC Roles
[bootstrap-token] configured RBAC rules to allow Node Bootstrap tokens to get nodes
[bootstrap-token] configured RBAC rules to allow Node Bootstrap tokens to post CSRs in order for nodes to get long term certificate credentials
[bootstrap-token] configured RBAC rules to allow the csrapprover controller automatically approve CSRs from a Node Bootstrap Token
[bootstrap-token] configured RBAC rules to allow certificate rotation for all node client certificates in the cluster
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

kubeadm join 172.16.1.214:6443 --token gvcye3.n7xemwaq8a94t8bs \
  --discovery-token-ca-cert-hash sha256:bf86bed07219b08acaab0dc5451b3c4ddfd550a5b4b6295d5594758e693cf7e9 </code></pre>

Beleve or not our Single node Kubernetes cluster is almost ready. :)

Check it:

```bash
mkdir -p $HOME/.kube
sudo cp -i /etc/kubernetes/admin.conf $HOME/.kube/config
sudo chown $(id -u):$(id -g) $HOME/.kube/config

kubectl get nodes -o wide
```

Output looks like this:
```plain
NAME        STATUS     ROLES                  AGE     VERSION   INTERNAL-IP    EXTERNAL-IP   OS-IMAGE                         KERNEL-VERSION   CONTAINER-RUNTIME
kube-test   NotReady   control-plane,master   5m26s   v1.21.5   172.16.1.214   <none>        Debian GNU/Linux 11 (bullseye)   5.10.0-9-amd64   containerd://1.4.11
```

It is beutiful, isn't it?


### Why my node is in `NotReady` state?

I can say that this behavior is normal in case of newly installed Kubernetes cluster. Check the reaseon:


<pre class="command-line" data-user="kube" data-host="kube-test" data-output="2-9"><code class="language-bash">kubectl get pods --all-namespaces -o wide
NAMESPACE     NAME                                READY   STATUS    RESTARTS   AGE     IP             NODE        NOMINATED NODE   READINESS GATES
kube-system   coredns-558bd4d5db-8tzmf            0/1     Pending   0          9m42s   <none>         <none>      <none>           <none>
kube-system   coredns-558bd4d5db-l6gtq            0/1     Pending   0          9m42s   <none>         <none>      <none>           <none>
kube-system   etcd-kube-test                      1/1     Running   0          10m     172.16.1.214   kube-test   <none>           <none>
kube-system   kube-apiserver-kube-test            1/1     Running   0          9m49s   172.16.1.214   kube-test   <none>           <none>
kube-system   kube-controller-manager-kube-test   1/1     Running   0          9m57s   172.16.1.214   kube-test   <none>           <none>
kube-system   kube-proxy-nhm2h                    1/1     Running   0          9m43s   172.16.1.214   kube-test   <none>           <none>
kube-system   kube-scheduler-kube-test            1/1     Running   0          9m58s   172.16.1.214   kube-test   <none>           <none></code></pre>

You can see that the coredns pods are in pending state. These pods are responsible for internal DNS queries inside the Cluster Network. What should be the problem? We don't have any network plugin installed in the cluster....

Links: 

 * [https://kubernetes.io/docs/concepts/extend-kubernetes/compute-storage-net/network-plugins/](https://kubernetes.io/docs/concepts/extend-kubernetes/compute-storage-net/network-plugins/)
 * [https://kubevious.io/blog/post/comparing-kubernetes-container-network-interface-cni-providers](https://kubevious.io/blog/post/comparing-kubernetes-container-network-interface-cni-providers)

As you can see that there are a lot of varions of network plugins. For this little home environment I chose weave: [https://www.weave.works/docs/net/latest/kubernetes/kube-addon/#install](https://www.weave.works/docs/net/latest/kubernetes/kube-addon/#install)

It is really simple to install, can be achieved with only one command:

<pre class="command-line" data-user="kube" data-host="kube-test" data-output="2-7"><code class="language-bash">kubectl apply -f "https://cloud.weave.works/k8s/net?k8s-version=$(kubectl version | base64 | tr -d '\n')"
serviceaccount/weave-net created
clusterrole.rbac.authorization.k8s.io/weave-net created
clusterrolebinding.rbac.authorization.k8s.io/weave-net created
role.rbac.authorization.k8s.io/weave-net created
rolebinding.rbac.authorization.k8s.io/weave-net created
daemonset.apps/weave-net created</code></pre>

Check again the cluster:

<pre class="command-line" data-user="kube" data-host="kube-test" data-output="2-10, 12-13"><code class="language-bash">kubectl get pods --all-namespaces -o wide
NAMESPACE     NAME                                READY   STATUS    RESTARTS   AGE     IP             NODE        NOMINATED NODE   READINESS GATES
kube-system   coredns-558bd4d5db-8tzmf            1/1     Running   0          18m     10.32.0.3      kube-test   <none>           <none>
kube-system   coredns-558bd4d5db-l6gtq            1/1     Running   0          18m     10.32.0.2      kube-test   <none>           <none>
kube-system   etcd-kube-test                      1/1     Running   0          18m     172.16.1.214   kube-test   <none>           <none>
kube-system   kube-apiserver-kube-test            1/1     Running   0          18m     172.16.1.214   kube-test   <none>           <none>
kube-system   kube-controller-manager-kube-test   1/1     Running   0          18m     172.16.1.214   kube-test   <none>           <none>
kube-system   kube-proxy-nhm2h                    1/1     Running   0          18m     172.16.1.214   kube-test   <none>           <none>
kube-system   kube-scheduler-kube-test            1/1     Running   0          18m     172.16.1.214   kube-test   <none>           <none>
kube-system   weave-net-l8xkh                     2/2     Running   1          2m22s   172.16.1.214   kube-test   <none>           <none>
kubectl get nodes -o wide
NAME        STATUS   ROLES                  AGE   VERSION   INTERNAL-IP    EXTERNAL-IP   OS-IMAGE                         KERNEL-VERSION   CONTAINER-RUNTIME
kube-test   Ready    control-plane,master   18m   v1.21.5   172.16.1.214   <none>        Debian GNU/Linux 11 (bullseye)   5.10.0-9-amd64   containerd://1.4.11</code></pre>

Now we really have a working single node Kubernetes cluster. 

Before jump to the next section take a look at the node role: `control-plane,master`  
This means the only node we hava acts as control-plane and master, since we won't have any other worker nodes this nodes must have worker role as well:

```bash
kubectl label node kube-test node-role.kubernetes.io/worker=
```

But this is not enoguh because the master nodes have taint by default: [https://kubernetes.io/docs/concepts/scheduling-eviction/taint-and-toleration/](https://kubernetes.io/docs/concepts/scheduling-eviction/taint-and-toleration/)

You can check the taint with `kubectl get node kube-test -o yaml` command:

```plain
...
  taints:
  - effect: NoSchedule
    key: node-role.kubernetes.io/maste
```

Remove this taint:
```bash
kubectl taint nodes kube-test node-role.kubernetes.io/master=:NoSchedule-
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

<pre class="command-line" data-user="kube" data-host="kube-test" data-output="2-9"><code class="language-bash">kubectl -n kube-system get pods
NAME                                READY   STATUS    RESTARTS   AGE
coredns-558bd4d5db-l6gtq            1/1     Running   0          32m
etcd-kube-test                      1/1     Running   0          33m
kube-apiserver-kube-test            1/1     Running   0          33m
kube-controller-manager-kube-test   1/1     Running   0          33m
kube-proxy-nhm2h                    1/1     Running   0          32m
kube-scheduler-kube-test            1/1     Running   0          33m
weave-net-l8xkh                     2/2     Running   1          16m</code></pre>



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
<pre class="command-line" data-user="kube" data-host="kube-test" data-output="2-10"><code class="language-bash">kubectl -n kube-system top pods
NAME                                CPU(cores)   MEMORY(bytes)   
coredns-558bd4d5db-l6gtq            3m           18Mi            
etcd-kube-test                      16m          41Mi            
kube-apiserver-kube-test            76m          333Mi           
kube-controller-manager-kube-test   12m          60Mi            
kube-proxy-nhm2h                    1m           20Mi            
kube-scheduler-kube-test            4m           25Mi            
metrics-server-6775f684f6-gxpcz     6m           18Mi            
weave-net-l8xkh                     2m           61Mi</code></pre>


### Install (Nginx) Ingress Controller

Maybe this it the most interesting part of this article as for now. You can chose from various ingress controller to install. Check the official documentation for more details:

* [https://kubernetes.io/docs/concepts/services-networking/ingress-controllers/](https://kubernetes.io/docs/concepts/services-networking/ingress-controllers/)

For this demo I choose the NGinx Ingress Controller. I think it is easy to install and maybe some of your already have experience with NGinx on bare metal. I can't tell you any other news than checking the official docs: [https://kubernetes.github.io/ingress-nginx/deploy/](https://kubernetes.github.io/ingress-nginx/deploy/) 

We are going to follow the Bare Metal installation: [https://kubernetes.github.io/ingress-nginx/deploy/#bare-metal](https://kubernetes.github.io/ingress-nginx/deploy/#bare-metal)

```bash
kubectl apply -f https://raw.githubusercontent.com/kubernetes/ingress-nginx/controller-v0.49.3/deploy/static/provider/baremetal/deploy.yaml

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

<pre class="command-line" data-user="kube" data-host="kube-test" data-output="2-4"><code class="language-bash">kubectl -n ingress-nginx get services
NAME                                 TYPE        CLUSTER-IP    EXTERNAL-IP   PORT(S)                      AGE
ingress-nginx-controller             NodePort    10.22.0.78    <none>        80:30016/TCP,443:32242/TCP   104s
ingress-nginx-controller-admission   ClusterIP   10.22.0.242   <none>        443/TCP                      104s</code></pre>

!!! warning
    Please read very carefully this documentation: [https://kubernetes.github.io/ingress-nginx/deploy/baremetal/](https://kubernetes.github.io/ingress-nginx/deploy/baremetal/)

This NodePort means that our NGinx ingress controller is accessible on every node in the cluster on `30016/TCP` and `32242/TCP`. It is OK if you planning to use these ports to access the applications inside the cluster.  
Or you can install a reverse proxy somewehere in you physical network. This can be the Kubernetes host itself. Configuring a reverse proxy could be a pain, and it is not the subject of this article.

**Check**

To check the NGinx Ingress Controller you should use another machine in your network. Most of the time I use curl to check if web server is running or not, but you can use your browser instead.

<pre class="command-line" data-user="kube" data-host="kube-test" data-output="2-15,17-30"><code class="language-bash">curl -i http://172.16.1.214:30016 
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

curl -ik https://172.16.1.214:32242
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
</html></code></pre>


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

<pre class="command-line" data-user="kube" data-host="kube-test" data-output="2-7,8-13"><code class="language-bash">curl -ikI https://172.16.1.214
HTTP/2 404 
date: Mon, 11 Oct 2021 10:29:13 GMT
content-type: text/html
content-length: 146
strict-transport-security: max-age=15724800; includeSubDomains

curl -ikI http://172.16.1.214
HTTP/1.1 404 Not Found
Date: Mon, 11 Oct 2021 10:29:16 GMT
Content-Type: text/html
Content-Length: 146
Connection: keep-alive</code></pre>

#### Deploy An Application And Create Service And Ingress For It

For demonstration we deploy a Ghost (blog) instance.

```bash
kubectl create deployment ghost-test --image=ghost:latest
```

!!! note
    Without explicitly specifying the namespace the pod will be created in the `default` namespace.

At this point we have a POD running, but we could not access it. First we need to create a `Service` object.

```bash
kubectl create service clusterip ghost-test --tcp=2368:2368
```

!!! important
    Use the same name as the Deployment (ghost-test)! This will create the appropiate selector.

**Check the Service:**

<pre class="command-line" data-user="kube" data-host="kube-test" data-output="2-16"><code class="language-bash">kubectl describe service ghost-test
Name:              ghost-test
Namespace:         default
Labels:            app=ghost-test
Annotations:       <none>
Selector:          app=ghost-test
Type:              ClusterIP
IP Family Policy:  SingleStack
IP Families:       IPv4
IP:                10.22.0.184
IPs:               10.22.0.184
Port:              2368-2368  2368/TCP
TargetPort:        2368/TCP
Endpoints:         10.32.0.3:2368
Session Affinity:  None
Events:            <none></code></pre>


The most important thing here is the Endpoints:

```plain
Endpoints:         10.32.0.3:2368
```

The IP address should point to the IP address of the Ghost POD:

<pre class="command-line" data-user="kube" data-host="kube-test" data-output="2,3"><code class="language-bash">get pods -o wide
NAME                          READY   STATUS    RESTARTS   AGE   IP          NODE        NOMINATED NODE   READINESS GATES
ghost-test-66846549b5-8z6mj   1/1     Running   0          15m   10.32.0.3   kube-test   <none>           <none></code></pre>


**The last step is to create the `Ingress` object.**

The `yaml` file:
```yaml
cat <<EOF>ghost-ingress.yaml
kind: Ingress
apiVersion: networking.k8s.io/v1
metadata:
  name: ghost-web
  namespace: default
spec:
  rules:
  - host: ghost-test.example.local
    http:
      paths:
      - pathType: ImplementationSpecific
        backend:
          service:
            name: ghost-test
            port:
              number: 2368
EOF
```

Apply the yaml:

```bash
kubectl apply -f ghost-ingress.yaml
```

**Check the ingress**

<pre class="command-line" data-user="kube" data-host="kube-test" data-output="2-16"><code class="language-bash">kubectl describe ingress ghost-web 
Name:             ghost-web
Namespace:        default
Address:          172.16.1.214
Default backend:  default-http-backend:80 (<error: endpoints "default-http-backend" not found>)
Rules:
  Host                     Path  Backends
  ----                     ----  --------
  ghost-test.k8s-test.loc  
                              ghost-test:2368 (10.32.0.4:2368)
Annotations:               <none>
Events:
  Type    Reason  Age                   From                      Message
  ----    ------  ----                  ----                      -------
  Normal  Sync    3m19s                 nginx-ingress-controller  Scheduled for sync
  Normal  Sync    104s (x2 over 2m55s)  nginx-ingress-controller  Scheduled for sync</code></pre>

**Check With `curl`**

```bash
curl  -H  'Host: ghost-test.example.local' http://172.16.1.212
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
kubectl apply -f https://raw.githubusercontent.com/kubernetes/dashboard/v2.3.1/aio/deploy/recommended.yaml
```

Check if the pods are fine.

<pre class="command-line" data-user="kube" data-host="kube-test" data-output="2-4"><code class="language-bash">kubectl -n kubernetes-dashboard get pods
NAME                                         READY   STATUS    RESTARTS   AGE
dashboard-metrics-scraper-856586f554-pgq5l   1/1     Running   0          47s
kubernetes-dashboard-67484c44f6-vjlkw        1/1     Running   0          47s</code></pre>

### Create An Ingress

**Check The Service**

<pre class="command-line" data-user="kube" data-host="kube-test" data-output="2-17"><code class="language-bash">kubectl -n kubernetes-dashboard describe  svc kubernetes-dashboard
Name:              kubernetes-dashboard
Namespace:         kubernetes-dashboard
Labels:            k8s-app=kubernetes-dashboard
Annotations:       <none>
Selector:          k8s-app=kubernetes-dashboard
Type:              ClusterIP
IP Family Policy:  SingleStack
IP Families:       IPv4
IP:                10.22.0.56
IPs:               10.22.0.56
Port:              <unset>  443/TCP
TargetPort:        8443/TCP
Endpoints:         10.32.0.5:8443
Session Affinity:  None
Events:            <none></code></pre>


**The Ingress `yaml`**

```yaml
cat <<EOF>kubernetes-dashboard-ingress.yaml
apiVersion: networking.k8s.io/v1
kind: Ingress
metadata:
  name: kubernetes-dashboard
  namespace: kubernetes-dashboard
  annotations:
    nginx.ingress.kubernetes.io/backend-protocol: HTTPS
spec:
  rules:
    - host: dashboard.k8s-test.loc
      http:
        paths:
          - path: /
            pathType: Prefix
            backend:
              service:
                name: kubernetes-dashboard
                port:
                  number: 443
EOF
```

Apply the ingress:

```bash
kubectl apply -f kubernetes-dashboard-ingress.yaml
```

Now I can access the Kubernetes Dashboard at [https://dashboard.k8s-test.loc](https://dashboard.k8s-test.loc)

### Get The Thoken

When you see the login screen, you are asked for the token or kubeconfig file. I choose the simpier way and use token.

First obtain the name of the secret:
<pre class="command-line" data-user="kube" data-host="kube-test" data-output="2-7"><code class="language-bash">kubectl -n kubernetes-dashboard get secrets
NAME                               TYPE                                  DATA   AGE
default-token-v85k8                kubernetes.io/service-account-token   3      14m
kubernetes-dashboard-certs         Opaque                                0      14m
kubernetes-dashboard-csrf          Opaque                                1      14m
kubernetes-dashboard-key-holder    Opaque                                2      14m
kubernetes-dashboard-token-24jfb   kubernetes.io/service-account-token   3      14m</code></pre>

We need this: **kubernetes-dashboard-token-24jfb**

**Get the token:**

```bash
kubectl -n kubernetes-dashboard get secret kubernetes-dashboard-token-24jfb -o json | jq -r  '.data.token' | base64 -d ; echo 
```

### Fix Permission

You will see a lot of error message like this:

```log
namespaces is forbidden: User "system:serviceaccount:kubernetes-dashboard:kubernetes-dashboard" cannot list resource "namespaces" in API group "" at the cluster scope
```

**Screenshot:**

![Error](//assets/images/DeepinScreenshot_select-area_20211011165036.png)

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
<pre class="command-line" data-user="kube" data-host="kube-test" data-output="2-7"><code class="language-bash">kubectl -n ingress-nginx get events
LAST SEEN   TYPE      REASON              OBJECT                                           MESSAGE
34s         Warning   FailedScheduling    pod/ingress-nginx-controller-5f7bb7476d-2nhqc    0/1 nodes are available: 1 node(s) didn't have free ports for the requested pod ports.
35s         Normal    SuccessfulCreate    replicaset/ingress-nginx-controller-5f7bb7476d   Created pod: ingress-nginx-controller-5f7bb7476d-2nhqc
36s         Normal    ScalingReplicaSet   deployment/ingress-nginx-controller              Scaled up replica set ingress-nginx-controller-5f7bb7476d to 1</code></pre>

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
















































