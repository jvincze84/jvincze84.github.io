!!! caution
    **This page has been updated a long time ago.**  Information found here could be outdated and may lead to missconfiguration.  
    Some of the links and references may be broken or lead to non existing pages.  
    Please use this docs carefully. Most of the information here now is only for reference or example!
    
# Google Cloud Print With Orange PI (or RPI)


## -1. Update your system & Install Requirements
```bash
apt-get update
apt-ge upgrade
apt-get install gcc make # If they aren't installed (for golang)
apt-get install build-essential libcups2-dev libavahi-client-dev git bzr # for cloud connector
```

## 0. Install Go Language
Install go lang. You can follow "Compile GO language on Raspberry PI" to complete this step. 
I don't want to write detailed install steps here, instead of I paste only the commands to this chapter without any / detailed comments. (Maybe it will helpful for someone).

##1. Clone Go 
```bash
mkdir /opt/go/
cd /opt/go/
git clone https://github.com/golang/go`
```

##2. Checkout Go 
```bash
cd /opt/go/go
git tag -l
cd ..
mv go go1.4.3
cp -r go1.4.3 go1.6.3
cd go1.4.3/
git checkout go1.4.3 
cd /opt/go/go1.6.3
git checkout go1.6.3 
```

##3. Compile GO 1.4.3
```
export GOARCH="arm"
export GOOS="linux"
export GOARM="7"
cd /opt/go/go1.4.3/src
/opt/go/go1.4.3/src
./all.bash | tee -a output.log
```
Sample Output: [Link](https://drive.google.com/file/d/0B4xTxuaiVCZyUnNVTF9ncFo1VnM/view?usp=sharing)

##4. Set System environments 
```bash
export GOROOT_BOOTSTRAP="/opt/go/go1.4.3"  
export GOROOT="/opt/go/go1.4.3"  
export GOROOT_BOOTSTRAP="$GOROOT"  
export GOPATH="$GOROOT/src"  
export PATH="$PATH:$GOROOT/bin" 
export GOARCH="arm"
export GOOS="linux"
export GOARM="7"
```

##5. Some Performance tuning
```bash
fallocate --length 2GiB /root/2G.swap  
chmod 0600 /root/2G.swap  
mkswap /root/2G.swap  
swapon /root/2G.swap 

ulimit -s 65536
```

##6. Compile GO 1.6.3
```bash
cd /opt/go/go1.6.3/src
./all.bash | tee -a output.log
```
Sample output: [Link](https://drive.google.com/file/d/0B4xTxuaiVCZyVnJzdXVHS1FzVFE/view?usp=sharing)

##7. Set System Environments to use go1.6.3.
You should unset all GO related ENV, or logout from current shell and create new shell.
```bash
export GOROOT_BOOTSTRAP="/opt/go/go1.4.3"  
export GOROOT="/opt/go/go1.6.3"  
export GOROOT_BOOTSTRAP="$GOROOT"  
export GOPATH="$GOROOT/src"  
export PATH="$PATH:$GOROOT/bin"  
export GOARCH="arm"
export GOOS="linux"
export GOARM="7"
```

**Check:**
```
go version
go version go1.6.3 linux/arm
```
Your GO is ready to use. :)


## Install Google Cloud Print connector

Simply run the following command:
`go get github.com/google/cloud-print-connector/...`  
Go will download and install packages and dependencies.

Q: What means `...`?
A: if you want all packages in that repository, use `... `

==**Reference:**==  
https://github.com/google/cloud-print-connector/wiki/Build-from-source
Run automatically on system boot (systemd):
https://github.com/google/cloud-print-connector/wiki/Run-Connector-Automatically-on-Boot

This will create two new files to `/opt/go/go1.6.3/src/bin` directory:
```bash
root@OrangePI:/opt/go/go1.6.3/src/bin# ls -al
total 17504
drwxr-xr-x  2 root root    4096 Sep  6 13:11 .
drwxr-xr-x 47 root root    4096 Sep  6 13:11 ..
-rwxr-xr-x  1 root root 8358992 Sep  6 13:11 gcp-connector-util
-rwxr-xr-x  1 root root 9554384 Sep  6 13:11 gcp-cups-connector
```

And the source is available int `/opt/go/go1.6.3/src/src/github.com/google/cloud-print-connector`

### Configure Google Cloud Print connector

To configure Google Cloud Print (GCP) you simply run `gcp-connector-util` from `/opt/go/go1.6.3/src/bin` directory, answer some question.

```bash
root@OrangePI:/opt/go/go1.6.3/src/bin# ./gcp-connector-util init
"Local printing" means that clients print directly to the connector via
local subnet, and that an Internet connection is neither necessary nor used.

Enable local printing?
yes

"Cloud printing" means that clients can print from anywhere on the Internet,
and that printers must be explicitly shared with users.
Enable cloud printing?
yes

Retain the user OAuth token to enable automatic sharing?
no

Proxy name for this connector:
opi_sam_ml1510

