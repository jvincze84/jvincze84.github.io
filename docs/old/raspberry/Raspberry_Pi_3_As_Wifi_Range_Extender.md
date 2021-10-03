!!! caution
    **This page has been updated a long time ago.**  Information found here could be outdated and may lead to missconfiguration.  
    Some of the links and references may be broken or lead to non existing pages.  
    Please use this docs carefully. Most of the information here now is only for reference or example!
    
# Raspberry PI 3 As Wifi Range Extender


## TL;DR

I have a Workshop in our backyard, and there are some ESPs inside. Unfortunately my router is far away from them and the Wifi connection often breaks. This is a real problem for me because the ESPs are controlling my lighting in the garden and it's a bit irritating when I cannot turn on the lights. (The ESPs automatically turn off all relay channels when the Wifi disconnects, so turning off is not an issue.)
As I have wired LAN access (almost) everywhere in my house and even in my Workshop I was thinking about how to extend my Wifi range. OK. I know. There are a lot of possibilities to do it, but I wanted to choose the best and the most reliable way, and I wanted to use something I have already have.  
I use a Mikrotik router with a lot of switches all around the house. Since I don't like Wifi networks I'm trying to connect as much devices as I can wired to my network, but the ESPs needs Wifi connection. There is a  Raspberry PI3 already running in the workshop so it is reasonable to use that. Of course the PI has Ethernet connection to my Mikrotik router. :)

==Update:== I haven't published this post yet, and I've already had an update.   
~~To make it work was much easier than I thought.~~ --> To make it work was much complicated then I've ever thought and took more days. :(

As you will see I faced a lot of problems. But I want to believe that this post will be helpful. 

## Install the necessary packages

```bash
sudo apt-get install hostapd bridge-utils wicd wicd-cli wpasupplicant
```

During the installation the wicd-daemon will ask you for the list of users who can use the wicd client. 
>  Users who should be able to run wicd clients need to be added to the group "netdev".

You can modify these settings later by running `dpkg-reconfigure wicd-daemon` command.

## Configuring Bridge Interface

My setup looks like that:
```bash
auto lo
iface lo inet loopback
iface eth0 inet manual
iface wlan0 inet manual
auto br0
iface br0 inet dhcp
  bridge_ports eth0 
  bridge_stp off
  bridge_fd 0
  bridge_maxwait 0
  bridge_waitport 0
```

Now you should restart your PI, after that you can check your config:

<pre class="command-line" data-user="root" data-host="raspberrypi" data-output="2-4"><code class="language-bash">brctl show
bridge name	bridge id		STP enabled	interfaces
br0		8000.b827eb26993d	no		eth0
</code></pre>

## Check Wifi Device & Configure Hostapd

First it is recommended to **check if your Wireless device supports AP mode** or not. It is only necessary for example if you are using an RPI which is older than PI3. (RPI3 has built-n WiFi chip, which supports AP mode.)

* **Check your interface list**
<pre class="command-line" data-user="root" data-host="raspberrypi" data-output="2-8"><code class="language-bash">iw dev  
phy#0
	Interface wlan0
		ifindex 3
		wdev 0x1
		addr b8:27:eb:73:cc:68
		type managed
</code></pre>

You can see I have only one interface: `phy#0`. Here is an example when there are multiple interfaces:

<pre class="command-line" data-user="root" data-host="raspberrypi" data-output="2-18"><code class="language-bash">iw dev  
phy#1
	Interface wlan1
		ifindex 4
		wdev 0x100000001
		addr 00:e0:32:00:00:8b
		type managed
		channel 8 (2447 MHz), width: 20 MHz, center1: 2447 MHz
phy#0
	Interface wlan0
		ifindex 3
		wdev 0x1
		addr b8:27:eb:f9:dd:be
		ssid Vinyo-Net
		type AP
		channel 2 (2417 MHz), width: 20 MHz, center1: 2417 MHz
</code></pre>

* **Check "Supported interface modes"**

