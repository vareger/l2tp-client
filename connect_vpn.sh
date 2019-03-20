#!/bin/sh
apt-get update
apt-get -y install strongswan xl2tpd

echo "Dependencies installed"

VPN_SERVER_IP=$1 #'your_vpn_server_ip_or_domain_name'
VPN_IPSEC_PSK=$2 #'your_ipsec_pre_shared_key'
VPN_USER=$3 #'your_vpn_username'
VPN_PASSWORD=$4 #'your_vpn_password'

YOUR_LOCAL_PC_PUBLIC_IP=$(wget -qO- http://ipv4.icanhazip.com) #Getting YOUR_LOCAL_PC_PUBLIC_IP

echo "ENV variables setuped"

########################################################
#Configure strongSwan:
echo "Configuration strongSwan..."

cat > /etc/ipsec.conf <<EOF
# ipsec.conf - strongSwan IPsec configuration file

# basic configuration

config setup
  # strictcrlpolicy=yes
  # uniqueids = no

# Add connections here.

# Sample VPN connections

conn %default
  ikelifetime=60m
  keylife=20m
  rekeymargin=3m
  keyingtries=1
  keyexchange=ikev1
  authby=secret
  ike=aes256-sha1-modp2048,aes128-sha1-modp2048!
  esp=aes256-sha1-modp2048,aes128-sha1-modp2048!

conn myvpn
  keyexchange=ikev1
  left=%defaultroute
  auto=add
  authby=secret
  type=transport
  leftprotoport=17/1701
  rightprotoport=17/1701
  right=$VPN_SERVER_IP
EOF

cat > /etc/ipsec.secrets <<EOF
: PSK "$VPN_IPSEC_PSK"
EOF

chmod 600 /etc/ipsec.secrets

echo "strongSwan configured"

########################################################
#Configure xl2tpd:
echo "Configuration xl2tpd..."

cat > /etc/xl2tpd/xl2tpd.conf <<EOF
[lac myvpn]
lns = $VPN_SERVER_IP
ppp debug = yes
pppoptfile = /etc/ppp/options.l2tpd.client
length bit = yes
EOF

cat > /etc/ppp/options.l2tpd.client <<EOF
ipcp-accept-local
ipcp-accept-remote
refuse-eap
require-chap
noccp
noauth
mtu 1280
mru 1280
noipdefault
defaultroute
usepeerdns
connect-delay 5000
name $VPN_USER
password $VPN_PASSWORD
EOF

chmod 600 /etc/ppp/options.l2tpd.client

echo "xl2tpd configured"

########################################################
#Create script for reconnection:
echo "Creating script for reconnection..."

cat > /etc/ppp/reconnect.sh <<EOF
#!/bin/sh
echo "c myvpn" > /var/run/xl2tpd/l2tp-control
sleep 10
sudo route add -net 192.168.0.0/16 gw 192.168.1.1
EOF

chmod 777 /etc/ppp/reconnect.sh
echo "Script for reconnection created"
########################################################
#Create xl2tpd control file:
echo "Create xl2tpd control file..."
mkdir -p /var/run/xl2tpd
touch /var/run/xl2tpd/l2tp-control

service strongswan restart
service strongswan status

service xl2tpd restart
service xl2tpd status

echo "xl2tpd control file created"

########################################################
#Start the L2TP connection:
echo "Start the L2TP connection..."
echo "c myvpn" > /var/run/xl2tpd/l2tp-control
sleep 5
echo "Started"
########################################################
#Defined function for crontab job for reconnecting L2TP connection:
add_crontask () {
    crontab -l > ftemp
    echo "* * * * * /etc/ppp/reconnect.sh" >> ftemp
    crontab ftemp
    rm ftemp
}

########################################################
#Definition function for disconnection:
disconnect () {
    echo "d myvpn" > /var/run/xl2tpd/l2tp-control
    ipsec down myvpn
}

########################################################
#Definition finction for adding routes:
add_routes () {
    #Check your existing default route:
    ip route

    #route add YOUR_VPN_SERVER_IP gw X.X.X.X:
    route add $VPN_SERVER_IP gw $(ip route |grep "default via" | grep -o '[0-9]\{1,3\}\.[0-9]\{1,3\}\.[0-9]\{1,3\}\.[0-9]\{1,3\}' |grep -m1 "")

    #route add YOUR_LOCAL_PC_PUBLIC_IP gw X.X.X.X:
    route add $YOUR_LOCAL_PC_PUBLIC_IP gw $(ip route |grep "default via" | grep -o '[0-9]\{1,3\}\.[0-9]\{1,3\}\.[0-9]\{1,3\}\.[0-9]\{1,3\}' |grep -m1 "")

    #route add for DNS server
    route add $(systemd-resolve --status |grep "DNS Servers:" |grep -o '[0-9]\{1,3\}\.[0-9]\{1,3\}\.[0-9]\{1,3\}\.[0-9]\{1,3\}') gw $(ip route |grep "default via" | grep -o '[0-9]\{1,3\}\.[0-9]\{1,3\}\.[0-9]\{1,3\}\.[0-9]\{1,3\}' |grep -m1 "")

    #Add a new default route to start routing traffic via the VPN server (Disabled now)：
    #route add default dev ppp0

    #Add route only for subnet inside Private Network
    route add -net 192.168.0.0/16 gw 192.168.1.1

    #Verify that your traffic is being routed properly:
    echo "This is new public IP:"$(wget -qO- http://ipv4.icanhazip.com)
}
########################################################

echo "Add routes..."
add_routes
echo "Routes added"

echo "Add crontab job..."
add_crontask
echo "Crontab job added"