Visit https://www.google.com/device, and enter this code. I'll wait for you.
GGVY-****
```

At this point you have to login to your google account, visit https://www.google.com/device and give your code. 
After you enter your code you will get the following message on linux box:

```
The config file /opt/go/go1.6.3/src/bin/gcp-cups-connector.config.json is ready to rock.
Keep it somewhere safe, as it contains an OAuth refresh token.
```

The next step is checking the configuration:  

* Start GCP connector:  
`./gcp-cups-connector --config-filename gcp-cups-connector.config.json --log-to-console`
* Check your printer by visiting https://www.google.com/cloudprint/#printers website.If everything went fine you should see your printer. 

The last step is change log file location by editing `gcp-cups-connector.config.json`, and modify `log_file_name` entry according to where you want to save logs.

Run in the background:
`nohup ./gcp-cups-connector --config-filename gcp-cups-connector.config.json &`

### Run Automatically On boot

If you want to start GCP at system boot follow these steps.
**==Reference:==**  
https://github.com/google/cloud-print-connector/wiki/Run-Connector-Automatically-on-Boot

* You can find a sample config file in `/opt/go/go1.6.3/src/src/github.com/google/cloud-print-connector/systemd` directory.
* Make a backup:  
`cp cloud-print-connector.service cloud-print-connector.service-orig`
* Edit this file. Modify `ExecStart` and `User` property to this:  
`ExecStart=/opt/go/go1.6.3/src/bin/gcp-cups-connector -config-filename /opt/go/go1.6.3/src/bin/gcp-cups-connector.config.json`  
`User=root`
* Install systemd service:  
`install -o root -m 0660 cloud-print-connector.service /etc/systemd/system`
* Enable the service:  
`systemctl enable cloud-print-connector.service`
* Start service:  
`systemctl start cloud-print-connector.service`
* Check status:  
`systemctl status cloud-print-connector.service`

Done. :)
Now everytime you restart your OPI GCP will start automatically.

**==Update==**  

Unfortunately GCP can't start at boot time because of the following error:
```
systemctl status  cloud-print-connector.service
â— cloud-print-connector.service - Google Cloud Print Connector
   Loaded: loaded (/etc/systemd/system/cloud-print-connector.service; enabled)
   Active: failed (Result: start-limit) since Thu 1970-01-01 00:24:04 UTC; 46 years 8 months ago
     Docs: https://github.com/google/cloud-print-connector
  Process: 867 ExecStart=/opt/go/go1.6.3/src/bin/gcp-cups-connector --config-filename /opt/go/go1.6.3/src/bin/gcp-cups-connector.config.json (code=exited, status=1/FAILURE)
 Main PID: 867 (code=exited, status=1/FAILURE)

Jan 01 00:24:03 OrangePI systemd[1]: Unit cloud-print-connector.service entered failed state.
Jan 01 00:24:04 OrangePI systemd[1]: cloud-print-connector.service holdoff time over, scheduling restart.
Jan 01 00:24:04 OrangePI systemd[1]: Stopping Google Cloud Print Connector...
Jan 01 00:24:04 OrangePI systemd[1]: Starting Google Cloud Print Connector...
Jan 01 00:24:04 OrangePI systemd[1]: cloud-print-connector.service start request repeated too quickly, refusing to start.
Jan 01 00:24:04 OrangePI systemd[1]: Failed to start Google Cloud Print Connector.
Jan 01 00:24:04 OrangePI systemd[1]: Unit cloud-print-connector.service entered failed state.
```

I've checked the log files and I saw that after boot the log file was accessed in 1970, and the log entries was also from 1970:
```
I [01/Jan/1970:00:24:03 +0000] Using config file /opt/go/go1.6.3/src/bin/gcp-cups-connector.config.json
I [01/Jan/1970:00:24:03 +0000] Cloud Print Connector for CUPS version DEV-linux
X [01/Jan/1970:00:24:03 +0000] While starting XMPP, failed to get access token (password): Post https://accounts.google.com/o/oauth2/token: x509: certificate has expired or is not yet valid
```

Based on these errors I tried to modify "After" in cloud print service file to start service after ntp.service and some other services:
`After=cups.service avahi-daemon.service network-online.target ntp.service networking.service exim4.service ssh.service NetworkManager.service wpa_supplicant.service`  
But It did not help. After some tries I gave up and wrote a shell script to start this service:
```bash
#!/bin/bash
IFS='
'

ps aux| grep -v grep  | grep -q gcp-cups-connector
if [ $? -eq 0 ]
then
echo "Already running"
exit 0
fi

OK=0
while [ $OK -eq 0 ]
do
  YEAR=$( date +%Y )
  if [ $YEAR -gt 2015 ]
  then 
    echo ok
    OK=1
    /opt/go/go1.6.3/src/bin/gcp-cups-connector --config-filename /opt/go/go1.6.3/src/bin/gcp-cups-connector.config.json
  else
    echo "Sleep for 1 secs"
    sleep 1
  fi
 
done
```
This little script check the year in every sec and if it is grater then 2015 the GCP will be started. 

The problem was:

* OrangePI has no built in (hw) clock, thus before the ntp service start it doesn't know the current time.
* GCP was started before the network service came up that's why it could not connect to google service (this happened despite my modification on service file (after property)).














