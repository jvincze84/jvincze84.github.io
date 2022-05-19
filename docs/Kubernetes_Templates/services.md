# Services

## Nginx Ingress - MetalLB
```yaml linenums="1"
apiVersion: v1
kind: Service
metadata:
  name: nginx
  namespace: ingress-nginx
  annotations:
    metallb.universe.tf/address-pool: default
spec:
  ports:
  - port: 80
    targetPort: 80
    name: http
  - port: 443
    targetPort: 443
    name: https
  selector:
    app.kubernetes.io/component: controller
    app.kubernetes.io/instance: ingress-nginx
    app.kubernetes.io/name: ingress-nginx
  type: LoadBalancer
```
### Bonus - MetalLB config
```yaml linenums="1"
apiVersion: v1
kind: ConfigMap
metadata:
  namespace: metallb-system
  name: config
data:
  config: |
    address-pools:
    - name: default
      protocol: layer2
      addresses:
      - 172.16.1.33 - 172.16.1.62
```
### Bonus - Result
```bash
# kubectl -n ingress-nginx describe svc nginx

Name:                     nginx
Namespace:                ingress-nginx
Labels:                   <none>
Annotations:              metallb.universe.tf/address-pool: default
Selector:                 app.kubernetes.io/component=controller,app.kubernetes.io/instance=ingress-nginx,app.kubernetes.io/name=ingress-nginx
Type:                     LoadBalancer
IP Family Policy:         SingleStack
IP Families:              IPv4
IP:                       10.253.161.102
IPs:                      10.253.161.102
LoadBalancer Ingress:     172.16.1.33
Port:                     http  80/TCP
TargetPort:               80/TCP
NodePort:                 http  30154/TCP
Endpoints:                10.32.0.13:80
Port:                     https  443/TCP
TargetPort:               443/TCP
NodePort:                 https  31568/TCP
Endpoints:                10.32.0.13:443
Session Affinity:         None
External Traffic Policy:  Cluster
Events:
  Type    Reason        Age                From                Message
  ----    ------        ----               ----                -------
  Normal  IPAllocated   3h47m              metallb-controller  Assigned IP ["172.16.1.33"]
  Normal  nodeAssigned  3h47m              metallb-speaker     announcing from node "k8s-nuc-test"
  Normal  nodeAssigned  61m                metallb-speaker     announcing from node "k8s-nuc-test"
  Normal  nodeAssigned  26m (x2 over 26m)  metallb-speaker     announcing from node "k8s-nuc-test"
  
 ```
