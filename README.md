# l2tp-client
For quick connection to VPN server from Ubuntu

Step by step manual for Ubuntu 18.04:

```
git clone https://github.com/vareger/l2tp-client.git
cd l2tp-client
sudo ./connect_vpn.sh \
'your_vpn_server_ip_or_domain_name' \
'your_ipsec_pre_shared_key' \
'your_vpn_username' \
'your_vpn_password'
```
