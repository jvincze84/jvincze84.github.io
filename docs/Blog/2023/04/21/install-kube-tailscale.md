# Install Kubernetes Cluster Behind Tailscale VPN

## TL;DR

In this post we will install a **multi-master** Kubernetes cluster behind Tailscale VPN.
This scenario can be useful when:
- You Kubernetes nodes are not in the same subnet. 
- You are building a home-lab system, and the nodes are behind two or more NAT-ted network, or even behind CGNAT.
- Your nodes are running in separate data centers, and don't want to publish API ports on the public internet. 
- You want to access your cluster only from private VPN network.
- You want extra security by encrypted connection between nodes.
- Or the mixture of above scenarios. 

**Why Tailscale VPN?**

You can use any other VPN solution like Wireguard, OpenVPN, IPSec, etc. But nowadays I think Tailscal is the easiest way to bring up a VPN network.
With a free registration you get 100 device, subnet routers, exit nodes, (Magic)DNS, and so many useful features. 

For more information check the following links:
- [TailScale](https://tailscale.com)
- [Tailscale Pricing](https://tailscale.com/pricing/)

But as I mentiond you can use any other VPN solution, personally I'm using Wireguard in my home-lab system.

!!! warning
    Tailscale assigns IP address from `100.64.0.0/10` range! [IP Address Assignment](https://tailscale.com/kb/1015/100.x-addresses/)
    If you are plannig to use [Kube-OVN](https://www.kube-ovn.io) nerworking don't forget to change the CIDR, because Kube-OVN is also use this subnet!

## Infrastructure

As I mentioned we will deploy a multi-master Kubernetes cluster:
- 3 master/worker nodes, without worker nodes. Later additional worker nodes can be added to the cluster, but for the simplicity we won't deploy extra worker nodes.
- We need an additional TCP load balancer for the API requests. I prefer HAProxy for this purpose, because it is easy to set up and lightweight. 
  - For this lab I will deploy only one Load Balancer, but if you need HA solution, at least two Load Balancers are needed. This can be achieved by using Keppalived. Or you can use external load balancer like F5. But this demo is not about HA Load balaners, so it is just enough to have only one LB.

| Hostname        | Role                     | IP Address   | VPN IP Address   |
| :-------------- | :----------------------- | :----------- | :--------------- |
| kube02-m1       | Controle Plane Node 1    | 172.16.1.77  | 100.100.100.100  |
| kube02-m2       | Controle Plane Node 2    | 172.16.1.78  | 100.100.100.100  |
| kube02-m3       | Controle Plane Node 3    | 172.16.1.79  | 100.100.100.100  |
| kube02-haproxy  | HAProxy Load Balancer    | 172.16.1.80  | 100.100.100.100  |
| ansible         | Ansible Host             | 172.16.0.252 | ---              |

!!! note
    You don't need the additional Ansible host, if you preparing the OS manually. 

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
And if something goes wrong you can start it over in a munite.

### Ansible 

Just a quick overwiev about my Ansible configuration and variables.

#### `ansible.cfg`

```yaml  title='<a href="https://raw.githubusercontent.com/jvincze84/jvincze84.github.io/master/docs/files/kube-ans-tailscale/ansible.cfg" target="_blank">Click Here For Raw Source</a>' linenums="1"
--8<-- "docs/files/ube-ans-tailscal/ansible.cfg"
```

#### `myvars.yml`

```yaml title='<a href="https://raw.githubusercontent.com/jvincze84/jvincze84.github.io/master/docs/files/kube-ans-tailscale/myvars.yml" target="_blank">Click Here For Raw Source</a>' linenums="1"
--8<-- docs/files/kube-ans-tailscale/myvars.yml
```

Details:
- `yq_url`: Yq binary URL. This version of yq will be installed on the hosts.
- `kube_version`: Here you can define which version of Kubernetes you want to install. (kubelet, kubeadm and kubectl)
- `common_packages`: These packages will be installed on the hosts. "Common packages" because usually I install these packages on my VMs, regardless of deploying Docker or Kubernetes. 
- `docker_packages`: Packages for installing Docker/Containerd engine.


#### `hosts`

```plain title='<a href="https://raw.githubusercontent.com/jvincze84/jvincze84.github.io/master/docs/files/kube-ans-tailscale/hosts" target="_blank">Click Here For Raw Source</a>' linenums="1"
--8<-- docs/files/kube-ans-tailscale/hosts
```


!!! important
    Ansible host must access the VMs over ssh. Before you run any of playbooks enable root login.
    For example: `sed -i -e 's/^#\(PermitRootLogin \).*/\1 yes/' /etc/ssh/sshd_config` and restart sshd daemon. 
    It is highly recommended to use dedicated ansible user (with sudo right) and ssh key authentication! 
    And don't forget to accept ssh key by login to the remotes systems before run the playbooks.
    If you are using other user than root, you may want to use `become: 'yes'` option it the plays.

### Update 

I usually start with updating the OS to the latest version, unless the application to be installed has no strict requirements.

**playbook-upgrade-debian.yaml**

```yaml title='<a href="https://raw.githubusercontent.com/jvincze84/jvincze84.github.io/master/docs/files/kube-ans-tailscale/playbook-upgrade-debian.yaml" target="_blank">Click Here For Raw Source</a>' linenums="1"
--8<-- docs/files/kube-ans-tailscale/playbook-upgrade-debian.yaml
```


**task_allow_release_info_change.yaml**

```yaml title='<a href="https://raw.githubusercontent.com/jvincze84/jvincze84.github.io/master/docs/files/kube-ans-tailscale/task_allow_release_info_change.yaml" target="_blank">Click Here For Raw Source</a>' linenums="1"
--8<-- docs/files/kube-ans-tailscale/task_allow_release_info_change.yaml
```


**Run this playbook:**

```bash
ansible-playbook playbook-upgrade-debian.yaml
```

### Install Common Packages

**playbook-install-common-packages.yaml**

```yaml title='<a href="https://raw.githubusercontent.com/jvincze84/jvincze84.github.io/master/docs/files/kube-ans-tailscale/playbook-install-common-packages.yaml" target="_blank">Click Here For Raw Source</a>' linenums="1"
--8<-- docs/files/kube-ans-tailscale/playbook-install-common-packages.yaml
```


**Run this playbook:**

```bash
ansible-playbook playbook-install-common-packages.yaml
```

### Install Container Engine

**playbook-install-docker.yaml**

```yaml title='<a href="https://raw.githubusercontent.com/jvincze84/jvincze84.github.io/master/docs/files/kube-ans-tailscale/playbook-install-docker.yaml" target="_blank">Click Here For Raw Source</a>' linenums="1"
--8<-- docs/files/kube-ans-tailscale/playbook-install-docker.yaml
```

**Run this playbook:**

```bash
ansible-playbook playbook-install-docker.yaml
```

### Install Kubernetes Tools 

**playbook-install-kubernetes.yaml**

```yaml title='<a href="https://raw.githubusercontent.com/jvincze84/jvincze84.github.io/master/docs/files/kube-ans-tailscale/playbook-install-kubernetes.yaml" target="_blank">Click Here For Raw Source</a>' linenums="1"
--8<-- docs/files/kube-ans-tailscale/playbook-install-kubernetes.yaml
```

**Run this playbook:**

```bash
ansible-playbook playbook-install-kubernetes.yaml
```











