# Kubernetes Reverse Proxy With Ingress, Service And Endpoint

## TL;DR

Maybe you are wondering if Kubernetes capable proxying requests to an external service.
In which situation can it be useful? What is the benefit of it?
Imagine the situation that you have a Kubernetes cluster, perfectly configured Ingresses, Services, applications, etc. Everything goes well. But you have a service which is not running inside the Kubernetes cluster, and you want to access it form the internet. Port 443 and 80 are reserved for the IngressController, so your application could not bind these ports. My situation is similar to this, but there is a little difference.

I have a Kubernetes cluster running on some VPS and at home: 

* 2 VPS node have static, public ip address
* 2 node at my home are behind NAT, and don't have static ip address.

That's why my ingress pods are runnung only on the two VPS node; the IngressController DaemonSet has nodeSelector:

```yaml
      nodeSelector:
        kubernetes.io/os: linux
        nginxIngress: "true"
```

Ingress PODs:

```plain
NAME                             READY   STATUS    RESTARTS   AGE   IP          NODE                   NOMINATED NODE   READINESS GATES
ingress-nginx-controller-bplnb   1/1     Running   0          23d   10.8.0.33   vps11                  <none>           <none>
ingress-nginx-controller-qwr4c   1/1     Running   0          23d   10.8.0.2    vps9                   <none>           <none>
```

For simplicity I'm using dns loadbalancer between my two ingress pods.  
Another important thing, that the entire Kubernetes cluster is behind Wireguard VPN, so the nodes are connected to each other in this VPN connection. 

I have a separate HomeAssistant server, and I want to access it through my static ip addresses. I think it is better than user some kind of DynDns service, and it is even impossible when you are behind CGNAT. All of my PCs (servers) connected to the same Wireguard VPN. So I want to access the HomeAssistant server through the nginx ingress. 

!!! note

    I know that there are several other ways to access services running  behind NAT or CGNAT. The simpiest is to install Wireguard to all the device from which I want to access the home assistnat server, but I think this is an interesting way to achieve my goal.

Ok let's see the solution.

## Create The Service And Endpoints

### Service

```yaml
kind: Service
apiVersion: v1
metadata:
  name: hassio-ext-test
  namespace: default
spec:
  ports:
    - name: hassio
      protocol: TCP
      port: 80
      targetPort: 80
  type: ClusterIP
```

### Endpoints

```yaml
apiVersion: v1
kind: Endpoints
metadata:
  namespace: default
  name: hassio-ext-test
subsets:
- addresses:
  - ip: 10.8.0.1
  ports:
  - name: hassio
    port: 8123
    protocol: TCP
```


The following fileds **must** mach:

|Service|Endpoints|
|----|----|
|metadata.name|metadata.name|
|spec.ports.name|subsets.ports.name|
|spec.ports.protocol|subsets.ports.protocol|

**The Service must not have any selector in the spec.**

The HomeAssistant service is running on `10.8.0.1:8123`.

??? note

    This approch can also be useful if you want to access external service from inside the Kubernetes cluster. For example you have external Elasticsearch cluster with multiple ip addresses and you want to access it from a POD. You can simply define multiple ip address in the service `subnet.addresses` section.

## Ingress

In the last step we define the Ingress.

```yaml
kind: Ingress
apiVersion: networking.k8s.io/v1
metadata:
  name: hassio-test
  namespace: default
  annotations:
    kubernetes.io/ingress.class: nginx
spec:
  rules:
    - host: hassio-test.vincze.work
      http:
        paths:
          - pathType: ImplementationSpecific
            backend:
              service:
                name: hassio-ext-test
                port:
                  number: 80
```


That's all. Now you can access the HomeAssistant service running outside the Kubernetes cluster.

If you have configured cert-manager you may want to get a valid, public trust certificate for this ingress. You can achieve this by adding an extra annotation:

```yaml
metadata:
  annotations:
    cert-manager.io/cluster-issuer: letsencrypt-prod
```



