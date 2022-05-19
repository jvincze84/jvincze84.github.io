# Ingress

## Nginx Ingress Class

```yaml linenums="1"
apiVersion: networking.k8s.io/v1
kind: Ingress
metadata:
  annotations:
    kubernetes.io/ingress.class: nginx
  name: replace_me
  namespace: replace_me
spec:
  #ingressClassName: nginx
  rules:
  - host: replace_me
    http:
      paths:
      - backend:
          service:
            name: replace_me
            port:
              name: replace_me
        pathType: ImplementationSpecific
```

## Kubernetes Dashboard
```yaml linenums="1"
apiVersion: networking.k8s.io/v1
kind: Ingress
metadata:
  annotations:
    nginx.ingress.kubernetes.io/backend-protocol: HTTPS
  labels:
    app.kubernetes.io/instance: kubernetes-dashboard
  name: dashboard
  namespace: kubernetes-dashboard
spec:
  ingressClassName: nginx
  rules:
  - host: dashboard.k8s-nuc-test.loc
    http:
      paths:
      - backend:
          service:
            name: kubernetes-dashboard
            port:
              number: 443
        path: /
        pathType: ImplementationSpecific
```



## `extensions/v1beta1`

!!! attention
    Deprecated Api Version

```yaml linenums="1"
kind: Ingress
apiVersion: extensions/v1beta1
metadata:
  name: replace_me
  namespace: replace_me
spec:
  rules:
    - host: replace_me
      http:
        paths:
          - pathType: ImplementationSpecific
            backend:
              serviceName: replace_me
              servicePort: 5601 
```

## Nginx Ingress HTTPS backend

```yaml linenums="1"
  annotations:
    kubernetes.io/ingress.class: nginx
    nginx.ingress.kubernetes.io/backend-protocol: HTTPS
	nginx.ingress.kubernetes.io/proxy-body-size: 100m
```
