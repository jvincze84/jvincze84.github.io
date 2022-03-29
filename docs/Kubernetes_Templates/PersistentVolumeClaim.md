# PersistentVolumeClaim

## List Storage Classes

```bash
kubectl get sc
```

## Example Claim

```yaml linenums="1"
apiVersion: v1
kind: PersistentVolumeClaim
metadata:
  name: replace_me
spec:
  storageClassName: replace_me
  accessModes:
    - ReadWriteOnce # (1)
  resources:
    requests:
      storage: 1Gi
```

1. 	Avaiable Access Modes: **ReadWriteOnce**, **ReadOnlyMany**, **ReadWriteMany**, **ReadWriteOncePod**  
	[Link](https://kubernetes.io/docs/concepts/storage/persistent-volumes/#access-modes)


## Create And Attach PVC (Shell Script)

!!! caution
    Highlighted Lines must be changed!

```bash linenums="1" hl_lines="27"
#!/bin/bash

PVC=$( mktemp /tmp/pvc-XXXXXX.yaml)
PATCH=$( mktemp /tmp/patch-XXXXXX.yaml)

read -p "Namespace?: " NS
read -p "PVC name: " PVC
read -p "PVC size (mb): " SIZE
read -p "Deployment?: " DEPLOY
read -p "Container?: " CONTAINER
read -p "Mount?: " MOUNT



cat <<EOF>$PVC
kind: PersistentVolumeClaim
apiVersion: v1
metadata:
  name: $PVC
  namespace: $NS
spec:
  accessModes:
    - ReadWriteOnce 
  resources:
    requests:
      storage: ${SIZE}Mi
  storageClassName: longhorn-one-replica
  volumeMode: Filesystem
EOF

kubectl apply -f $PVC 

cat <<EOF>$PATCH
spec:
  template:
    spec:
      volumes:
        - name: pvc-$PVC
          persistentVolumeClaim:
            claimName: $PVC
      containers:
        - name: $CONTAINER
          volumeMounts:
            - name: pvc-$PVC
              mountPath: $MOUNT
EOF


echo "Sleep 5 secs"
sleep 5
kubectl -n $NS patch deployment $DEPLOY --patch-file $PATCH 
```

## Example Attach

```yaml linenums="1"
    spec:
      volumes:
        - name: ohab-data
          persistentVolumeClaim:
            claimName: ohab-data
```

```yaml linenums="1"
    spec:
      containers:
        - name: openhab3
          volumeMounts:
            - name: ohab-data
              mountPath: /openhab/addons
              subPath: addons
```

