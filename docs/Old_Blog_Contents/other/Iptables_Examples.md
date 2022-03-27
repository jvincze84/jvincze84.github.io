# Iptables Examples

!!! caution
    **This page has been updated a long time ago.**  Information found here could be outdated and may lead to missconfiguration.  
    Some of the links and references may be broken or lead to non existing pages.  
    Please use this docs carefully. Most of the information here now is only for reference or example!
    
## Clear All Rules
The following commands will completely clear all your rules (and ACCEPT everything).

```bash
iptables -P INPUT ACCEPT
iptables -P FORWARD ACCEPT
iptables -P OUTPUT ACCEPT
iptables -t nat -F
iptables -t mangle -F
iptables -F
iptables -X
```

---

## Simple NAT

**Situation:**

There are some ISPs in Hungary (and all over the world) which use [Carrier-grade](https://en.wikipedia.org/wiki/Carrier-grade_NAT) NAT and this "feature" makes my life harder.

Devices and Networks:

* Router  
IP address: `192.168.100.1`, Network: `192.168.100.0/24`
* NVR (Network Video Recorder)
  * It connects to the ISP's router. IP address: `192.168.100.4`
  * But it has its own network for IP cameras. (3 eth port and WiFi) IP address: `172.20.18.4`, Network: `172.20.18.0/24`
* Orange PI zero
  * `eth0` - Connected to the router. (`192.168.100.230`)
  * `tun0` - Connected to the OpenVPN server. (`10.50.0.230`)
  * `wlan0` - Connected directly to the NVR over WiFi. (`172.20.18.0.6`)
* For example 3 IP cameras:
  * `172.20.18.3`
  * `172.20.18.4`
  * `172.20.18.5`

==Picture:==
<iframe src="https://drive.google.com/file/d/14VLenZ6yAbd9rQIJzTMbTCO508mhZLdW/preview" width="640" height="480"></iframe>


**Mission:** Access the NVR and the cameras over the VPN network.

So there are three different network:

* 192.168.100.0/24
* 10.50.0.0./16
* 172.20.18.0/24

First we have to determine on which ports the NVR listens. 
```bash title="Command"
nmap 192.168.100.4
```
```text title="Output"

Starting Nmap 7.40 ( https://nmap.org ) at 2018-11-07 10:30 UTC
Nmap scan report for 192.168.100.4
Host is up (0.0015s latency).
Not shown: 995 closed ports
PORT     STATE SERVICE
53/tcp   open  domain
80/tcp   open  http
554/tcp  open  rtsp
5000/tcp open  upnp
8888/tcp open  sun-answerbook
MAC Address: 08:EA:40:56:95:EB (Shenzhen Bilian Electronicltd)

Nmap done: 1 IP address (1 host up) scanned in 2.34 seconds
```


**Solution:**
```bash
iptables -A FORWARD -i tun0 -j ACCEPT
iptables -t nat -A POSTROUTING -o eth0 -j MASQUERADE
iptables -t nat -A PREROUTING -i tun0 -p tcp --dport 80 -j DNAT --to 192.168.100.4:80
iptables -t nat -A PREROUTING -i tun0 -p tcp --dport 554 -j DNAT --to 192.168.100.4:554
iptables -t nat -A PREROUTING -i tun0 -p tcp --dport 8888 -j DNAT --to 192.168.100.4:8888
iptables -t nat -A PREROUTING -i tun0 -p tcp --dport 5000 -j DNAT --to 192.168.100.4:5000
```

It is very important to enable IP(v4) forwarding. 
We can enable it temporary:
```bash
# check: cat /proc/sys/net/ipv4/ip_forward
echo -n 1 >/proc/sys/net/ipv4/ip_forward
```
Or permanently, by adding the following line to `/etc/sysctl.conf` file:
```plain
net.ipv4.ip_forward=1
```

The whole script:
```bash
#!/bin/bash

IFS='
'

iptables -P INPUT ACCEPT
iptables -P FORWARD ACCEPT
iptables -P OUTPUT ACCEPT
iptables -t nat -F
iptables -t mangle -F
iptables -F
iptables -X


echo -n 1 > /proc/sys/net/ipv4/ip_forward

iptables -A FORWARD -i tun0 -j ACCEPT
iptables -t nat -A POSTROUTING -o eth0 -j MASQUERADE
iptables -t nat -A PREROUTING -i tun0 -p tcp --dport 80 -j DNAT --to 192.168.100.4:80
iptables -t nat -A PREROUTING -i tun0 -p tcp --dport 554 -j DNAT --to 192.168.100.4:554
iptables -t nat -A PREROUTING -i tun0 -p tcp --dport 8888 -j DNAT --to 192.168.100.4:8888
iptables -t nat -A PREROUTING -i tun0 -p tcp --dport 5000 -j DNAT --to 192.168.100.4:5000
```

!!! important
    This will enable all traffic, and completely turn the firewall off.
    NOT recommended if you do not have any other firewall in your network and/or your device has public IP address.

And what about the cameras? 
Rules for a camera:

```bash
iptables -A FORWARD -i tun0 -j ACCEPT
iptables -t nat -A POSTROUTING -o wlan0 -j MASQUERADE
iptables -t nat -A PREROUTING -i tun0 -p tcp --dport 80 -j DNAT --to 172.20.18.4:80
iptables -t nat -A PREROUTING -i tun0 -p tcp --dport 554 -j DNAT --to 172.20.18.4:554
iptables -t nat -A PREROUTING -i tun0 -p tcp --dport 34567 -j DNAT --to 172.20.18.4:34567
```

I have never tried but it may be possible to configure `iptables` to access all cameras without reconfigure our rules for each camera. 
Example:
```bash
iptables -t nat -A PREROUTING -i tun0 -p tcp --dport 80 -j DNAT --to 172.20.18.4:80
iptables -t nat -A PREROUTING -i tun0 -p tcp --dport 81 -j DNAT --to 172.20.18.3:80
iptables -t nat -A PREROUTING -i tun0 -p tcp --dport 82 -j DNAT --to 172.20.18.5:80
iptables -t nat -A PREROUTING -i tun0 -p tcp --dport 34567 -j DNAT --to 172.20.18.4:34567
iptables -t nat -A PREROUTING -i tun0 -p tcp --dport 34568 -j DNAT --to 172.20.18.3:34568
iptables -t nat -A PREROUTING -i tun0 -p tcp --dport 34569 -j DNAT --to 172.20.18.5:34569
```
In order to work these rule perfectly the listen ports have to be (re)configured on the IP camera side as well.
But in my scenario it is not so important, because I don't need frequently access directly the cameras.

---

## Permanently Save Iptables rules (on debian(-like) OS)

* **Save the current configuration**  
`iptables-save > /etc/iptables.rules`
* **Restore the saved configuration from file**  
`iptables-restore < /etc/iptables.rules`

For apply `iptables` rules on startup use this little script:
```bash
cat <<EOF>/etc/network/if-pre-up.d/firewall
#!/bin/bash
/sbin/iptables-restore < /etc/iptables.rules
EOF

chmod +x /etc/network/if-pre-up.d/firewall
```

---
## Port Forwarding To Another Host

**My scenario:**
I wanted to access RTSP port (554) of multiple IP cameras over one host (Gateway).

Host IP address: `172.16.0.230`
IP adress of cameras: `172.19.1.1`-`172.19.1.8`
RTSP listen port: `554`

Rules: 
```bash
iptables -t nat -A PREROUTING -p tcp --dport 5541 -j DNAT --to-destination 172.19.1.1:554 
iptables -t nat -A POSTROUTING -p tcp -d 172.19.1.1 --dport 554 -j SNAT --to-source  172.16.0.230 

iptables -t nat -A PREROUTING -p tcp --dport 5542 -j DNAT --to-destination 172.19.1.2:554 
iptables -t nat -A POSTROUTING -p tcp -d 172.19.1.2 --dport 554 -j SNAT --to-source  172.16.0.230 


iptables -t nat -A PREROUTING -p tcp --dport 5543 -j DNAT --to-destination 172.19.1.3:554 
iptables -t nat -A POSTROUTING -p tcp -d 172.19.1.3 --dport 554 -j SNAT --to-source  172.16.0.230 

etc.
```

The script with traffic monitoring:
```bash
#!/bin/bash

IFS='
'
iptables -P INPUT ACCEPT
iptables -P FORWARD ACCEPT
iptables -P OUTPUT ACCEPT
iptables -t nat -F
iptables -t mangle -F
iptables -F
iptables -X


echo -n 1 > /proc/sys/net/ipv4/ip_forward

iptables -A INPUT  -p tcp -m state --state NEW   -j LOG --log-prefix "INPUT: "
iptables -A OUTPUT  -p tcp -m state --state NEW   -j LOG --log-prefix "OUTPUT: "

iptables -t nat -A PREROUTING  -p tcp  -j LOG --log-prefix "PREROUTING: "
iptables -t nat -A POSTROUTING  -p tcp  -j LOG --log-prefix "POSTROUTING: "


###
## Traffic
###
iptables -N trafficmon
iptables -A FORWARD -p tcp --sport 554 -m comment --comment "ALL" -j trafficmon



LOCAL_IP="172.16.0.230"

LISTEN=1554

#  NAME | IP | PORT | URL

CAMS[0]="Pool|172.19.1.1|554|ucast/11"
CAMS[1]="Garden|172.19.1.2|554|11"
CAMS[2]="Garage|172.19.1.3|554|user=admin_password=tlJwpbo6_channel=1_stream=0.sdp?real_stream"
CAMS[3]="Workshop|172.19.1.4|554|user=admin_password=tlJwpbo6_channel=1_stream=0.sdp?real_stream"
CAMS[4]="Backyard|172.19.1.5|554|user=admin_password=tlJwpbo6_channel=1_stream=0.sdp?real_stream"
CAMS[5]="Gate|172.19.1.6|554|user=admin_password=tlJwpbo6_channel=1_stream=0.sdp?real_stream"
CAMS[6]="Street|172.19.1.7|554|user=admin_password=tlJwpbo6_channel=1_stream=0.sdp?real_stream"
CAMS[7]="Corridor|172.19.1.8|554|11"


for CAM in ${CAMS[@]}
do
  NAME=$( echo $CAM | cut -f 1 -d"|" )
  IPADDR=$( echo $CAM | cut -f 2 -d"|" )
  PORT=$( echo $CAM | cut -f 3 -d"|" )
  URL=$( echo $CAM | cut -f 4 -d"|" )

  echo "URL : rtsp://$LOCAL_IP:$LISTEN/$URL (### $NAME ###)"

  iptables -t nat -A PREROUTING -p tcp --dport $LISTEN -j DNAT --to-destination $IPADDR:$PORT -m comment --comment "$NAME"
  iptables -t nat -A POSTROUTING -p tcp -d $IPADDR --dport $PORT -j SNAT --to-source $LOCAL_IP -m comment --comment "$NAME"
  iptables -A FORWARD -p tcp --sport 554 --source $IPADDR -m comment --comment "$NAME" -j trafficmon

  (( LISTEN ++ ))
done



cat <<EOF
Please Run

iptables-save > /etc/iptables.rules

to make rules permanent!
EOF
```

---

## IPTABLES quick commands & Cheat Sheets

```plain
manage chain:
# iptables -N new_chain				// create a chain
# iptables -E new_chain old_chain  		// edit a chain
# iptables -X old_chain				// delete a chain

redirecting packet to a user chain:
# iptables -A INPUT -p icmp -j new_chain

listing rules:
# iptables -L					// list all rules of all tables
# iptables -L -v				// display rules and their counters
# iptables -L -t nat				// display rules for a specific tables
# iptables -L -n --line-numbers			// listing rules with line number for all tables
# iptables -L INPUT -n --line-numbers		// listing rules with line number for specific table

manage rules:
# iptables -A chain				// append rules to the bottom of the chain
# iptables -I chain [rulenum]			// insert in chain as rulenum (default at the top or 1)
# iptables -R chain rulenum			// replace rules with rules specified for the rulnum
# iptables -D chain	rulenum			// delete rules matching rulenum (default 1)
# iptables -D chain				// delete matching rules

change default policy:
# iptables -P chain target			// change policy on chain to target
# iptables -P INPUT DROP			// change INPUT table policy to DROP
# iptables -P OUTPUT DROP			// change OUTPUT chain policy to DROP
# iptables -P FORWARD DROP			// change FORWARD chain policy to DROP
```
==Reference:== [iptables-quick-command-list/](http://raynux.com/blog/2009/04/15/iptables-quick-command-list/)


















