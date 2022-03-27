# Ingress

## Nginx Ingress Class

```yaml
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

## `extensions/v1beta1`

!!! attention
    Deprecated Api Version

```yaml
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

```yaml
  annotations:
    kubernetes.io/ingress.class: nginx
    nginx.ingress.kubernetes.io/backend-protocol: HTTPS
	nginx.ingress.kubernetes.io/proxy-body-size: 100m
```
