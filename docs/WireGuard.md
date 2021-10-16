# Install And Configure Wireguard VPN

## Preface

I think it is not necessary to emphasize how important you privacy on the public Internet. In the world of high speed internet more and more applications are running at your home, eg.: OpenHab, Plex, Private NAS, etc. People usually want to access these services outside the home network too. It is not recommended to publish these service directly on your public ip address:

* It is becoming more common to use [CGN Nat](https://en.wikipedia.org/wiki/Carrier-grade_NAT) by many internet providers. This situation make it impossible to publish your service on Public IP address, because you won't have any.
* Everybody on the public Internet will have access to your private servers. Hacker can easily find your service and may steal your sensitive data.
* You have to make effort to configure NAT in your router.
* Usually consumer internet providers assign IP address dynamically. In this case you have to choose a dynamic DNS service. One of the best I think is [DudkDNS](https://www.duckdns.org), it is completely free for use. You need to update you ip address somehow (router, shell script, etc.). DuckDNS supports a lot of method to do this.

Not all of above could be eliminated with Wireguard VPN:

* If you don't have static public ip address you still need NAT configuration and DynDNS service.
* With CGN Nat it is still impossible to get into your home network.

If you are looking for a really zero-configuration VPN solution your best option may be [Tailscale](https://tailscale.com).  It can be easily installed on any popular platforms (Linux, Mac, Windows, Android or IOS).  
If you are interested in how Tailscale solve the NAT and dynamic IP problems you should read this article: [https://tailscale.com/blog/how-nat-traversal-works/](https://tailscale.com/blog/how-nat-traversal-works/). And the best: it's completely free up to 20 devices. 

But this article is not about Tailscale, but Wireguard.

## Install Wireguard

!!! quote
    WireGuard® is an extremely simple yet fast and modern VPN that utilizes state-of-the-art cryptography. It aims to be faster, simpler, leaner, and more useful than IPsec, while avoiding the massive headache. It intends to be considerably more performant than OpenVPN. WireGuard is designed as a general purpose VPN for running on embedded interfaces and super computers alike, fit for many different circumstances. Initially released for the Linux kernel, it is now cross-platform (Windows, macOS, BSD, iOS, Android) and widely deployable. It is currently under heavy development, but already it might be regarded as the most secure, easiest to use, and simplest VPN solution in the industry. 

Official Web Page: [https://www.wireguard.com/install/](https://www.wireguard.com/install/)

The install process is the same as Server or Client, but WireGuard is a decentralized VPN solution so there is no classic Server-Client terminology as in case of example OpenVPN. 

I have VPS server with static and public IP address. This machine will be the "Server". Unfortunately lack of at least one static ip address makes the situation complicated, and there is no overall (magic) solution. So later in this article it is **assumed that you have at least one public, static ip address**. I'm going to highlight how can you partially solve the lack of the public ip, but all everything is only Workaround and solve the problems just partially.

Install Wireguard:

```bash
apt-get install wireguard wireguard-tools qrencode
```

!!! warning
    Users with Debian releases older than Bullseye should enable backports.


You may want to check the official install doc if you have another system than Debian based OS: [https://www.wireguard.com/install/](https://www.wireguard.com/install/)

## Configure The Server

* Private Key

```bash
export PRIVATE_KEY=$( wg genkey )
```

* Public Key

```bash
export PUBLIC_KEY=$( echo $PRIVATE_KEY | wg pubkey )
```

Now you have to choose a public IP address range which never will overlap any of your existing network. Example: `10.9.0.0/24`

* Create The Interface Configuration file `/etc/wireguard/wg0.conf`

```bash
cat <<EOF>/etc/wireguard/wg0.conf
# PubKey: $PUBLIC_KEY
[Interface]
Address = 10.9.0.1/32
ListenPort = 51820
PrivateKey = $PRIVATE_KEY
EOF
```

* Start the VPN Server

```bash
systemctl enable wg-quick@wg0
systemctl start wg-quick@wg0
```

* Check The Interface

<pre class="command-line" data-user="root" data-host="dockerhost" data-output="2-8"><code class="language-bash">ifconfig wg0
wg0: flags=209<UP,POINTOPOINT,RUNNING,NOARP>  mtu 1420
        inet 10.9.0.1  netmask 255.255.255.255  destination 10.9.0.1
        unspec 00-00-00-00-00-00-00-00-00-00-00-00-00-00-00-00  txqueuelen 1000  (UNSPEC)
        RX packets 0  bytes 0 (0.0 B)
        RX errors 0  dropped 0  overruns 0  frame 0
        TX packets 0  bytes 0 (0.0 B)
        TX errors 0  dropped 0 overruns 0  carrier 0  collisions 0 </UP,POINTOPOINT,RUNNING,NOARP>
</code></pre>

## Create Peer (Client) Config

### Collect Things We Need

```
# Private Key (Client)
wg genkey
iEypOx3Xt5HE++e5I5udO8oJ+bArSoEXqK3XvuvFeXo=

# Public Key (Client)
echo "iEypOx3Xt5HE++e5I5udO8oJ+bArSoEXqK3XvuvFeXo=" | wg pubkey
k6k5GnW3+JJSmzCqEQzkZyFyg7OFO3RhiXhSXur5tFI=

# The Public Key Of the Server
cat /etc/wireguard/wg0.conf | tr -d ' ' | grep -oP '(?<=PrivateKey=).*[^$]' | wg pubkey
TSXemmthLlXp8gsLSTfcmqgjolvYWmppNhIUeppg/CU=

# Preshared Key
wg genpsk
Samqdyf9gVcfEUPCS52I1hJCLMlXAmHoitk1l5y9UO0=
```

Peer Config File:

```config
[Interface]
Address = 10.9.0.2/24
ListenPort = 51820
PrivateKey = iEypOx3Xt5HE++e5I5udO8oJ+bArSoEXqK3XvuvFeXo=

[Peer]
PublicKey = TSXemmthLlXp8gsLSTfcmqgjolvYWmppNhIUeppg/CU=
PresharedKey = Samqdyf9gVcfEUPCS52I1hJCLMlXAmHoitk1l5y9UO0=
EndPoint=172.16.1.214:51820
PersistentKeepalive = 25
AllowedIPs = 10.9.0.0/24
```

This file should be saved on your client (`/etc/wireguard/wg0.conf`).  
Or save it to a file (`01.conf`) and generate QR code for you Android or IOS client:

```bash
qrencode -t ansiutf8 <01.conf
```

Before you start using your client you need to update your Wireguard Server. Add these lines:

```conf
cat <<EOF>>/etc/wireguard/wg0.conf

[Peer]
PublicKey = k6k5GnW3+JJSmzCqEQzkZyFyg7OFO3RhiXhSXur5tFI=
PresharedKey = Samqdyf9gVcfEUPCS52I1hJCLMlXAmHoitk1l5y9UO0=
PersistentKeepalive = 25
AllowedIPs = 10.9.0.2/32

EOF
```
* Reload The Server Config (Without Interrupting Connections)

```bash
wg syncconf wg0 <(wg-quick strip wg0)
```
### Peer Configs

At fist sight it could be confusing, but if you look closer I hope will understand the configs.

* **PrivateKey**: Should never shared. Unique across all peers and appear only in `[interface` section.
* **PublicKey**: Generated from `PrivateKey`. 
    - Should shared across peers. 
    - Peer1 gets the PublicKey of Peer2, and vice versa, 
    - Peer2 gets the PublicKey of Peer1.
* **PresharedKey**: Should be the same between two peers.
    - Peer1 and Peer2 use the same PresharedKey1, 
    - Peer2 and Peer3 use the same PresharedKey2, 
    - Peer1 and Peer3 use the same PresharedKey3.
    - This assumes that all of these three peers connected each other (decentralized connection), and there will be three different PresharedKey.
  
I try to explain through the following schema of `[peer]` configs. Only The keys are mentioned. Interface configs are always unique, does not have common parts.

**Peer1 Config**

```conf
[Peer]
PublicKey = Public Key Of Peer 2 (echo [PRIVATE_KEY OF PEER2] | wg pubkey)
PresharedKey = Shared Key12 

[Peer]
PublicKey = Public Key Of peer 3 (echo [PRIVATE_KEY OF PEER3] | wg pubkey)
PresharedKey = Shared Key13
```

**Peer2 Config**

```conf
[Peer]
PublicKey = Public Key Of Peer 1 (echo [PRIVATE_KEY OF PEER1] | wg pubkey)
PresharedKey = Shared Key12 

[Peer]
PublicKey = Public Key Of peer 3 (echo [PRIVATE_KEY OF PEER3] | wg pubkey)
PresharedKey = Shared Key23
```

**Peer3 Config**

```conf
[Peer]
PublicKey = Public Key Of Peer 1 (echo [PRIVATE_KEY OF PEER1] | wg pubkey)
PresharedKey = Shared Key13

[Peer]
PublicKey = Public Key Of peer 2 (echo [PRIVATE_KEY OF PEER2] | wg pubkey)
PresharedKey = Shared Key23
```

#### EndPoint

One out of two peers have to know where to find the other. 

| Peer1 Know Peer2 IP adddress     | Peer2 Know Peer1 IP adddress | Comment  |
| --- -----------------------------| ---------------------------- |----------|
| yes                              | yes                          | Best Situation. PersistentKeepalive is not needed. |
| yes                              | no                           | Good Situation. PersistentKeepalive should be set on Peer1. |
| no                               | yes                          | Good Situation. PersistentKeepalive should be set on Peer2. |
| no                               | no                           | Worst Situation. No Connection could be made.  |



Direct Connection Matrix:

| Connect FROM / TO            |  Server Peer (91.12.21.142)                                   | Peer2 (inside priv net)      | Peer3 (inside priv net)    | 
|-                             |-                                                              |-                             | -                          |
| Server Peer (91.12.21.142)   |             X                                                 | Doesn't know peer2 address   | Doesn't know peer3 address |
| Peer2 (inside priv net)      | `EndPoint: 91.12.21.142:51820` <br>`PersistentKeepalive = 25` |            X                 | No Ip addresses is known   |
| Peer3 (inside priv net)      | `EndPoint: 91.12.21.142:51820` <br>`PersistentKeepalive = 25` | No Ip addresses is known     |           X                |


* **Server Peer (91.12.21.142)** Has Static Public IP address (91.12.21.142)
    - When you configure peers on the server side usually no `EndPoint` and nor `PersistentKeepalive` is set up.
* **Peer2 (inside priv net)** AND **Peer3 (inside priv net)** are behind NAT. (Home network or your phone/tablet with mobile internet)
    - In the clients configuration we specify where to find the Server (`EndPoint`) and   `PersistentKeepalive` to update its ip address periodically.

!!! info
    So the mentioned `EndPoint` and `PersistentKeepalive` setting go to the clients config not to the server's one.

As we discussed earlier general peers may be behind CGN NAT, or inside your home network, or even could be your mobile phone with mobile internet connection. These peers don't have static, public IP addresses. Of course you can open your port on your firewall and set up NAT, use dynamic DNS, etc., but Wireguard check DNS record only when it starts. Every time your router gets a new public ip address you should trigger Wireguard to restart.  
This situation could not be solved easily, and this is where Tailscale comes to the picture. If all of your peers are behind NAT you should use Tailscale instead of Wireguard. You probably won't find any other good and stable solution. 

It is not likely that all of your peers behind nats get new IP address at the same time, but imagine the situation you have three peers and one of them gets a new IP address. Two things will happen:

* The other peers will look for this client on the old IP address (because of the initial DNS query)
* The peer with the new IP address will find the other peers, since ip addresses of them did not changed. 

It sound good, isn't it? Yes, but we have some problem:

* `PersistentKeepalive` should be set up on all dynamic clients. All clients look for the others on the ip address was resolved from Endpoint at startup. 
* Although the clients with new ip address will update it's ip address on all clients, the other clients will look it on its old IP address. 
* This easily leads to unstable connection. 
* The main problem here is the initial DNS query. 
* You may periodically restart all of your clients but this is really a bad idea, connections will be interrupted between the clients.

### Summarize

Now we have a server and a client configuration:

* Server

```conf
[Interface]
Address = 10.9.0.1/32
ListenPort = 51820
PrivateKey = oMQf0fLAvnIoiLr+z4zmOlETxA0eR/Z7oPHhXRpQoEY=


[Peer]
PublicKey = k6k5GnW3+JJSmzCqEQzkZyFyg7OFO3RhiXhSXur5tFI=
PresharedKey = Samqdyf9gVcfEUPCS52I1hJCLMlXAmHoitk1l5y9UO0=
PersistentKeepalive = 25
AllowedIPs = 10.9.0.2/32
```

* Client

```conf
[Interface]
Address = 10.9.0.2/24
ListenPort = 51820
PrivateKey = iEypOx3Xt5HE++e5I5udO8oJ+bArSoEXqK3XvuvFeXo=

[Peer]
PublicKey = TSXemmthLlXp8gsLSTfcmqgjolvYWmppNhIUeppg/CU=
PresharedKey = Samqdyf9gVcfEUPCS52I1hJCLMlXAmHoitk1l5y9UO0=
EndPoint=172.16.1.214:51820
PersistentKeepalive = 25
AllowedIPs = 10.9.0.0/24
```

We haven't talk about two important things:

* **`Interface` / `Address`**

!!! quote 
    The Address setting is the virtual address of the local WireGuard peer. It’s the IP address of the virtual network interface that WireGuard sets up for the peer;     and as such you can set it to whatever you want (whatever makes sense for the virtual WireGuard network you’re building).    
    
    Like with other network interfaces, the IP address for a WireGuard interface is defined with a network prefix, which tells the local host what other IP addresses     are available on the same virtual subnet as the interface. In the above example, this prefix is /32 (which generally is a safe default for a WireGuard interface).         If we set it to /24, that would indicate to the local host that other addresses in the same /24 block as the address itself (10.0.0.0 to 10.0.0.255) are routable     through the interface.



* **`Peer` / `AllowedIPs`**

!!! quote 
    Is the set of IP addresses the local host should route to the remote peer through the WireGuard tunnel. This setting tells the local host what goes in tunnel.

Example: `AllowedIPs = 10.8.0.0/24,192.168.100.0/24`

Basically this means that traffic to `10.8.0.0/24` and `192.168.100.0/24` is routed to the `wg0` interface (route command):

```plain
Kernel IP routing table
Destination     Gateway         Genmask         Flags Metric Ref    Use Iface
default         _gateway        0.0.0.0         UG    100    0        0 eth0
10.8.0.0        0.0.0.0         255.255.255.0   U     0      0        0 wg0
....
....
192.168.100.0   0.0.0.0         255.255.255.0   U     0      0        0 wg0
```

Read more:

* [https://stackoverflow.com/questions/65444747/what-is-the-difference-between-endpoint-and-allowedips-fields-in-wireguard-confi](https://stackoverflow.com/questions/65444747/what-is-the-difference-between-endpoint-and-allowedips-fields-in-wireguard-confi)
* [https://www.procustodibus.com/blog/2021/01/wireguard-endpoints-and-ip-addresses/](https://www.procustodibus.com/blog/2021/01/wireguard-endpoints-and-ip-addresses/)

## Generate Peer Config Using Bash Script




