<pre class="command-line" data-user="root" data-host="raspberrypi" data-output="2-29"><code class="language-bash">iw phy phy0 info
Wiphy phy0
	max # scan SSIDs: 10
	max scan IEs length: 2048 bytes
	Retry short limit: 7
	Retry long limit: 4
	Coverage class: 0 (up to 0m)
	Device supports T-DLS.
	Supported Ciphers:
		* WEP40 (00-0f-ac:1)
		* WEP104 (00-0f-ac:5)
		* TKIP (00-0f-ac:2)
		* CCMP (00-0f-ac:4)
	Available Antennas: TX 0 RX 0
	Supported interface modes:
		 * IBSS
		 * managed
		 * AP
		 * P2P-client
		 * P2P-GO
		 * P2P-device
	Band 1:
		Capabilities: 0x1020
			HT20
			Static SM Power Save
			RX HT20 SGI
			No RX STBC
			Max AMSDU length: 3839 bytes
			DSSS/CCK HT40
...
...
</code></pre>


As you can see, our built-in Wifi device supports the AP mode.
(By running this command (`iw phy phy0 info`) you get a lot of information about your Wifi device.)

* **Configure Hostapd**

I don't know why, but the /etc/hostapd directory does not contain default/sample configuration file, but you can find sample configuration files here: `/usr/share/doc/hostapd/examples`
I used this command to get examples:

```bash
gunzip -c /usr/share/doc/hostapd/examples/hostapd.conf.gz | less
```

I advise you to use a different SSID firstly then you already have to test a vanilla setup.

Here is working example file:

```plain
ctrl_interface=/var/run/hostapd
macaddr_acl=0 
driver=nl80211
interface=wlan0
bridge=br0
country_code=HU
hw_mode=g
ieee80211n=1
channel=2
ssid=WS-TST-01
auth_algs=1
ignore_broadcast_ssid=0
wpa=2
wpa_passphrase=12345678
wpa_key_mgmt=WPA-PSK
wpa_pairwise=CCMP
rsn_pairwise=CCMP
```

!!! warning
	Use a channel which is different from the one your primary device uses.

![](/assets/images/2017/08/wirelessfreqchart.png)


After the configuration file is created you can try to start hostapd.

```bash hl_lines="1"
hostapd /etc/hostapd/hostapd.conf 
Configuration file: /etc/hostapd/hostapd.conf
Failed to create interface mon.wlan0: -95 (Operation not supported)
wlan0: interface state UNINITIALIZED->COUNTRY_UPDATE
wlan0: Could not connect to kernel driver
Using interface wlan0 with hwaddr b8:27:eb:73:cc:68 and ssid "WS-TST-01"
wlan0: interface state COUNTRY_UPDATE->ENABLED
wlan0: AP-ENABLED 
```

We get two error messages:

* `Failed to create interface mon.wlan0: -95 (Operation not supported)`
* `wlan0: Could not connect to kernel driver`

I did a lot of Google searches, but failed to find any solution for this issue. Despite the failures the "AP-ENABLED" messages shows us that everything should work.
Now you can try to connect your new Wifi AP: `WS-TST-01`

* **Enable Auto Start hostapd daemon**

By default the hostapd doesn't start at boot time. To enable it change this file:

```diff
--- hostapd_orig    2017-08-15 11:14:58.673575799 +0200
+++ hostapd    2017-08-14 21:25:47.684546287 +0200
@@ -7,7 +7,7 @@
 # file and hostapd will be started during system boot. An example configuration
 # file can be found at /usr/share/doc/hostapd/examples/hostapd.conf.gz
 #
-DAEMON_CONF=""
+DAEMON_CONF="/etc/hostapd/hostapd.conf"

 # Additional daemon options to be appended to hostapd command:-
 #     -d   show more debug messages (-dd for even more)
```

