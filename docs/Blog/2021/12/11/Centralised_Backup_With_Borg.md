# Centralised Backup With Borg

## TL;DR

Why I Abandoned Duplicati?

I use to use [Duplicati](https://www.duplicati.com) as backup solution for ages. It's a really good backup solution with a handy user interface. Everything can be done on it's interface. 

My requirements toward a backup software:

* Differential backups on daily basis
* Support linux operation system
* Google Drive support for storing backup remotly
* Encryption, of course
* Be as lightweight as possible

I know Google Drive support a bit unusall, but I have 2TB storage and I don't want to pay for an other service. Duplicati fulfills all my requirments. There are only two weakness because of why I looked for another solution: resource consumption and speed:

* Duplicati can be really slow on restore from Google Drive if you store a lot of files.
* Duplicati uses [Mono](https://www.mono-project.com. (Cross platform, open source .NET framework). Running .NET on linux is not my taste, and sometimes consumes too much resource, especially on a Raspberry PI3.

After some hours of Googling and trying some softwares I found [Borg Backup](https://borgbackup.readthedocs.io/en/stable/).

The only missing feature is the Google Drive, but it can be achieved with `rclone`.

I don't want to write pages about my choice, features, advantages, disadvantages, etc. If you are reading this article you probably want to try or use Borg.

## Installing Borg

I will create three Virtual Machine for demonstration the installation and usage. 

Since the borg install procedure is always the same, I've done once and cloned the VM.

### Install On Debian 11

OS version:
```plain
root@borg01:~# cat /etc/os-release
PRETTY_NAME="Debian GNU/Linux 11 (bullseye)"
NAME="Debian GNU/Linux"
VERSION_ID="11"
VERSION="11 (bullseye)"
VERSION_CODENAME=bullseye
ID=debian
HOME_URL="https://www.debian.org/"
SUPPORT_URL="https://www.debian.org/support"
BUG_REPORT_URL="https://bugs.debian.org/"
```

Update apt:
```bash
apt-get update --allow-releaseinfo-change
apt-get upgrade
```

Install Borg Backup
```bash
apt-get install borgbackup
```

Check installed version:
```bash
root@borg01:~# borg --version
borg 1.1.16
```

So now I have a Proxmox template with ID 102. I'm goning to create 3 clone:

```bash
qm clone 102 501 -full false  -name borg-01
qm clone 102 502 -full false  -name borg-02
qm clone 102 503 -full false  -name borg-03

# Start 
qm start 501
qm start 502
qm start 503
```

IP Addresses:

* borg-01: `172.16.1.236/22`
* borg-02: `172.16.1.218/22`
* borg-03: `172.16.1.219/22`

### Configure SSH And Users

The borg-01 will be the server, it will store the backups.

* Create User
```bash
useradd --shell /bin/bash --create-home  borg
```

* Create SSH keys
```bash
su borg -s /bin/bash
ssh-keygen
cat ~/.ssh/id_rsa.pub >~/.ssh/authorized_keys
```

* Distribute the private key accross the other servers.
```bash
mkdir .ssh
cat <<EOF>~/.ssh/id_rsa
-----BEGIN OPENSSH PRIVATE KEY-----
b3BlbnNzaC1rZXktdjEAAAAABG5vbmUAAAAEbm9uZQAAAAAAAAABAAABlwAAAAdzc2gtcn
NhAAAAAwEAAQAAAYEAoyhZOfPqt61xanxN6tLP9+QDtS/UQhj2o+jmw4xPH2RCYAR9bWde
S9xVDLL/fvW2aSTwUKQ93ae0Q7e7eyzjBzH9sNab8knIpaiohJefyOgtqptUwN3f3MC8m9
uHUnBBHTiMG+9BkQ5/luU/VtG10ZLti9LqJaYmq3QFJszu8JGOhWHWDDbt8h08cwefikGJ
M0KtVCZnMV388QugIO4ecYa1vAdifz82y9m/UbmWkB6NXpnPx1ojciBUnlfTncFxMic+Za
ZvJsam/XU8hmdG7lSpyTUWRHIm61Zc9iBs90hmvqvDDuiMDu6chWVPiL/+CPT/G9CVprO+
dfG7mK+pmZgNNezsd5F6uCruhPjd5n17uKU1XgTDOhNmjYrwXCP+455B/NrWGjehjJY3sa
PNApQrE+XuHw6FQgIRIDH1mLCl1pqZo500M2PXQgj6+nFARpWrM5LrYOvy4ZmYILYEUauC
cUBpTBkfwqCUKdA3Aq3pAhxqzOzLwLlDxH1F806lAAAFiHUSLjJ1Ei4yAAAAB3NzaC1yc2
EAAAGBAKMoWTnz6retcWp8TerSz/fkA7Uv1EIY9qPo5sOMTx9kQmAEfW1nXkvcVQyy/371
tmkk8FCkPd2ntEO3u3ss4wcx/bDWm/JJyKWoqISXn8joLaqbVMDd39zAvJvbh1JwQR04jB
vvQZEOf5blP1bRtdGS7YvS6iWmJqt0BSbM7vCRjoVh1gw27fIdPHMHn4pBiTNCrVQmZzFd
/PELoCDuHnGGtbwHYn8/NsvZv1G5lpAejV6Zz8daI3IgVJ5X053BcTInPmWmbybGpv11PI
ZnRu5Uqck1FkRyJutWXPYgbPdIZr6rww7ojA7unIVlT4i//gj0/xvQlaazvnXxu5ivqZmY
DTXs7HeRergq7oT43eZ9e7ilNV4EwzoTZo2K8Fwj/uOeQfza1ho3oYyWN7GjzQKUKxPl7h
8OhUICESAx9ZiwpdaamaOdNDNj10II+vpxQEaVqzOS62Dr8uGZmCC2BFGrgnFAaUwZH8Kg
lCnQNwKt6QIcaszsy8C5Q8R9RfNOpQAAAAMBAAEAAAGAXcECvK1v08ojoPf64hPvk1d/1e
68/ppPp9JeQEHw+W3oQjpyRJqgceETMi/tZuwUvIiQWxZ1wlfq2vrKDba2Yl0UlThM9kX1
uVOYOlDSbWUVULLfWdBlIfnSp5DXSsTcdckXobmzKIJ3SKNE6UOqQdo3DCDPkYDPObh6eV
hLeQt7JSQaFny98GFiagsYXx7XkxAef3tt0s1aWry+cA3EiqHI7loj/FC70Rm3uWN2pCwa
OiESZ1Bhi+QOG8sF++G6mczyVc4/Ij/L47uWM7HGYy+kZxMi8eLW8SWCDGKCjOAxK7F3G3
N80I362y+ZeTO4ab73hGAukhjJb1SJRf0iWm8sgULRvdqxzEnRJuCzHZhoTErbNRqx4Rtz
val38czH4vhFT1H2pGyJQiLt2u+77kuCY+opKfb/YE4tsj1R8zT4MIUoui7OEPZ9KWsTPh
M53Fs+pAedKXUHCC+54AWUVhp49PQSDmFH1Wm5CtJVc4HOifsf1k7gwegGYGvIbqiFAAAA
wQCpz7o80lVgaobV4xXlf6vsshIm/f1Jp6gppGv72N+w5xqQqvEs3saBMnJ9BrD56M8cac
p2UzPL2DS4n/ZIi9EivTSGVCp9S6MVUFrbZRITEOKYXeQ14dJfkWBaB3876f5Ll++ougoO
XzJeVo9HJuy27/US2B58jlMF3UA+HAVfPlpwdPx8NPmBDd69GLzB/s/rOmn1ZTsSMzu7x6
igQnqiy+06XRhx4T1cSbGDH24lY6WH23SXikSt2+HX7KXdgTMAAADBANd/gnJqPVYuOlNJ
Yj/lBmmHd8pgdy6HSpguCVsD7XJjCQpv4N1NEq+xhdONeN/gFzlVKlf38o3W6vpfPR//Q1
u7Wud70XAijZpDDha190/9HhMCPqbJ3PY0HxniiMz4HHg5Gca9tYX4DezB3AoUmVh9F3oQ
PRO+RO3TMKdh5n3h8YVwCQ0qJvbWALqpyh6Fc2vO9j9pc+GNDGn/ViWXeZt2uyrnj6HE6K
3Mbvn+WZ85Ygbmvijca7Dm72dAyoKyuwAAAMEAwdKGkz0j0I/YOu9YcQXNp+YLUU/aRHox
wODjABbpJfBKM6l3VstV/uohu7egN5LZxQRiDk4Y75OtfR9SI5459qMzZP6vK3xxVcJso2
hrBz14DUhBt3R/akOfhF9PW2vasuhK2WOrMrYwBkkMxDcP1u66CVRHzlC5jX+uzBfPF7cI
FWP1EjNXMttHN5/t1NBs/Mj78Rgr+Rdzm//3dvWW1Z7ME/YVldTIBTCbP3/2Z9hHTO+FmR
EmVgLE4QudDV4fAAAADGJvcmdAYm9yZy0wMQECAwQFBg==
-----END OPENSSH PRIVATE KEY-----
EOF

chmod 700 ~/.ssh/
chmod 600 ~/.ssh/id_rsa
```

Test:
<pre class="command-line" data-user="root" data-host="borg-02" data-output="2-10"><code class="language-bash">ssh borg@172.16.1.215
Linux borg-01 5.13.19-1-pve #1 SMP PVE 5.13.19-2 (Tue, 09 Nov 2021 12:59:38 +0100) x86_64

The programs included with the Debian GNU/Linux system are free software;
the exact distribution terms for each program are described in the
individual files in /usr/share/doc/*/copyright.

Debian GNU/Linux comes with ABSOLUTELY NO WARRANTY, to the extent
permitted by applicable law.
Last login: Sat Dec 11 15:51:46 2021 from 172.16.1.216
borg@borg-01:~$ </code></pre>

Ok. It works well.

!!! warning
    Please keep your private key safe. Since this is a demo environment I don't care much the security. I storngly recommend to use individual keys for each host. This post is not about ssh key management, but Borg backup.

!!! info
    I'm using the `root` user on the clients, bacuse only the `root` account has access to the directories I want to backup.

## Create & Mange Backups

### Initialize & Passphare

* Create very storng passphare
```bash
head -c 32 /dev/urandom | base64 -w 0 > ~/.borg-passphrase
chmod 400 ~/.borg-passphrase
export BORG_PASSCOMMAND="cat $HOME/.borg-passphrase"
```

* Initialize

<pre class="command-line" data-user="root" data-host="borg-02" data-output="2-13"><code class="language-bash">borg init -e repokey-blake2 borg@172.16.1.236:/home/borg/borg-02

By default repositories initialized with this version will produce security
errors if written to with an older version (up to and including Borg 1.0.8).

If you want to use these older versions, you can disable the check by running:
borg upgrade --disable-tam ssh://borg@172.16.1.236/home/borg/borg-02

See https://borgbackup.readthedocs.io/en/stable/changes.html#pre-1-0-9-manifest-spoofing-vulnerability for details about the security implications.

IMPORTANT: you will need both KEY AND PASSPHRASE to access this repo!
Use "borg key export" to export the key, optionally in printable format.
Write down the passphrase. Store both at safe place(s). </code></pre>

!!! caution
    If you lose the passphrase (`~/.borg-passphrase`) you lose all of the backups, as well. So I do really recommend to keep it in a safe place, not just in the home directory!

Repeat this step on all nodes you want to create backup.

!!! important
    There are two really important things to be kept in safe, the passphrase  and the key. I strongly recommend to save them to you password manager or keep them somewhere in really safe. 
    
#### Manage Your Key And Passphrase 

I assume you are using password manager in any way, and hope this manager is not a plain text file. :) 

Save your passphrase to your password manager is simple. Just save the conent of this file: `~/.borg-passphrase`
```bash
cat ~/.borg-passphrase  ; echo
```
The key is bit more complicated. Fisrt see how to export:

<pre class="command-line" data-user="root" data-host="borg-02" data-output="3-15"><code class="language-bash">borg key export borg@172.16.1.236:/home/borg/borg-02  /tmp/key
cat /tmp/key
BORG_KEY f968c50460d1ca7aaec9a8e2347a61fd286b26fb84adcaa6de7808966026b51e
hqlhbGdvcml0aG2mc2hhMjU2pGRhdGHaAZ7vhs+Yzwxg9VgXxo95S5+ScE8RT3yY6elK5J
KJKhfwz/YYJrGO6ZlDSpr9i+fnUI7qz6BfIxBLA6yILdcFVpOUuy99cDp79Uyc7wrIDnTV
sk0oiQWBt3710yM3hJQC84Q69grriPrF0jdzgSCvDKn+FNfQQgLTgnYMavxxnXZESTStng
zfxMtcJZMghEm1Mfd8ZwRTDXPgpF5z03bXy+7DrQ/btxgiW8G+h6DEccBDKvf0oAfDOPvH
sGgC2aBq+lqpUcxdIhpd+CZ0BzFkWCMrQkr3QOhlMbGtkqi7a78/rIYeJWevyWwODM7RvZ
i01qqbrDoflkRAg/LiY76p0wi46ls8Annygw9RY7YzOq7+xEvImGRYXX5joJ9Lb1GQ3Eh1
7MSFFdVRfAXbcAUlyQXZ+k/TzxZIFw7ZsXvQL33AFD1MwuXVJdXCJZFtWNUD97Cd5cTwEq
f6T5AofjK6WAIF5qD4RGVEoH0X8+7MJ6IHCu8aPbjnqVLvjR9Ubii7mS5gC9IRdaN5T61i
PjNC3Lm8TjqL8WlSjqfqvu2BczikaGFzaNoAIL0XSOEvCdQ46MtJO5/Q98J1mEDsC9tLVv
OBZZy+emXAqml0ZXJhdGlvbnPOAAGGoKRzYWx02gAg/tXk5wRp5YZlOHdzm+Gk+8f5Qi/f
s2VHKZJPL8BfecWndmVyc2lvbgE=</code></pre>

If you can save this file as attachment  you are done. But not all password manager supports attachments, and the line brakes can be broken. In this case I recommend to use `base64`:

<pre class="command-line" data-user="root" data-host="borg-02" data-output="2"><code class="language-bash">cat /tmp/key | base64 -w0 ; echo
Qk9SR19LRVkgZjk2OGM1MDQ2MGQxY2E3YWFlYzlhOGUyMzQ3YTYxZmQyODZiMjZmYjg0YWRjYWE2ZGU3ODA4OTY2MDI2YjUxZQpocWxoYkdkdmNtbDBhRzJtYzJoaE1qVTJwR1JoZEdIYUFaN3ZocytZend4ZzlWZ1h4bzk1UzUrU2NFOFJUM3lZNmVsSzVKCktKS2hmd3ovWVlKckdPNlpsRFNwcjlpK2ZuVUk3cXo2QmZJeEJMQTZ5SUxkY0ZWcE9VdXk5OWNEcDc5VXljN3dySURuVFYKc2swb2lRV0J0MzcxMHlNM2hKUUM4NFE2OWdycmlQckYwamR6Z1NDdkRLbitGTmZRUWdMVGduWU1hdnh4blhaRVNUU3RuZwp6ZnhNdGNKWk1naEVtMU1mZDhad1JURFhQZ3BGNXowM2JYeSs3RHJRL2J0eGdpVzhHK2g2REVjY0JES3ZmMG9BZkRPUHZICnNHZ0MyYUJxK2xxcFVjeGRJaHBkK0NaMEJ6RmtXQ01yUWtyM1FPaGxNYkd0a3FpN2E3OC9ySVllSldldnlXd09ETTdSdloKaTAxcXFickRvZmxrUkFnL0xpWTc2cDB3aTQ2bHM4QW5ueWd3OVJZN1l6T3E3K3hFdkltR1JZWFg1am9KOUxiMUdRM0VoMQo3TVNGRmRWUmZBWGJjQVVseVFYWitrL1R6eFpJRnc3WnNYdlFMMzNBRkQxTXd1WFZKZFhDSlpGdFdOVUQ5N0NkNWNUd0VxCmY2VDVBb2ZqSzZXQUlGNXFENFJHVkVvSDBYOCs3TUo2SUhDdThhUGJqbnFWTHZqUjlVYmlpN21TNWdDOUlSZGFONVQ2MWkKUGpOQzNMbThUanFMOFdsU2pxZnF2dTJCY3ppa2FHRnphTm9BSUwwWFNPRXZDZFE0Nk10Sk81L1E5OEoxbUVEc0M5dExWdgpPQlpaeStlbVhBcW1sMFpYSmhkR2x2Ym5QT0FBR0dvS1J6WVd4MDJnQWcvdFhrNXdScDVZWmxPSGR6bStHays4ZjVRaS9mCnMyVkhLWkpQTDhCZmVjV25kbVZ5YzJsdmJnRT0K</code></pre>

Restore command: `echo -n [BASE64_STRING] | base64 -d`

!!! tip
    If you want to make the `base64` string smaller you can use `gzip`.  
    **Encode**: `cat /tmp/key | gzip -c | base64`  
    **Decode**: `echo -n [BASE64_STRING] | base64 -d | gunzip -c`
    


### Create Backups

!!! important
    Don't forget to export `BORG_PASSCOMMAND`  before you use `borg` command!  
    `export BORG_PASSCOMMAND="cat $HOME/.borg-passphrase"`



<pre class="command-line" data-user="root" data-host="borg-02" data-output="2-17"><code class="language-bash">borg create --stats borg@172.16.1.236:/home/borg/borg-02::firstBackup /root /etc /home /opt
------------------------------------------------------------------------------
Archive name: firstBackup
Archive fingerprint: 882ed726a7115928149aa438af4b78f09d322a34c17dd65f0bf7ce537092ee1b
Time (start): Sat, 2021-12-11 17:43:09
Time (end):   Sat, 2021-12-11 17:43:11
Duration: 2.40 seconds
Number of files: 443
Utilization of max. archive size: 0%
------------------------------------------------------------------------------
                       Original size      Compressed size    Deduplicated size
This archive:                1.61 MB            654.41 kB            649.83 kB
All archives:                1.61 MB            654.41 kB            649.83 kB

                       Unique chunks         Total chunks
Chunk index:                     424                  434
------------------------------------------------------------------------------ </code></pre>

Create another backup:

<pre class="command-line" data-user="root" data-host="borg-02" data-output="2-17"><code class="language-bash">borg create --stats borg@172.16.1.236:/home/borg/borg-02::secondBackup /root /etc /home /opt /var/log/
------------------------------------------------------------------------------
Archive name: secondBackup
Archive fingerprint: f61a6d2ce46fc6433a6cfa9cdb1f146933f897c6bce769d071644e7117684cd9
Time (start): Sat, 2021-12-11 17:44:53
Time (end):   Sat, 2021-12-11 17:44:55
Duration: 1.56 seconds
Number of files: 470
Utilization of max. archive size: 0%
------------------------------------------------------------------------------
                       Original size      Compressed size    Deduplicated size
This archive:               51.16 MB              8.95 MB              8.35 MB
All archives:               52.77 MB              9.60 MB              9.00 MB

                       Unique chunks         Total chunks
Chunk index:                     458                  898
------------------------------------------------------------------------------</code></pre>


### Check & List Backups

* List Backups 

<pre class="command-line" data-user="root" data-host="borg-02" data-output="2-3"><code class="language-bash">borg list borg@172.16.1.236:/home/borg/borg-02
firstBackup                          Sat, 2021-12-11 17:43:09 [882ed726a7115928149aa438af4b78f09d322a34c17dd65f0bf7ce537092ee1b]
secondBackup                         Sat, 2021-12-11 17:44:53 [f61a6d2ce46fc6433a6cfa9cdb1f146933f897c6bce769d071644e7117684cd9]</code></pre>

* Check The Conent Of A Backup

<pre class="command-line" data-user="root" data-host="borg-02" data-output="2-10"><code class="language-bash">borg list borg@172.16.1.236:/home/borg/borg-02::secondBackup
drwx------ root   root          0 Sat, 2021-12-11 17:36:41 root
-rw-r--r-- root   root        161 Tue, 2019-07-09 12:05:50 root/.profile
-rw-r--r-- root   root        571 Sat, 2021-04-10 22:00:00 root/.bashrc
-rw------- root   root        273 Sat, 2021-12-11 17:21:55 root/.bash_history
drwx------ root   root          0 Sat, 2021-12-11 17:26:32 root/.ssh
-rw------- root   root       2602 Sat, 2021-12-11 17:25:59 root/.ssh/id_rsa
-rw-r--r-- root   root        222 Sat, 2021-12-11 17:26:32 root/.ssh/known_hosts
...
... </code></pre>


### Extact Content

For example we want to restore the home direcrory from the `secondBackup`.

<pre class="command-line" data-user="root" data-host="borg-02" data-output="6-12"><code class="language-bash">cd /tmp
mkdir restore
cd restore
borg extract borg@172.16.1.236:/home/borg/borg-02::secondBackup home
find
.
./home
./home/user
./home/user/.bash_history
./home/user/.bash_logout
./home/user/.bashrc
./home/user/.profile </code></pre>

Borg has a really lovely feature: you can mount any of your backup.

### Mount A Backup

Command:
```bash
borg mount borg@172.16.1.236:/home/borg/borg-02::secondBackup /mnt
```

Check:
<pre class="command-line" data-user="root" data-host="borg-02" data-output="2-10"><code class="language-bash">cd /mnt/
ls -la
total 4
drwxr-xr-x  1 root root    0 Dec 11 18:01 .
drwxr-xr-x 18 root root 4096 Nov 21 13:38 ..
drwxr-xr-x  1 root root    0 Dec 11 17:43 etc
drwxr-xr-x  1 root root    0 Nov 21 13:42 home
drwxr-xr-x  1 root root    0 Nov 21 13:35 opt
drwx------  1 root root    0 Dec 11 17:36 root
drwxr-xr-x  1 root root    0 Dec 11 18:01 var </code></pre>

You can browse inside the backup and restore any file you want. 

If you don't need the mount anymore, don't forget to unmount:
```bash
borg umount /mnt
```

### Prune

Assume that you create backups every day. Probably you don't need every backup forever. You can prue your repository and keep only certain amount of backup. For example I use the following parameters to prune the repository:

```bash
borg prune  --stats --keep-daily 3 --keep-weekly 2  --keep-monthly 5 ${REPO_PATH}
```

This will keep 3 daily backup, 2 weekly and 5 monthly. What does it mean? Example:

```plain
Weekly 2:  2021-11-28T02:00:01                  Sun, 2021-11-28 02:00:03 [c1c349e361dc5f..... ]
Monthly 1: 2021-11-30T02:00:01                  Tue, 2021-11-30 02:00:03 [a83f0b4d9d686f..... ]
Weekly 1:  2021-12-05T02:00:01                  Sun, 2021-12-05 02:00:04 [39980ab7451c33..... ]
Daily 3:   2021-12-09T02:00:01                  Thu, 2021-12-09 02:00:02 [daf1c1ea020b16..... ]
Daily 2:   2021-12-10T02:00:01                  Fri, 2021-12-10 02:00:03 [dd6fee702f0593..... ]
Daily 1:   2021-12-11T02:00:01                  Sat, 2021-12-11 02:00:03 [e0385e46a1e968..... ]

```

!!! info
    My script creates backup on every day at 02:00am.

* `keep-daily` --> keeps the last backup of each day. 
* `keep-weekly` --> keeps the last backup from the last `n` Sunday
* `keep-monthly` --> keeps the last backup from the last day of the month

Read more: [https://borgbackup.readthedocs.io/en/stable/usage/prune.html](https://borgbackup.readthedocs.io/en/stable/usage/prune.html)


## Backup With Crontab

I have a little shell script to automatize my daily backup:

```bash
#!/bin/bash

exec > >(logger -i --tag borgbackup) 2>&1

export BORG_PASSCOMMAND="cat $HOME/.borg-passphrase"
REPO_PATH="borg@172.16.1.236:/home/borg/borg-02"
REPO_BCK_DATE="$(date +%FT%T)"
BACKUPS="/etc/ /opt/ /home/ /root"

echo "==================== Creating Backup ===================="
borg create --stats ${REPO_PATH}::${REPO_BCK_DATE} ${BACKUPS}
echo "==================== Prune ===================="
borg prune  --stats --keep-daily 3 --keep-weekly 2  --keep-monthly 5 ${REPO_PATH}
echo "==================== List ===================="
borg list ${REPO_PATH}
```

This script write logs to the `syslog`:

<pre class="command-line" data-user="root" data-host="borg-02" data-output="2-29"><code class="language-bash">cat /var/log/syslog | grep 'borgbackup'
Dec 11 18:23:56 borg-02 borgbackup[4557]: ==================== Creating Backup ====================
Dec 11 18:23:58 borg-02 borgbackup[4557]: ------------------------------------------------------------------------------
Dec 11 18:23:58 borg-02 borgbackup[4557]: Archive name: 2021-12-11T18:23:56
Dec 11 18:23:58 borg-02 borgbackup[4557]: Archive fingerprint: d8be120187e55f630cd4816b3879b2aae83f262a00336c3d20bd62da96dce7fa
Dec 11 18:23:58 borg-02 borgbackup[4557]: Time (start): Sat, 2021-12-11 18:23:56
Dec 11 18:23:58 borg-02 borgbackup[4557]: Time (end):   Sat, 2021-12-11 18:23:57
Dec 11 18:23:58 borg-02 borgbackup[4557]: Duration: 0.37 seconds
Dec 11 18:23:58 borg-02 borgbackup[4557]: Number of files: 444
Dec 11 18:23:58 borg-02 borgbackup[4557]: Utilization of max. archive size: 0%
Dec 11 18:23:58 borg-02 borgbackup[4557]: ------------------------------------------------------------------------------
Dec 11 18:23:58 borg-02 borgbackup[4557]:                        Original size      Compressed size    Deduplicated size
Dec 11 18:23:58 borg-02 borgbackup[4557]: This archive:                1.61 MB            654.31 kB             53.47 kB
Dec 11 18:23:58 borg-02 borgbackup[4557]: All archives:                3.22 MB              1.31 MB            703.21 kB
Dec 11 18:23:58 borg-02 borgbackup[4557]:
Dec 11 18:23:58 borg-02 borgbackup[4557]:                        Unique chunks         Total chunks
Dec 11 18:23:58 borg-02 borgbackup[4557]: Chunk index:                     430                  870
Dec 11 18:23:58 borg-02 borgbackup[4557]: ------------------------------------------------------------------------------
Dec 11 18:23:58 borg-02 borgbackup[4557]: ==================== Prune ====================
Dec 11 18:24:00 borg-02 borgbackup[4557]: ------------------------------------------------------------------------------
Dec 11 18:24:00 borg-02 borgbackup[4557]:                        Original size      Compressed size    Deduplicated size
Dec 11 18:24:00 borg-02 borgbackup[4557]: Deleted data:               -1.61 MB           -654.32 kB            -53.48 kB
Dec 11 18:24:00 borg-02 borgbackup[4557]: All archives:                1.61 MB            654.31 kB            649.73 kB
Dec 11 18:24:00 borg-02 borgbackup[4557]:
Dec 11 18:24:00 borg-02 borgbackup[4557]:                        Unique chunks         Total chunks
Dec 11 18:24:00 borg-02 borgbackup[4557]: Chunk index:                     425                  435
Dec 11 18:24:00 borg-02 borgbackup[4557]: ------------------------------------------------------------------------------
Dec 11 18:24:00 borg-02 borgbackup[4557]: ==================== List ====================
Dec 11 18:24:01 borg-02 borgbackup[4557]: 2021-12-11T18:23:56                  Sat, 2021-12-11 18:23:56 [d8be120187e55f630cd4816b3879b2aae83f262a00336c3d20bd62da96dce7fa] </code></pre>

You can schedule this script using `crontab`:

```crontab
0       2       *       *       *       /root/do-backup.sh
```

## Save Backup To Google Drive

As I mentioned early in this article, one of my important goal is to save my backups to Google Drive. I did not bother too much with this. There is an excellent tool for linux: [Rclone](https://rclone.org)

After configuring `rclone` you can upload the backups to Google Dirve from your central Borg server. Example command:
```bash
rclone sync -P /home/borg/ gdrive:/borgbackup
```

!!! quote
    Sync the source to the destination, changing the destination
    only.  Doesn't transfer unchanged files, testing by size and
    modification time or MD5SUM.  Destination is updated to match
    source, including deleting files if necessary.


!!! info
    Since all of the backups are encrypted we don't need to bother with extra encryption or password protection. 


There are two disadvantages over Duplicati from my point of view: 

* This way we store the backup twice. (On the Borg central server and Google Drive)
* We need a running Borg Server. 
	- This can be avoided. You can create local backups and upload them individually from the hosts.

--- 

**Thank you for reading!**  I don't know if this post was useful for you or not, but I think giving more and more examples is always helpful.



































