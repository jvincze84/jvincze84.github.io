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