**At this point** I was facing a very strange and serious issue. :( It took days to find a working solution or only a workaround instead. 

The problem: After restarting my PI everything seemed fine, but none of devices could see the SSID. But it could be solved with restarting the hostapd daemon. At the bottom of this post in the references section you can find some article which discuss similar issues, but without any "real" solution (only workarounds). (Example: control the hostapd daemon from interface config, ifup.d). 

Now I sharing you my experiences I got during the investigation, It may (or may not) be useful.
You have to know I made uncountable tries to configure hostapd, dhcpcd, dhcp-client, bridge, etc, but none of them led to success. 

**1. Replace the original System V init service to systemd.**

By default the hostapd daemon is started by an init.d scripts  (/etc/init.d/hostapd). I wanted to move the service start to the end of the boot process to make sure that every necessary service started before hostapd. So I wrote a custom systemd config file and removed it from /etc/rc3.d.

My SystemD script:

```
[Unit]
Description=HOSTAPD
Requires=multi-user.target network-online.target avahi-daemon.service smbd.service
After=avahi-daemon.service smbd.service multi-user.target

[Service]
Type=forking
GuessMainPID=yes  
ExecStart=/usr/sbin/hostapd -d -t -B -P /run/hostapd.pid -f /var/log/hostapd.log /etc/hostapd/hostapd.conf
ExecStop=/usr/bin/kill -SIGINT $MAINPID  
PIDFile=/run/hostapd.pid
Restart=always
User=root

[Install]
WantedBy=multi-user.target
```

You can check the boot order by issuing the command (after reboot):

```bash
systemd-analyze plot >/tmp/plot3.svg
```

This .svg file can be opened with any type of browser. I saw that the hostapd service was started almost at the end of the boot process (I think it was the penultimate one before systemd-update-utmp-runlevel.service and after the multi-user.target).

But It did not solved my problem.

**2. Restart hostapd daemon after the IP address bounded (br0)**

I was reading the log files a lot, and found that something happens after the boot process has been finished with the interfaces (br0,wlan0,eth0):

In the log files you can see that the boot process has been finished at 11:09:11.
`Aug 26 11:09:11 ws-rpi3 systemd[1]: Startup finished in 3.918s (kernel) + 29.036s (userspace) = 32.954s.`

But after some seconds:
```log
Aug 26 11:09:14 ws-rpi3 kernel: [   36.241794] smsc95xx 1-1.1:1.0 eth0: hardware isn't capable of remote wakeup
Aug 26 11:09:14 ws-rpi3 kernel: [   36.242140] br0: port 1(eth0) entered disabled state
Aug 26 11:09:14 ws-rpi3 kernel: [   36.342138] smsc95xx 1-1.1:1.0 eth0: hardware isn't capable of remote wakeup
Aug 26 11:09:14 ws-rpi3 kernel: [   36.342435] br0: port 1(eth0) entered blocking state
Aug 26 11:09:14 ws-rpi3 kernel: [   36.342446] br0: port 1(eth0) entered forwarding state
Aug 26 11:09:14 ws-rpi3 kernel: [   36.474142] smsc95xx 1-1.1:1.0 eth0: hardware isn't capable of remote wakeup
Aug 26 11:09:14 ws-rpi3 kernel: [   36.474380] br0: port 1(eth0) entered disabled state
Aug 26 11:09:14 ws-rpi3 dhcpcd[1046]: dhcpcd not running
Aug 26 11:09:14 ws-rpi3 kernel: [   36.591789] smsc95xx 1-1.1:1.0 eth0: hardware isn't capable of remote wakeup
Aug 26 11:09:14 ws-rpi3 kernel: [   36.592070] br0: port 1(eth0) entered blocking state
Aug 26 11:09:14 ws-rpi3 kernel: [   36.592074] br0: port 1(eth0) entered forwarding state
Aug 26 11:09:16 ws-rpi3 kernel: [   38.073773] smsc95xx 1-1.1:1.0 eth0: link up, 100Mbps, full-duplex, lpa 0xC5E1
Aug 26 11:09:16 ws-rpi3 dhcpcd[1051]: version 6.7.1 starting
Aug 26 11:09:16 ws-rpi3 dhcpcd[1051]: eth0: interface not found or invalid
Aug 26 11:09:16 ws-rpi3 dhcpcd[1051]: exited
Aug 26 11:09:21 ws-rpi3 dhcpcd[1089]: dhcpcd not running
Aug 26 11:09:21 ws-rpi3 kernel: [   43.735165] brcmfmac: power management disabled
Aug 26 11:09:22 ws-rpi3 dhcpcd[1113]: dhcpcd not running
Aug 26 11:09:22 ws-rpi3 kernel: [   43.866789] smsc95xx 1-1.1:1.0 eth0: hardware isn't capable of remote wakeup
Aug 26 11:09:22 ws-rpi3 kernel: [   43.866935] br0: port 1(eth0) entered disabled state
Aug 26 11:09:22 ws-rpi3 kernel: [   43.962974] smsc95xx 1-1.1:1.0 eth0: hardware isn't capable of remote wakeup
Aug 26 11:09:22 ws-rpi3 kernel: [   43.963452] br0: port 1(eth0) entered blocking state
Aug 26 11:09:22 ws-rpi3 kernel: [   43.963460] br0: port 1(eth0) entered forwarding state
Aug 26 11:09:23 ws-rpi3 kernel: [   45.581772] smsc95xx 1-1.1:1.0 eth0: link up, 100Mbps, full-duplex, lpa 0xC5E1
```

This is the only possible reason I could find. For some reason the interfaces changed to down and up again. I run the ping command from a remote machine and during this period the packages were lost.
(When I was fast I could see the SSID on my phone for some seconds before it disappeared.)

Here I was facing another big issue. I could not find any errors in the log files or anything else on the RPI side with which the restart could have been triggered. This means that everything seemed fine on the RPI side, but the SSID was not visible. 

First I thought it is a good idea to restart hostapd daemon when the br0 get the IP address from the DHCP server (BOUND), but it wasn't. :( The dhcp client "only" renews the IP address. 

Only for information I paste here my dhcp related config (`/etc/dhcp/dhclient-enter-hooks.d/jvincze_custom`):

```bash
#!/bin/sh

case "$reason" in

    BOUND)
        echo "[ $(date +%F\ %T ) ] - ($0) DHCP REASON: $reason ($new_ip_address , $interface)" >>/var/log/jvinczedhcp.log
        PID=$( ps aux|grep hostapd | grep -v grep | awk '{print $2}' )
        if [ ! -z $PID ] 
        then
          echo "[ $(date +%F\ %T ) ] - KILLING $PID pid" >>/var/log/jvinczedhcp.log
          sleep 30
          kill $PID
        fi
        ;;
    *)
        echo "[ $(date +%F\ %T ) ] - ($0) DHCP REASON: $reason ($new_ip_address , $interface)" >>/var/log/jvinczedhcp.log
       ;; 

esac
```

First I tried this (instead of killing the process):

```bash
#[ ! -z $PID ] && while kill $PID  2> /dev/null;  do sleep 1 ;  done;
#sleep 4
#/usr/sbin/hostapd -t -B -P /run/hostapd.pid -f /var/log/hostapd.log /etc/hostapd/hostapd.conf
```
I did not like this, because this file contains the command line parameter of hostapd. It is not a "real" problem, but with this way this file has to be synchronized with the .service file.

After I slept a bit I found out that I can kill the process if I use `Restart=always` and `Type=forking` in the .service file (systemd will restart the process when it's dead/killed/etc.)

But nothing changed. :(

It could be a solution to modify the script to restart hostapd daemon when ip address is renewed, but in case of long lease time I could lose the wifi connection for hours. (And I did not want to change a network parameter which affects my entire network and devices.)

==NOTE:== After finding my final WA, I did not remove this script to make sure if the interface br0 get a new ip address hostapd will be restarted. (I don't know if it is necessary or not, but think this won't cause further problems.) 
If you have more than one interface using dhcp to assign IP address you can write an "if" condition to specify the interface to check. Example:

```bash
if [ ! -z $PID ] || [ "$interface" == "br0" ] ; then
```

**3. Another tries**

Start hostapd from systemd with this command line options:
```
ExecStart=/usr/sbin/hostapd -d -S -P /run/hostapd.pid -f /var/log/hostapd.log /etc/hostapd/hostapd.conf
```

After the RPI restarted, I stopped hostapd, backed-up/removed the hostapd.log files, and started the hostapd (again). Then I compared the two log files.

You can download my diff file from here: [LINK](https://drive.google.com/file/d/0B4xTxuaiVCZyTklFaEJRVzBtZ1E/view?usp=sharing)
Example .svg file. [LINK](https://drive.google.com/file/d/0B4xTxuaiVCZyczg3Wm5vY2xEeXc/view?usp=sharing)

I tried to find something special to search in google, but all of my searches led to nothing. :( So I finally gave up searching in the log files. It is obvious that this behavior was caused by the interface changes after boot. Syslog:
```
...
Aug 30 21:05:33 ws-rpi3 kernel: [   44.726888] br0: port 2(wlan0) entered disabled state
Aug 30 21:05:33 ws-rpi3 dhcpcd[1020]: dhcpcd not running
Aug 30 21:05:33 ws-rpi3 kernel: [   44.969033] smsc95xx 1-1.1:1.0 eth0: hardware isn't capable of remote wakeup
Aug 30 21:05:33 ws-rpi3 kernel: [   44.969368] br0: port 1(eth0) entered disabled state
...
```

Of course I did a lot of search for syslog entries but I could not find any relating, or useful article. 



**4. Final Solution (WA)**

I tried a lot of things in order to make this work, but the only way is the "delayed start". :(

I completely disabled the hostapd service and restarted the PI, waited some time (~1min) and started the hostapd daemon. Everything was fine. Now the "only" thing was to figuring out how to start hostapd service delayed. 

My first solution was this (.service file):
```bash
[Service]
ExecStartPre=/bin/sleep 30
```
It is a working but ugly workaround. With this method the whole boot process is delayed. :( And you can see in the boot order (.svg) that the hostapd starting process take +30s compared with the "normal" case. :(

Finally I set up a systemd timer:

* **hostapd.timer**

<pre class="command-line" data-user="root" data-host="raspberrypi" data-output="2-12"><code class="language-bash">cat /lib/systemd/system/hostapd.timer
[Unit]
Description=Runs hostapd
After=multi-user.target

[Timer]
OnBootSec=1min
Unit=hostapd.service

[Install]
WantedBy=multi-user.target</code></pre>

I think 1 minute enough delay after boot to start hostapd.  

* **hostapd.service**

```bash
cat /lib/systemd/system/hostapd.service 
[Unit]
Description=HOSTAPD
Requires=multi-user.target network-online.target avahi-daemon.service smbd.service
After=avahi-daemon.service smbd.service multi-user.target sockets.targee

[Service]
Type=forking
GuessMainPID=yes  
ExecStart=/usr/sbin/hostapd -d -t -B -P /run/hostapd.pid -f /var/log/hostapd.log /etc/hostapd/hostapd.conf
#ExecStart=/usr/sbin/hostapd -d -S -t -B -P /run/hostapd.pid -f /var/log/hostapd.log /etc/hostapd/hostapd.conf
#ExecStart=/usr/sbin/hostapd -t -B  -f /var/log/hostapd.log /etc/hostapd/hostapd.conf
ExecStop=/usr/bin/kill -SIGINT $MAINPID  
PIDFile=/run/hostapd.pid
Restart=always
User=root

#[Install]
#WantedBy=multi-user.target
```
Commands:
<pre class="command-line" data-user="root" data-host="raspberrypi" data-output="3,5"><code class="language-bash">systemctl daemon-reload
systemctl disable hostapd.service
Removed symlink /etc/systemd/system/multi-user.target.wants/hostapd.service.
systemctl enable hostapd.timer
Created symlink from /etc/systemd/system/multi-user.target.wants/hostapd.timer to /lib/systemd/system/hostapd.timer.
</code></pre>

## Final Thoughts

When I started to write this post I thought configuring hostapd must consist of some easy steps. Actually it is right because configuring hostapd is pretty easy, I had(/have) problems with autostart on boot time. 

I have been running this setup since weeks without any problem. Maybe later when I have time for this, I'll continue the investigation, or maybe in the future there will be a new kernel and/or hostapd daemon with which this problem won't occur.

If you have any idea how to solve this please let me a post on Disqus.  :)


## Some Useful Commands

* **Check Connected Devices**

```bash
hostapd_cli all_sta
```

* **Check Connected Devices (only MAC addresses)**

```bash
hostapd_cli all_sta | grep  -E '^([0-9|a-f|A-F]{2,2}\:?){6,6}'
```

* **Check Connected Devices & Query MAC address on MIKROTIK router**

<pre class="command-line" data-user="root" data-host="raspberrypi" data-output="2-6"><code class="language-bash">for MAC in $(hostapd_cli all_sta | grep  -E '^([0-9|a-f|A-F]{2,2}\:?){6,6}'); do echo "########## $MAC ##########" ; ssh admin@172.16.0.1 "ip dhcp-server lease print where mac-address=$MAC" ; done
########## 60:01:94:08:31:48 ##########
Flags: X - disabled, R - radius, D - dynamic, B - blocked
 # ADDRESS                                      MAC-ADDRESS       HO SER.. RA
 0   172.20.0.15                                  60:01:94:08:31:48 NO def..
</code></pre>



* **Check bridge interface**
<pre class="command-line" data-user="root" data-host="raspberrypi" data-output="2-4"><code class="language-bash">brctl show
bridge name	bridge id		STP enabled	interfaces
br0		8000.b827eb26993d	no		eth0
							wlan0
</code></pre>

==NOTE:== If the hostapd have been started successfully you have to see WLAN0 in the interface list.

* **Analyze boot order**

```bash
systemd-analyze plot >/tmp/plot.svg
```

You can open the created file in your browser.

* **Enable packet forwarding by kernel**

```bash
echo 1 > /proc/sys/net/ipv4/ip_forward
iptables --append FORWARD --in-interface eth1 -j ACCEPT
```

Or permanently, add this line to `/etc/sysctl.conf`
```
net.ipv4.ip_forward=1
```

Alternatively:

```bash
sudo sysctl -w net.ipv4.ip_forward=1
```

* **Disable interface in dhcpcd.conf**

```
denyinterfaces wlan0
denyinterfaces br0
```

* **Disable ipv6 (sysctl.conf)**

```
net.ipv6.conf.all.disable_ipv6 = 1
net.ipv6.conf.default.disable_ipv6 = 1
net.ipv6.conf.lo.disable_ipv6 = 1
```

* **Wifi Channel Setup (hostapd.conf)**

If you build a WiFi infrastructure you must use different channel in all devices.
References:

* [https://www.extremetech.com/computing/179344-how-to-boost-your-wifi-speed-by-choosing-the-right-channel](https://www.extremetech.com/computing/179344-how-to-boost-your-wifi-speed-by-choosing-the-right-channel)
* [https://www.hanselman.com/blog/ConfiguringTwoWirelessRoutersWithOneSSIDNetworkNameAtHomeForFreeRoaming.aspx](https://www.hanselman.com/blog/ConfiguringTwoWirelessRoutersWithOneSSIDNetworkNameAtHomeForFreeRoaming.aspx)
 
From hostapd example conf:

```
# Channel number (IEEE 802.11)
# (default: 0, i.e., not set)
# Please note that some drivers do not use this value from hostapd and the
# channel will need to be configured separately with iwconfig.
#
# If CONFIG_ACS build option is enabled, the channel can be selected
# automatically at run time by setting channel=acs_survey or channel=0, both of
# which will enable the ACS survey based algorithm.
channel=1
```

* **Bonus - Connect To Existing WiFi Network**

It can be useful when you have two WiFi adapters, and you want to use your raspberry to extend WiFi signal range without ETH connection. I haven't tested this, but I think based on this post and the linked articles it can be done easily.

* Install necessary packages
```bash
apt-get install wpasupplicant wicd wicd-cli
```
* Search for Wifi Networks
```bash
iwlist wlan1 scan  
```
* Create Config File
```bash
wpa_passphrase  Wifi-NetWork 12345678 >wifi.config
```
* Test you connection
```bash
wpa_supplicant -i wlan1 -D nl80211 -c wifi.config  
```
* Edit Interface Config (/etc/network/interfaces)
```
auto wlan1  
allow-hotplug wlan1  
iface wlan1 inet dhcp  
    wpa-conf /root/wifi.config
```





==**References:**==

* [https://frillip.com/using-your-raspberry-pi-3-as-a-wifi-access-point-with-hostapd/](https://frillip.com/using-your-raspberry-pi-3-as-a-wifi-access-point-with-hostapd/)
* [http://www.instructables.com/id/How-to-make-a-WiFi-Access-Point-out-of-a-Raspberry/](http://www.instructables.com/id/How-to-make-a-WiFi-Access-Point-out-of-a-Raspberry/)
* [http://www.catonrug.net/2016/07/use-phone-tablet-as-raspberry-pi-3-wireless-screen-part-2.html](http://www.catonrug.net/2016/07/use-phone-tablet-as-raspberry-pi-3-wireless-screen-part-2.html)
* [https://www.raspberrypi.org/forums/viewtopic.php?t=141807](https://www.raspberrypi.org/forums/viewtopic.php?t=141807)
* [https://wiki.debian.org/BridgeNetworkConnections](https://wiki.debian.org/BridgeNetworkConnections)
* [https://askubuntu.com/questions/617973/fatal-error-netlink-genl-genl-h-no-such-file-or-directory](https://askubuntu.com/questions/617973/fatal-error-netlink-genl-genl-h-no-such-file-or-directory)
* [https://unix.stackexchange.com/questions/119209/hostapd-will-not-start-via-service-but-will-start-directly](https://unix.stackexchange.com/questions/119209/hostapd-will-not-start-via-service-but-will-start-directly)
* [https://superuser.com/questions/676918/hostapd-requires-manual-restart-for-devices-to-connect](https://superuser.com/questions/676918/hostapd-requires-manual-restart-for-devices-to-connect)
* [https://learn.adafruit.com/setting-up-a-raspberry-pi-as-a-wifi-access-point/install-software](https://learn.adafruit.com/setting-up-a-raspberry-pi-as-a-wifi-access-point/install-software)



