# Secret

## Create Secret

```bash
kubectl -n default create secret generic test-password --from-literal=pass=vqMSr49PyimubUDIGxvA
```

### Check

```bash title="Command"
kubectl -n default get secret test-password -o yaml
```
```yaml linenums="1" title="Output"
apiVersion: v1
data:
  pass: dnFNU3I0OVB5aW11YlVESUd4dkE=
kind: Secret
metadata:
  creationTimestamp: "2022-03-29T10:33:02Z"
  name: test-password
  namespace: default
  resourceVersion: "130167833"
  uid: 269f72f5-2539-437d-877e-29959a754bef
type: Opaque
```

## Secret As Environment Variable

First Create a patch file:

```yaml linenums="1"
cat <<EOF>/tmp/patch.yaml
spec:
  template:
    spec:
      containers:
        - name: debian-example
          env:
           - name: PASSWORD
             valueFrom:
               secretKeyRef:
                 name: test-password
                 key: pass
EOF
```

**Run patch command**
```bash
kubectl -n default patch deployment debian-test --patch-file /tmp/patch.yaml
```

## Secret As File Mount (Simple)

### Patch File

```yaml linenums="1"
cat <<EOF>/tmp/patch.yaml
spec:
  template:
    spec:
      volumes:
        - name: secretpassword
          secret:
            secretName: test-password
      containers:
        - name: debian-example
          volumeMounts:
            - name: secretpassword
              mountPath: "/etc/foo"
              readOnly: true
EOF
```

### Apply

```bash
kubectl -n default patch deployment debian-test --patch-file /tmp/patch.yaml
```

### Check (Inside The Container)


```bash title="Commands"
find /etc/foo/
cat /etc/foo/pass ; echo
```
```text title="Ouptuts"
# find
/etc/foo/
/etc/foo/..data
/etc/foo/pass
/etc/foo/..2022_03_29_10_54_40.729006392
/etc/foo/..2022_03_29_10_54_40.729006392/pass

# cat
vqMSr49PyimubUDIGxvA
```

## Secret As File Mount (mountPath)

### Patch File

```yaml linenums="1" hl_lines="11 16"
cat <<EOF>/tmp/patch.yaml
spec:
  template:
    spec:
      volumes:
        - name: secretpasswordpath
          secret:
            secretName: test-password
            items:
              - key: pass
                path: custompath/password
      containers:
        - name: debian-example
          volumeMounts:
            - name: secretpasswordpath
              mountPath: "/etc/bar"
              readOnly: true
EOF
```

### Apply

```bash
kubectl -n default patch deployment debian-test --patch-file /tmp/patch.yaml
```

### Check (Inside The Container)

!!! info
    See the highlighted lines in the patch file and below.

```bash title="Commands" hl_lines="2"
find /etc/bar/ -ls
cat /etc/bar/custompath/password  ; echo 
```
```text title="Ouptuts" linenums="1" 
# find /etc/bar/ -ls
925320365      0 drwxrwxrwt   3 root     root          100 Mar 29 11:08 /etc/bar/
925316004      0 lrwxrwxrwx   1 root     root           31 Mar 29 11:08 /etc/bar/..data -> ..2022_03_29_11_08_55.729800752
925316003      0 lrwxrwxrwx   1 root     root           17 Mar 29 11:08 /etc/bar/custompath -> ..data/custompath
925316000      0 drwxr-xr-x   3 root     root           60 Mar 29 11:08 /etc/bar/..2022_03_29_11_08_55.729800752
925316001      0 drwxr-xr-x   2 root     root           60 Mar 29 11:08 /etc/bar/..2022_03_29_11_08_55.729800752/custompath
925316002      4 -rw-r--r--   1 root     root           20 Mar 29 11:08 /etc/bar/..2022_03_29_11_08_55.729800752/custompath/password

# cat /etc/bar/custompath/password  ; echo  
vqMSr49PyimubUDIGxvA
```

---

**Reference:**

  * [https://kubernetes.io/docs/concepts/configuration/secret/](https://kubernetes.io/docs/concepts/configuration/secret/)
  
