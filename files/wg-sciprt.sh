#!/bin/bash
  
VPN_IP_ADDRESS="10.8.0"
PRIVATE_KEY=$( wg genkey )
PUBLIC_KEY=$( echo $PRIVATE_KEY | wg pubkey )
NEXT_IP_ADDR=$( cat /etc/wireguard/clients/ip.txt )

PUBLIC=$( cat ../wg0.conf | tr -d ' ' | grep -oP '(?<=PrivateKey=).*[^$]' | wg pubkey )
PRESHARED=$( wg genpsk )

read -p 'Config Name (peername): ' peername
peer=$( echo $peername | tr '[:upper:]' '[:lower:]' | tr -d ' ' )

read -p 'Endpoint (leave blank for 23.88.60.51:51820): ' ENDPOINT
ENDPOINT="${ENDPOINT:-23.88.60.51:51820}"

PUBLIC=$( cat ../wg0.conf | tr -d ' ' | grep -oP '(?<=PrivateKey=).*[^$]' | wg pubkey )
PRESHARED=$( wg genpsk )

cat <<EOF > $peer.conf
#:${PUBLIC_KEY},${VPN_IP_ADDRESS}.${NEXT_IP_ADDR},${peer}
[Interface]
Address = ${VPN_IP_ADDRESS}.${NEXT_IP_ADDR}/32
ListenPort = 51820
PrivateKey = ${PRIVATE_KEY}
#DNS = 1.1.1.1

[Peer]
PublicKey = ${PUBLIC}
PresharedKey = ${PRESHARED}
EndPoint=${ENDPOINT}
PersistentKeepalive = 25
AllowedIPs = ${VPN_IP_ADDRESS}.0/24
EOF

qrencode -t ansiutf8 < $peer.conf

echo "==================== wg0 config change: ===================="
cat <<EOF 

[Peer] # Config File: $peer.conf
PublicKey = ${PUBLIC_KEY}
PresharedKey = ${PRESHARED}
PersistentKeepalive = 25
AllowedIPs = ${VPN_IP_ADDRESS}.${NEXT_IP_ADDR}/32

EOF

((NEXT_IP_ADDR=NEXT_IP_ADDR+1))
echo $NEXT_IP_ADDR >/etc/wireguard/clients/ip.txt

echo "==================== Client Config ===================="
cat $peer.conf

echo
echo -e  "Run command to reload Wireguard: \nwg syncconf wg0 <(wg-quick strip wg0)"