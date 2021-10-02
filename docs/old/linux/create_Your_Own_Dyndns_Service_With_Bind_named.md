!!! caution
    **This page has been updated a long time ago.**  Information found here could be outdated and may lead to missconfiguration.  
    Some of the links and references may be broken or lead to non existing pages.  
    Please use this docs carefully. Most of the information here now is only for reference or example!

    
# Create Your Own DynDns Service with Bind (Named)

## 1. First you need to generate the private and public key
You can do that with one simple command:
```bash
dnssec-keygen -a HMAC-MD5 -b 256 -n HOST dyn-key
```
dnssec-keygen -a HMAC-MD5 -b 256 -n HOST dyn-key

I chose `HMAC-MD5` hash algorithm, and I recommend to generate at least 256 bit keys.
The `-n` option: `-n <nametype>: ZONE | HOST | ENTITY | USER | OTHER`

We will have these two files:
```plain
Kdyn-key.+157+60890.key
Kdyn-key.+157+60890.private
```


## 2 Modify named.conf
Add this line to `named.conf`:

```bind
include "/etc/bind/dns.keys";
```


## 3. Create dns.keys configuration file

It must look like something similar to this example:
```
cat dns.keys 
key dyn-key. {
	algorithm HMAC-MD5;
	secret "fop39Dcbz9HZ9sQqzo64fHorSIJXnmGjJ980BwTg6O4=";
};
```

We have to stop here for some words. Where is the "secret" come from? 
You can find this ==private== key in `Kdyn-key.+157+60890.private`.
In my case: 

```
cat Kdyn-key.+157+60890.private 
Private-key-format: v1.3
Algorithm: 157 (HMAC_MD5)
Key: fop39Dcbz9HZ9sQqzo64fHorSIJXnmGjJ980BwTg6O4=
Bits: AAA=
Created: 20161015122904
Publish: 20161015122904
Activate: 20161015122904
```

## 4. Allow Update Zone with these keys
Example:
```
zone "dyn.vinczejanos.info" {
        type master;
        file "/etc/bind/db.dyn.vinczejanos.info";
        allow-query { any; };
        allow-update { key "dyn-key."; };
};
```

After the configuration is done, do not forget to restart bind.
```
/etc/init.d/bind9 restart
```

## 5. Check Update

```
cat update.sh 
cat << EOF | nsupdate -k "Kdyn-key.+157+60890.key"
server ns20.vinczejanos.info
zone dyn.vinczejanos.info.
update delete test-dyn.dyn.vinczejanos.info
update add test-dyn.dyn.vinczejanos.info 60 A 192.168.0.1
show
send
EOF
```



