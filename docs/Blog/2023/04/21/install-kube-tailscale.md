# Install Kubernetes Cluster Behind Tailscale VPN

!!! important
    UNFINISHED post!!!



## TL;DR

In this post we will install a **multi-master** Kubernetes cluster behind Tailscale VPN.
This scenario can be useful when:

- Your Kubernetes nodes are not in the same subnet. 
- You are building a home-lab system, and the nodes are behind two or more NAT-ted network, or even behind CGNAT.
- Your nodes are running in separate data centers, and don't want to publish API ports on the public internet. 
- You want to access your cluster only from private VPN network.
- You want extra security by encrypted connection between nodes.
- Or the mixture of above scenarios. 

**Why Tailscale VPN?**

You can use any other VPN solution like Wireguard, OpenVPN, IPSec, etc. But nowadays I think Tailscale is the easiest way to bring up a VPN network.
With a free registration you get 100 device, subnet routers, exit nodes, (Magic)DNS, and so many useful features. 

For more information check the following links:

- [TailScale](https://tailscale.com)
- [Tailscale Pricing](https://tailscale.com/pricing/)

But as I mentioned you can use any other VPN solution, personally I'm using Wireguard in my home-lab system.

!!! warning
    Tailscale assigns IP address from `100.64.0.0/10` range! [IP Address Assignment](https://tailscale.com/kb/1015/100.x-addresses/)
    If you are planning to use [Kube-OVN](https://www.kube-ovn.io) networking don't forget to change the CIDR, because Kube-OVN is also use this subnet!

## Infrastructure

As I mentioned we will deploy a multi-master Kubernetes cluster:

- 3 master|worker nodes, without worker nodes. Later additional worker nodes can be added to the cluster, but for the simplicity we won't deploy extra worker nodes.
- We need an additional TCP load balancer for the API requests. I prefer HAProxy for this purpose, because it is easy to set up and lightweight. 
    * For this lab I will deploy only one Load Balancer, but if you need HA solution, at least two Load Balancers are needed. This can be achieved by using Keppalived. Or you can use external load balancer like F5. But this demo is not about HA Load balancers, so it is just enough to have only one LB.

| Hostname        | Role                     | IP Address   | VPN IP Address   |
| :-------------- | :----------------------- | :----------- | :--------------- |
| kube02-m1       | Control Plane Node 1     | 172.16.1.77  | Later            |
| kube02-m2       | Control Plane Node 2     | 172.16.1.78  | Later            |
| kube02-m3       | Control Plane Node 3     | 172.16.1.79  | Later            |
| kube02-haproxy  | HAProxy Load Balancer    | 172.16.1.80  | Later            |
| ansible         | Ansible Host             | 172.16.0.252 | ---              |

!!! note
    You don't need the additional Ansible host, if you preparing the OS manually. 

!!! note
    You can use one of the kubernetes node for HAProxy, but in this case you need to configure either the HAProxy listen port or `--apiserver-bind-port` (kubadm init).


The nodes in this test environment are connected each other on the same subnet.

### Hardware

These nodes are completely identical both on hardware and OS level, running on Proxmox Virtualization platform with KVM.
- 2 CPU cores
- 2GB memory
- 32B system disk
- Debian OS
  - Debian GNU/Linux 11 (bullseye)
  - Kernel: `5.10.0-21-amd64`


## Preparing The OS

In this post I'm using **Ansible** to prepare the Debian OSes for Kubernetes installation.
I'm highly recommend to use some kind of automatization tool(s) or scirpt(s) to maintain your infrastructure, especially if you planning to have a bunch of nodes, not just a home-lab.
And if something goes wrong you can start it over in a minute.

### Ansible 

Just a quick overview about my Ansible configuration and variables.

#### `ansible.cfg`

```yaml title='<a href="https://raw.githubusercontent.com/jvincze84/jvincze84.github.io/master/docs/files/kube-ans-tailscale/ansible.cfg" target="_blank">Click Here For Raw Source</a>' linenums="1"
--8<-- "docs/files/kube-ans-tailscale/ansible.cfg"
```


#### `myvars.yml`

```yaml title='<a href="https://raw.githubusercontent.com/jvincze84/jvincze84.github.io/master/docs/files/kube-ans-tailscale/myvars.yml" target="_blank">Click Here For Raw Source</a>' linenums="1"
--8<-- "docs/files/kube-ans-tailscale/myvars.yml"
```

**Details:**

- `yq_url`: Yq binary URL. This version of yq will be installed on the hosts.
- `kube_version`: Here you can define which version of Kubernetes you want to install. (kubelet, kubeadm and kubectl)
- `common_packages`: These packages will be installed on the hosts. "Common packages" because usually I install these packages on my VMs, regardless of deploying Docker or Kubernetes. 
- `docker_packages`: Packages for installing Docker/Containerd engine.


#### `hosts`

```plain title='<a href="https://raw.githubusercontent.com/jvincze84/jvincze84.github.io/master/docs/files/kube-ans-tailscale/hosts" target="_blank">Click Here For Raw Source</a>' linenums="1"
--8<-- "docs/files/kube-ans-tailscale/hosts"
```


!!! important
    Ansible host must access the VMs over ssh. Before you run any of the playbooks please enable root login.
    For example: `sed -i -e 's/^#\(PermitRootLogin \).*/\1 yes/' /etc/ssh/sshd_config` and restart sshd daemon. 
    It is highly recommended to use dedicated ansible user (with sudo right) and ssh key authentication! 
    **And don't forget to accept ssh key by login to the remotes systems before run the playbooks.**
    If you are using other user than root, you may want to use `become: 'yes'` option it the plays.

### Update 

I usually start with updating the OS to the latest version, unless the application to be installed has strict requirements.

**playbook-upgrade-debian.yaml**

```yaml title='<a href="https://raw.githubusercontent.com/jvincze84/jvincze84.github.io/master/docs/files/kube-ans-tailscale/playbook-upgrade-debian.yaml" target="_blank">Click Here For Raw Source</a>' linenums="1"
--8<-- "docs/files/kube-ans-tailscale/playbook-upgrade-debian.yaml"
```


**task_allow_release_info_change.yaml**

```yaml title='<a href="https://raw.githubusercontent.com/jvincze84/jvincze84.github.io/master/docs/files/kube-ans-tailscale/task_allow_release_info_change.yaml" target="_blank">Click Here For Raw Source</a>' linenums="1"
--8<-- "docs/files/kube-ans-tailscale/task_allow_release_info_change.yaml"
```


**Run this playbook:**

```bash
ansible-playbook playbook-upgrade-debian.yaml
```

### Install Common Packages

**playbook-install-common-packages.yaml**

```yaml title='<a href="https://raw.githubusercontent.com/jvincze84/jvincze84.github.io/master/docs/files/kube-ans-tailscale/playbook-install-common-packages.yaml" target="_blank">Click Here For Raw Source</a>' linenums="1"
--8<-- "docs/files/kube-ans-tailscale/playbook-install-common-packages.yaml"
```


**Run this playbook:**

```bash
ansible-playbook playbook-install-common-packages.yaml
```

### Install Container Engine

**playbook-install-docker.yaml**

```yaml title='<a href="https://raw.githubusercontent.com/jvincze84/jvincze84.github.io/master/docs/files/kube-ans-tailscale/playbook-install-docker.yaml" target="_blank">Click Here For Raw Source</a>' linenums="1"
--8<-- "docs/files/kube-ans-tailscale/playbook-install-docker.yaml"
```

**Run this playbook:**

```bash
ansible-playbook playbook-install-docker.yaml
```

### Install Kubernetes Tools 

**playbook-install-kubernetes.yaml**

```yaml title='<a href="https://raw.githubusercontent.com/jvincze84/jvincze84.github.io/master/docs/files/kube-ans-tailscale/playbook-install-kubernetes.yaml" target="_blank">Click Here For Raw Source</a>' linenums="1"
--8<-- "docs/files/kube-ans-tailscale/playbook-install-kubernetes.yaml"
```

**Run this playbook:**

```bash
ansible-playbook playbook-install-kubernetes.yaml
```

Now we have 3 identical nodes which are waiting for us to install & configure Tailscale VPN and Kubernetes cluster.

Before we proceed, I would like to advise you some really useful links and tips. These are helpful especially if you are not familiar with Ansible and don't want to bother with that:

- Update OS: `apt-get update --allow-releaseinfo-change` && `apt-get upgrade`
- Common Packages: You can install all necessary packages with `apt-get install` command.
- [Install Container Engine](https://docs.docker.com/engine/install/debian/)
- [Install Tailscale](https://tailscale.com/download/linux)
- **Install Kubernetes:**
    * [container-runtimes](https://kubernetes.io/docs/setup/production-environment/container-runtimes/)
    * [install-kubeadm](https://kubernetes.io/docs/setup/production-environment/tools/kubeadm/install-kubeadm/)
    * [crictl](https://kubernetes.io/docs/tasks/debug/debug-cluster/crictl/#general-usage)
    * [crictl usage](https://github.com/kubernetes-sigs/cri-tools/blob/master/docs/crictl.md)

If you follow these links you should be able to install everything without Ansible.

## Tailscale VPN

I assume that Tailscale is successfully  installed on every node.
Before you begin please register a free account: [Tailscale](https://login.tailscale.com/start)

!!! info
    I recommend you to enable "[MagicDNS](https://login.tailscale.com/admin/dns)" on the Tailscale web interface. 

Run the following command on all 4 nodes (kube0-m[1,2,3] and kube02-haproxy):

```bash
tailscale up --accept-dns=true
```

Check if all your nodes have VPN IP address:

```plain
root@kube02-m3:~# tailscale status | grep kube02
100.124.70.97   kube02-m3            jvincze84@   linux   -
100.121.89.125  kube02-haproxy       jvincze84@   linux   -
100.122.123.2   kube02-m1            jvincze84@   linux   -
100.103.128.9   kube02-m2            jvincze84@   linux   -
```

**Try ping:**

```plain
root@kube02-m3:~# ping kube02-m1
PING kube02-m1.tailnet-a5cd.ts.net (100.122.123.2) 56(84) bytes of data.
64 bytes from kube02-m1.tailnet-a5cd.ts.net (100.122.123.2): icmp_seq=1 ttl=64 time=1.33 ms
64 bytes from kube02-m1.tailnet-a5cd.ts.net (100.122.123.2): icmp_seq=2 ttl=64 time=0.976 ms
^C
--- kube02-m1.tailnet-a5cd.ts.net ping statistics ---
2 packets transmitted, 2 received, 0% packet loss, time 1001ms
rtt min/avg/max/mdev = 0.976/1.151/1.327/0.175 ms

root@kube02-m3:~# ping kube02-m2
PING kube02-m2.tailnet-a5cd.ts.net (100.103.128.9) 56(84) bytes of data.
64 bytes from kube02-m2.tailnet-a5cd.ts.net (100.103.128.9): icmp_seq=1 ttl=64 time=1.49 ms
64 bytes from kube02-m2.tailnet-a5cd.ts.net (100.103.128.9): icmp_seq=2 ttl=64 time=1.06 ms
^C
--- kube02-m2.tailnet-a5cd.ts.net ping statistics ---
2 packets transmitted, 2 received, 0% packet loss, time 1000ms
rtt min/avg/max/mdev = 1.055/1.272/1.490/0.217 ms

root@kube02-m3:~# ping kube02-haproxy
PING kube02-haproxy.tailnet-a5cd.ts.net (100.121.89.125) 56(84) bytes of data.
64 bytes from kube02-haproxy.tailnet-a5cd.ts.net (100.121.89.125): icmp_seq=1 ttl=64 time=1.27 ms
^C
--- kube02-haproxy.tailnet-a5cd.ts.net ping statistics ---
1 packets transmitted, 1 received, 0% packet loss, time 0ms
rtt min/avg/max/mdev = 1.269/1.269/1.269/0.000 ms
```

It seems that everything is fine.

Now check `tailscale status` command again:

```plain
root@kube02-m3:~# tailscale status | grep kube02
100.124.70.97   kube02-m3            jvincze84@   linux   -
100.121.89.125  kube02-haproxy       jvincze84@   linux   active; direct 172.16.1.80:41641, tx 468 rx 348
100.122.123.2   kube02-m1            jvincze84@   linux   active; direct 172.16.1.77:41641, tx 724 rx 604
100.103.128.9   kube02-m2            jvincze84@   linux   active; direct 172.16.1.78:41641, tx 596 rx 476
```

After you connect to a host, the status command will show extra information: `active; direct 172.16.1.80:41641, tx 468 rx 348`

#### Updated IP Address Table

| Hostname        | Role                     | IP Address   | VPN IP Address     |
| :-------------- | :----------------------- | :----------- | :----------------- |
| kube02-m1       | Control Plane Node 1     | 172.16.1.77  | **100.122.123.2**  |
| kube02-m2       | Control Plane Node 2     | 172.16.1.78  | **100.103.128.9**  |
| kube02-m3       | Control Plane Node 3     | 172.16.1.79  | **100.124.70.97**  |
| kube02-haproxy  | HAProxy Load Balancer    | 172.16.1.80  | **100.121.89.125** |
| ansible         | Ansible Host             | 172.16.0.252 | ---                |

### (Optional) Disable Direct Access

This step is optional. I want to simulate the situation when the nodes are not sitting in the same subnet, and can talk to each other only over the Tailscale VPN.
This way maybe easier to understand what we doing with the VPN.

I don't want to make it complicated, so simply disable the communication between node with iptables.

**kube02-m1**

```bash
iptables -I INPUT -s 172.16.1.78 -j DROP
iptables -I INPUT -s 172.16.1.79 -j DROP
```

**kube02-m2**

```bash
iptables -I INPUT -s 172.16.1.77 -j DROP
iptables -I INPUT -s 172.16.1.79 -j DROP
```

**kube02-m3**

```bash
iptables -I INPUT -s 172.16.1.77 -j DROP
iptables -I INPUT -s 172.16.1.78 -j DROP
```

!!! note
    These rules are not permanent. So, if you restart the machine you should apply them again.

**Check the Tailscale Connection**

Don't forget the ping hosts before the `tailscale status` command.

```plain
root@kube02-m1:~# tailscale status | grep kube02-m
100.122.123.2   kube02-m1            jvincze84@   linux   -
100.103.128.9   kube02-m2            jvincze84@   linux   active; relay "fra", tx 308 rx 220
100.124.70.97   kube02-m3            jvincze84@   linux   active; relay "waw", tx 308 rx 220
```

Now you can see that the hosts are connected to each other via relay servers (`active; relay "fra", tx 308 rx 22`) provided by Tailscale.

To see the available relays, run the `tailscale netcheck` command.

```bash
root@kube02-m1:~# tailscale netcheck

Report:
        * UDP: true
        * IPv4: yes, 176.*.*.107:58839
        * IPv6: no, but OS has support
        * MappingVariesByDestIP: false
        * HairPinning: false
        * PortMapping:
        * Nearest DERP: Frankfurt
        * DERP latency:
                - fra: 18.4ms  (Frankfurt)
                - waw: 19.6ms  (Warsaw)
                - ams: 25.1ms  (Amsterdam)
                - par: 32ms    (Paris)
                - mad: 44.7ms  (Madrid)
                - lhr: 59.5ms  (London)
                - nyc: 119.4ms (New York City)
                - tor: 119.5ms (Toronto)
                - ord: 119.9ms (Chicago)
                - dbi: 130.8ms (Dubai)
                - mia: 132.8ms (Miami)
                - den: 140.8ms (Denver)
                - dfw: 145.8ms (Dallas)
                - sfo: 166.8ms (San Francisco)
                - lax: 170.1ms (Los Angeles)
                - sin: 170.5ms (Singapore)
                - sea: 177.8ms (Seattle)
                - blr: 193.9ms (Bangalore)
                - jnb: 198.7ms (Johannesburg)
                - hkg: 209ms   (Hong Kong)
                - sao: 214.5ms (São Paulo)
                - hnl: 215.8ms (Honolulu)
                - syd:         (Sydney)
                - tok:         (Tokyo)
root@kube02-m1:~#
```

This is one of my favorite feature of Tailscale. You don't have to have stable static public IP address to use VPN service.
But keep in mind, that connection over relay server can be significantly slower than direct connection. 

## Init The Cluster

### Prepare Kubelet

Before you do anything, prepare the kubelet to use Tailscale VPN IP address as node IP address. 

Run this command on all Kubernetes nodes:

```bash
echo "KUBELET_EXTRA_ARGS=--node-ip=$(tailscale ip --4)" | tee -a /etc/default/kubelet
```

**Samples:**

```plain
root@kube02-m1:~# echo "KUBELET_EXTRA_ARGS=--node-ip=$(tailscale ip --4)" | tee -a /etc/default/kubelet
KUBELET_EXTRA_ARGS=--node-ip=100.122.123.2
root@kube02-m1:~#

root@kube02-m2:~# echo "KUBELET_EXTRA_ARGS=--node-ip=$(tailscale ip --4)" | tee -a /etc/default/kubelet
KUBELET_EXTRA_ARGS=--node-ip=100.103.128.9
root@kube02-m2:~#

root@kube02-m3:~# echo "KUBELET_EXTRA_ARGS=--node-ip=$(tailscale ip --4)" | tee -a /etc/default/kubelet
KUBELET_EXTRA_ARGS=--node-ip=100.124.70.97
root@kube02-m3:~#
```

### Prepare The Load Balancer

I won't want to waste a lot time for this task, since this is only a lab env with just one function: demonstrate the installation.
HAProxy is a really good example about how to configure an external Load Balancer for kubernetes control plane nodes. 


**Check if MagicDNS is working fine**

```bash
root@kube02-haproxy:~# nslookup kube02-m1
Server:         100.100.100.100
Address:        100.100.100.100#53

Name:   kube02-m1.tailnet-a5cd.ts.net
Address: 100.122.123.2

root@kube02-haproxy:~# nslookup kube02-m2
Server:         100.100.100.100
Address:        100.100.100.100#53

Name:   kube02-m2.tailnet-a5cd.ts.net
Address: 100.103.128.9

root@kube02-haproxy:~# nslookup kube02-m3
Server:         100.100.100.100
Address:        100.100.100.100#53

Name:   kube02-m3.tailnet-a5cd.ts.net
Address: 100.124.70.97
```


**/etc/haproxy.conf** config file:

```conf
frontend kubeapi
  log global
  bind *:6443
  mode tcp
  option tcplog
  default_backend kubecontroleplain

backend kubecontroleplain
  option httpchk GET /healthz
  http-check expect status 200
  mode tcp
  log global
  balance roundrobin
  #option tcp-check
  option ssl-hello-chk
  server kube02-m1 kube02-m1.tailnet-a5cd.ts.net:6443 check
  server kube02-m2 kube02-m2.tailnet-a5cd.ts.net:6443 check
  server kube02-m3 kube02-m3.tailnet-a5cd.ts.net:6443 check


frontend stats
    mode http
    bind *:8404
    stats enable
    stats uri /stats
    stats refresh 10s
    stats admin if LOCALHOST
```

!!! warning
    As I know HAProxy resolve DNS only once at startup. So use DNS name in `server` section with caution. If the IP address has changed, do not forget to restart HAProxy.

Run `HAProxy`:

```bash
docker run --name haproxy -d -p 6443:6443 -p 8404:8404 -v /etc/haproxy.conf:/usr/local/etc/haproxy/haproxy.cfg haproxy
```

!!! info
    `*.tailnet-a5cd.ts.net` is my MagicDNS name.

### Init The First Control Plane Node

The command:

```bash
kubeadm init --cri-socket /var/run/containerd/containerd.sock \
--control-plane-endpoint kube02-haproxy.tailnet-a5cd.ts.net \
--apiserver-advertise-address $(tailscale ip --4) \
--pod-network-cidr 10.25.0.0/16 \
--service-cidr 10.26.0.0/16 \
--upload-certs
```

!!! important
    If you don't have separate HAProxy node, and you are using one kubernetes node, you should consider changing the `--apiserver-bind-port` port or the listen port of the HAProxy.

!!! important
    `pod-network-cidr` and `service-cidr` is required by flannel CNI. 

!!! important
    Do not forget the `--upload-certs` option, otherwise additional control plane nodes won't be able to join the cluster without extra steps.

**Command output:**

```plain linenums="1" hl_lines="67-69 81-83"
root@kube02-m1:# kubeadm init --cri-socket /var/run/containerd/containerd.sock \
--control-plane-endpoint kube02-haproxy.tailnet-a5cd.ts.net \
--apiserver-advertise-address $(tailscale ip --4) \
--pod-network-cidr 10.25.0.0/16 \
--service-cidr 10.26.0.0/16 \
--upload-certs
W0421 16:13:16.891232   25655 initconfiguration.go:119] Usage of CRI endpoints without URL scheme is deprecated and can cause kubelet errors in the future. Automatically prepending scheme "unix" to the "criSocket" with value "/var/run/containerd/containerd.sock". Please update your configuration!
I0421 16:13:17.241235   25655 version.go:256] remote version is much newer: v1.27.1; falling back to: stable-1.26
[init] Using Kubernetes version: v1.26.4
[preflight] Running pre-flight checks
[preflight] Pulling images required for setting up a Kubernetes cluster
[preflight] This might take a minute or two, depending on the speed of your internet connection
[preflight] You can also perform this action in beforehand using 'kubeadm config images pull'
[certs] Using certificateDir folder "/etc/kubernetes/pki"
[certs] Generating "ca" certificate and key
[certs] Generating "apiserver" certificate and key
[certs] apiserver serving cert is signed for DNS names [kube02-haproxy.tailnet-a5cd.ts.net kube02-m1 kubernetes kubernetes.default kubernetes.default.svc kubernetes.default.svc.cluster.local] and IPs [10.26.0.1 100.122.123.2]
[certs] Generating "apiserver-kubelet-client" certificate and key
[certs] Generating "front-proxy-ca" certificate and key
[certs] Generating "front-proxy-client" certificate and key
[certs] Generating "etcd/ca" certificate and key
[certs] Generating "etcd/server" certificate and key
[certs] etcd/server serving cert is signed for DNS names [kube02-m1 localhost] and IPs [100.122.123.2 127.0.0.1 ::1]
[certs] Generating "etcd/peer" certificate and key
[certs] etcd/peer serving cert is signed for DNS names [kube02-m1 localhost] and IPs [100.122.123.2 127.0.0.1 ::1]
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
[apiclient] All control plane components are healthy after 101.038704 seconds
[upload-config] Storing the configuration used in ConfigMap "kubeadm-config" in the "kube-system" Namespace
[kubelet] Creating a ConfigMap "kubelet-config" in namespace kube-system with the configuration for the kubelets in the cluster
[upload-certs] Storing the certificates in Secret "kubeadm-certs" in the "kube-system" Namespace
[upload-certs] Using certificate key:
2f2caa21e13d7f4bece27faa2515d024c8b4e93e08d8d21612113a7ebacff5ea
[mark-control-plane] Marking the node kube02-m1 as control-plane by adding the labels: [node-role.kubernetes.io/control-plane node.kubernetes.io/exclude-from-external-load-balancers]
[mark-control-plane] Marking the node kube02-m1 as control-plane by adding the taints [node-role.kubernetes.io/control-plane:NoSchedule]
[bootstrap-token] Using token: 1q32dn.swfpr7qj89hl2g4j
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

You can now join any number of the control-plane node running the following command on each as root:

  kubeadm join kube02-haproxy.tailnet-a5cd.ts.net:6443 --token 1q32dn.swfpr7qj89hl2g4j \
        --discovery-token-ca-cert-hash sha256:11c669ee4e4e27b997ae5431133dd2cd7c6a2050ddd16b38bee8bee544bbe680 \
        --control-plane --certificate-key 2f2caa21e13d7f4bece27faa2515d024c8b4e93e08d8d21612113a7ebacff5ea

Please note that the certificate-key gives access to cluster sensitive data, keep it secret!
As a safeguard, uploaded-certs will be deleted in two hours; If necessary, you can use
"kubeadm init phase upload-certs --upload-certs" to reload certs afterward.

Then you can join any number of worker nodes by running the following on each as root:

kubeadm join kube02-haproxy.tailnet-a5cd.ts.net:6443 --token 1q32dn.swfpr7qj89hl2g4j \
        --discovery-token-ca-cert-hash sha256:11c669ee4e4e27b997ae5431133dd2cd7c6a2050ddd16b38bee8bee544bbe680
```

Run these commands:

```bash
mkdir -p $HOME/.kube
sudo cp -i /etc/kubernetes/admin.conf $HOME/.kube/config
sudo chown $(id -u):$(id -g) $HOME/.kube/config
```  

And finally check the nodes:

```bash
kubectl get nodes -o wide
NAME        STATUS     ROLES           AGE     VERSION   INTERNAL-IP     EXTERNAL-IP   OS-IMAGE                         KERNEL-VERSION    CONTAINER-RUNTIME
kube02-m1   NotReady   control-plane   2m45s   v1.26.4   100.122.123.2   <none>        Debian GNU/Linux 11 (bullseye)   5.10.0-21-amd64   containerd://1.6.20
```

### Init Additinal Control Plane Nodes

**Command:**

```bash
kubeadm join kube02-haproxy.tailnet-a5cd.ts.net:6443 --token 1q32dn.swfpr7qj89hl2g4j \
--apiserver-advertise-address $(tailscale ip --4) \
--cri-socket /var/run/containerd/containerd.sock \
--discovery-token-ca-cert-hash sha256:11c669ee4e4e27b997ae5431133dd2cd7c6a2050ddd16b38bee8bee544bbe680 \
--control-plane --certificate-key 2f2caa21e13d7f4bece27faa2515d024c8b4e93e08d8d21612113a7ebacff5ea
```

!!! important
    Important that the nodes must use their own VPN address as `apiserver-advertise-address`

Example Command Output:

```plain linenums="1" hl_lines="57-59 61"
root@kube02-m2:# kubeadm join kube02-haproxy.tailnet-a5cd.ts.net:6443 --token 1q32dn.swfpr7qj89hl2g4j --apiserver-advertise-address $(tailscale ip --4) --cri-socket /var/run/containerd/containerd.sock --discovery-token-ca-cert-hash sha256:11c669ee4e4e27b997ae5431133dd2cd7c6a2050ddd16b38bee8bee544bbe680 --control-plane --certificate-key 2f2caa21e13d7f4bece27faa2515d024c8b4e93e08d8d21612113a7ebacff5ea
W0421 16:23:11.602945   26931 initconfiguration.go:119] Usage of CRI endpoints without URL scheme is deprecated and can cause kubelet errors in the future. Automatically prepending scheme "unix" to the "criSocket" with value "/var/run/containerd/containerd.sock". Please update your configuration!
[preflight] Running pre-flight checks
[preflight] Reading configuration from the cluster...
[preflight] FYI: You can look at this config file with 'kubectl -n kube-system get cm kubeadm-config -o yaml'
[preflight] Running pre-flight checks before initializing the new control plane instance
[preflight] Pulling images required for setting up a Kubernetes cluster
[preflight] This might take a minute or two, depending on the speed of your internet connection
[preflight] You can also perform this action in beforehand using 'kubeadm config images pull'
[download-certs] Downloading the certificates in Secret "kubeadm-certs" in the "kube-system" Namespace
[download-certs] Saving the certificates to the folder: "/etc/kubernetes/pki"
[certs] Using certificateDir folder "/etc/kubernetes/pki"
[certs] Generating "apiserver" certificate and key
[certs] apiserver serving cert is signed for DNS names [kube02-haproxy.tailnet-a5cd.ts.net kube02-m2 kubernetes kubernetes.default kubernetes.default.svc kubernetes.default.svc.cluster.local] and IPs [10.26.0.1 100.103.128.9]
[certs] Generating "apiserver-kubelet-client" certificate and key
[certs] Generating "front-proxy-client" certificate and key
[certs] Generating "etcd/peer" certificate and key
[certs] etcd/peer serving cert is signed for DNS names [kube02-m2 localhost] and IPs [100.103.128.9 127.0.0.1 ::1]
[certs] Generating "apiserver-etcd-client" certificate and key
[certs] Generating "etcd/server" certificate and key
[certs] etcd/server serving cert is signed for DNS names [kube02-m2 localhost] and IPs [100.103.128.9 127.0.0.1 ::1]
[certs] Generating "etcd/healthcheck-client" certificate and key
[certs] Valid certificates and keys now exist in "/etc/kubernetes/pki"
[certs] Using the existing "sa" key
[kubeconfig] Generating kubeconfig files
[kubeconfig] Using kubeconfig folder "/etc/kubernetes"
[kubeconfig] Writing "admin.conf" kubeconfig file
[kubeconfig] Writing "controller-manager.conf" kubeconfig file
[kubeconfig] Writing "scheduler.conf" kubeconfig file
[control-plane] Using manifest folder "/etc/kubernetes/manifests"
[control-plane] Creating static Pod manifest for "kube-apiserver"
[control-plane] Creating static Pod manifest for "kube-controller-manager"
[control-plane] Creating static Pod manifest for "kube-scheduler"
[check-etcd] Checking that the etcd cluster is healthy
[kubelet-start] Writing kubelet configuration to file "/var/lib/kubelet/config.yaml"
[kubelet-start] Writing kubelet environment file with flags to file "/var/lib/kubelet/kubeadm-flags.env"
[kubelet-start] Starting the kubelet
[kubelet-start] Waiting for the kubelet to perform the TLS Bootstrap...
[etcd] Announced new etcd member joining to the existing etcd cluster
[etcd] Creating static Pod manifest for "etcd"
[etcd] Waiting for the new etcd member to join the cluster. This can take up to 40s

The 'update-status' phase is deprecated and will be removed in a future release. Currently it performs no operation
[mark-control-plane] Marking the node kube02-m2 as control-plane by adding the labels: [node-role.kubernetes.io/control-plane node.kubernetes.io/exclude-from-external-load-balancers]
[mark-control-plane] Marking the node kube02-m2 as control-plane by adding the taints [node-role.kubernetes.io/control-plane:NoSchedule]

This node has joined the cluster and a new control plane instance was created:

* Certificate signing request was sent to apiserver and approval was received.
* The Kubelet was informed of the new secure connection details.
* Control plane label and taint were applied to the new node.
* The Kubernetes control plane instances scaled up.
* A new etcd member was added to the local/stacked etcd cluster.

To start administering your cluster from this node, you need to run the following as a regular user:

        mkdir -p $HOME/.kube
        sudo cp -i /etc/kubernetes/admin.conf $HOME/.kube/config
        sudo chown $(id -u):$(id -g) $HOME/.kube/config

Run 'kubectl get nodes' to see this node join the cluster.
```

**Finally check the nodes:**

```
root@kube02-m1:~# kubectl get nodes -o wide
NAME        STATUS     ROLES           AGE   VERSION   INTERNAL-IP     EXTERNAL-IP   OS-IMAGE                         KERNEL-VERSION    CONTAINER-RUNTIME
kube02-m1   NotReady   control-plane   10m   v1.26.4   100.122.123.2   <none>        Debian GNU/Linux 11 (bullseye)   5.10.0-21-amd64   containerd://1.6.20
kube02-m2   NotReady   control-plane   98s   v1.26.4   100.103.128.9   <none>        Debian GNU/Linux 11 (bullseye)   5.10.0-21-amd64   containerd://1.6.20
kube02-m3   NotReady   control-plane   16s   v1.26.4   100.124.70.97   <none>        Debian GNU/Linux 11 (bullseye)   5.10.0-21-amd64   containerd://1.6.20
```

### (optional) Post Init Steps

These steps are useful when you won't have any worker nodes, just control-planes.

#### Mark Nodes As Worker

```bash
kubectl label node kube02-m1 node-role.kubernetes.io/worker=
kubectl label node kube02-m2 node-role.kubernetes.io/worker=
kubectl label node kube02-m3 node-role.kubernetes.io/worker=
```

#### Untaint The Nodes

```bash
kubectl taint nodes kube02-m1 node-role.kubernetes.io/control-plane=:NoSchedule-
kubectl taint nodes kube02-m2 node-role.kubernetes.io/control-plane=:NoSchedule-
kubectl taint nodes kube02-m3 node-role.kubernetes.io/control-plane=:NoSchedule-
```

Our nodes are in `NotReady` state, because no network plugin is installed.

## Install Network Plugin

In this post I will show two network plugin: [flannel](https://github.com/flannel-io/flannel) and [weave](https://www.weave.works/docs/net/latest/kubernetes/kube-addon/).

### Weave

**Download The Manifest**

```bash
wget https://github.com/weaveworks/weave/releases/download/v2.8.1/weave-daemonset-k8s.yaml
```

You should consider to change iptables mode:

> IPTABLES_BACKEND - set to nft to use nftables backend for iptables (default is iptables)

In my case I use nft, so I have to add `IPTABLES_BACKEND` environment variable and set to `nft`

```yaml hl_lines="5-7" linenums="1"
          containers:
            - name: weave
              command:
                - /home/weave/launch.sh
              env:
                - name: IPTABLES_BACKEND
                  value: nft
```

**Apply the manifest**

```bash
kubectl  apply -f weave-daemonset-k8s.yaml
```

Check the status of the Weave PODs:

```bash
kubectl -n kube-system get pods -l name=weave-net -o wide
```

You should see something like this:

```
NAME              READY   STATUS    RESTARTS      AGE   IP              NODE        NOMINATED NODE   READINESS GATES
weave-net-drz44   2/2     Running   1 (59s ago)   68s   100.103.128.9   kube02-m2   <none>           <none>
weave-net-p72nl   2/2     Running   1 (59s ago)   68s   100.124.70.97   kube02-m3   <none>           <none>
weave-net-zzj9p   2/2     Running   1 (59s ago)   68s   100.122.123.2   kube02-m1   <none>           <none>
```

If everything went good, you should see that the coredns pods are running:

```bash
root@kube02-m1:~# kubectl -n kube-system get pods -l k8s-app=kube-dns -o wide
NAME                       READY   STATUS    RESTARTS   AGE   IP          NODE        NOMINATED NODE   READINESS GATES
coredns-787d4945fb-2d5zm   1/1     Running   0          21m   10.40.0.0   kube02-m1   <none>           <none>
coredns-787d4945fb-gmtbr   1/1     Running   0          21m   10.40.0.1   kube02-m1   <none>           <none>
```

### Flannel

Download the manifest:

```bash
wget https://github.com/flannel-io/flannel/releases/latest/download/kube-flannel.yml
```

Modify the manifest to use the tailscale0 interface (`iface=tailscale0`):

```yaml hl_lines="5" linenums="1"
     containers:
      - args:
        - --ip-masq
        - --kube-subnet-mgr
        - --iface=tailscale0
        command:
        - /opt/bin/flanneld
        env:
        - name: POD_NAME
          valueFrom:
```

Apply the manifest:

```bash
kubectl apply -f kube-flannel.yml
```

!!! warning
    Choose only one CNI plugin, do not install both flannel and weave.
    If you want to replace weave you should remove it: 

    - `kubectl delete -f weave-daemonset-k8s.yaml`
    - `rm /etc/cni/net.d/10-weave.conflist`
    - Additionally rebooting the nodes may be necessary.

### Switch Between iptables-legacy And iptables-nft

If you want or need to change iptables to or from iptables-legacy please check this link: [https://wiki.debian.org/iptables](https://wiki.debian.org/iptables)

Example, how to change to legacy:

```bash
apt-get install arptables
update-alternatives --set iptables /usr/sbin/iptables-legacy
update-alternatives --set ip6tables /usr/sbin/ip6tables-legacy
update-alternatives --set arptables /usr/sbin/arptables-legacy
update-alternatives --set ebtables /usr/sbin/ebtables-legacy
```

## (bonus) - Persistent Storage

Almost all Kubernetes Cluster have some kind of PersistentVolume solution for storing data. Now we will deploy [Longhorn](https://longhorn.io/docs/1.4.1/deploy/install/install-with-kubectl/)

**It is just a simple command:**

```bash
kubectl apply -f https://raw.githubusercontent.com/longhorn/longhorn/v1.4.1/deploy/longhorn.yaml
```

!!! info
    If you want to use RWX volumes NFSv4 client must be installed on all Kubernetes nodes. [LINK](https://longhorn.io/docs/1.4.1/advanced-resources/rwx-workloads/index.html#requirements)

### Create PVC

```yaml linenums="1"
cat <<EOF | kubectl apply -f -
apiVersion: v1
kind: PersistentVolumeClaim
metadata:
  name: test-pvc-02
spec:
  storageClassName: longhorn #(1)
  accessModes:
    - ReadWriteMany # (2)
  resources:
    requests:
      storage: 1Gi
EOF
```

1.  This is the default Storage Class
2.  Use one of: `ReadWriteOnce, ReadOnlyMany or ReadWriteMany, see AccessModes`

**Create Pod To Consume The Storage**

```bash linenums="1"
cat <<EOF | kubectl apply -f -
apiVersion: v1
kind: Pod
metadata:
  name: hello-pvc
  namespace: default
spec:
  volumes:
  - name: storage
    persistentVolumeClaim:
      claimName: test-pvc-02
  containers:
  - name: hello-container
    image: busybox
    command:
       - sh
       - -c
       - 'while true; do echo "`date` [`hostname`] Hello from Longhorn PV." >> /mnt/store/greet.txt; sleep $(($RANDOM % 5 + 300)); done'
    volumeMounts:
    - mountPath: /mnt/store
      name: storage
EOF
```      



