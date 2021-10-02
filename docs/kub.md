# INSTALL

**Important:**
kubeadm will not install or manage kubelet or kubectl for you, so you will need to ensure they match the version of the Kubernetes control plane you want kubeadm to install for you. If you do not, there is a risk of a version skew occurring that can lead to unexpected, buggy behaviour. However, one minor version skew between the kubelet and the control plane is supported, but the kubelet version may never exceed the API server version. For example, kubelets running 1.7.0 should be fully compatible with a 1.8.0 API server, but not vice versa.

## Add Repository

```bash
sudo apt-get update && sudo apt-get install -y apt-transport-https
curl -s https://packages.cloud.google.com/apt/doc/apt-key.gpg | sudo apt-key add -
echo "deb https://apt.kubernetes.io/ kubernetes-xenial main" | sudo tee -a /etc/apt/sources.list.d/kubernetes.list
sudo apt-get update
```

## Check Versions

Lehetséges parancsok:

- **`apt-cache madison kubectl`**
- **`apt-cache madison kubectl`**
```bash
kubectl:
  Installed: (none)
  Candidate: 1.17.3-00
  Version table:
     1.17.3-00 500
        500 https://apt.kubernetes.io kubernetes-xenial/main amd64 Packages
     1.17.2-00 500
        500 https://apt.kubernetes.io kubernetes-xenial/main amd64 Packages
     1.17.1-00 500
        500 https://apt.kubernetes.io kubernetes-xenial/main amd64 Packages
```
- **`apt list kubectl`**
```bash
Listing... Done
kubectl/kubernetes-xenial 1.17.3-00 amd64
N: There are 143 additional versions. Please use the '-a' switch to see them.
```
- **`apt list kubectl kubelet kubeadm`**
```bash
Listing... Done
kubeadm/kubernetes-xenial 1.17.3-00 amd64
kubectl/kubernetes-xenial 1.17.3-00 amd64
kubelet/kubernetes-xenial 1.17.3-00 amd64
```

Ellenőrzés telepítés előtt: **`apt-get install -s kubelet kubeadm kubectl`**

## cgroup

**Check:**
```bash
docker info | grep -i cgroup
 Cgroup Driver: cgroupfs
```

**Modify Config**:
```bash
cat  /etc/docker/daemon.json 
{
  "exec-opts": ["native.cgroupdriver=systemd"],
  "log-driver": "json-file",
  "log-opts": {
    "max-size": "100m"
  },
  "storage-driver": "overlay2",
  "live-restore": true
}
```

**ReCheck**
```bash
docker info | grep -i cgroup
 Cgroup Driver: systemd
```

**/etc/containerd/config.toml/config.toml**
(ez mégsem kell)
```bash
root@docker:/home/vinyo# cat /etc/containerd/config.toml | grep cg
#plugins.cri.systemd_cgroup = true
```

# Kubelet start script
```
cat kubelet.service
[Unit]
Description=kubelet: The Kubernetes Node Agent
Documentation=https://kubernetes.io/docs/home/
After=docker.service

[Service]
ExecStart=/usr/bin/kubelet
Restart=always
StartLimitInterval=0
RestartSec=10

[Install]
WantedBy=multi-user.target
```


## Aadmin
```
https://github.com/cloudnativelabs/kube-router/blob/master/docs/kubeadm.md
KUBECONFIG=/etc/kubernetes/admin.conf kubectl apply -f https://raw.githubusercontent.com/cloudnativelabs/kube-router/master/daemonset/kubeadm-kuberouter.yaml
```

https://cloudblue.freshdesk.com/support/solutions/articles/44001886522

# ==1 node(s) had taints that the pod didn't tolerate.==
```
Events:
  Type     Reason            Age        From               Message
  ----     ------            ----       ----               -------
  Warning  FailedScheduling  <unknown>  default-scheduler  0/1 nodes are available: 1 node(s) had taints that the pod didn't tolerate.
  Warning  FailedScheduling  <unknown>  default-scheduler  0/1 nodes are available: 1 node(s) had taints that the pod didn't tolerate.
```
**Megoldsás:**
```
kubectl taint nodes  docker.loc node-role.kubernetes.io/master-
```


# vsyscall
```
GRUB_CMDLINE_LINUX_DEFAULT="quiet vsyscall=emulate"
```
[https://einsteinathome.org/content/vsyscall-now-disabled-latest-linux-distros](https://einsteinathome.org/content/vsyscall-now-disabled-latest-linux-distros)



















