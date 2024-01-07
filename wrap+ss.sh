# Add cloudflare gpg key
curl -fsSL https://pkg.cloudflareclient.com/pubkey.gpg | gpg --yes --dearmor --output /usr/share/keyrings/cloudflare-warp-archive-keyring.gpg
# Add this repo to your apt repositories
echo "deb [arch=amd64 signed-by=/usr/share/keyrings/cloudflare-warp-archive-keyring.gpg] https://pkg.cloudflareclient.com/ $(lsb_release -cs) main" | tee /etc/apt/sources.list.d/cloudflare-client.list
# Install
apt-get update && apt-get install cloudflare-warp -y
warp-cli --accept-tos register
warp-cli --accept-tos set-mode proxy
warp-cli --accept-tos connect
warp-cli --accept-tos enable-always-on
bash <(curl -L https://raw.githubusercontent.com/v2fly/fhs-install-v2ray/master/install-release.sh)
echo '{
  "inbounds": [
    {
        "protocol": "shadowsocks",
        "port": 10001,
        "settings": {
            "method":"chacha20-ietf-poly1305",
            "password":"123456",
            "network": "tcp,udp"
        }
    }
  ],
  "outbounds": [
    {
      "protocol": "socks",
      "settings": {
        "servers": [{
                "address": "127.0.0.1",
                "port": 40000
        }]
      }
    }
  ]
}' > /usr/local/etc/v2ray/config.json
systemctl enable v2ray
systemctl restart v2ray
