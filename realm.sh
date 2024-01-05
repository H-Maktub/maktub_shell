#! /bin/bash
PATH=/bin:/sbin:/usr/bin:/usr/sbin:/usr/local/bin:/usr/local/sbin:~/bin
export PATH

#参数
# #本地端口
localPort=''
# #远程地址
remoteHost=''
# #远程端口
remotePort=''
# #自定义sni
customSni=''
# #是否为服务端
isServer='false'

function main()
{
    get_system_config
    echo "请选择============================="
    echo "1）安装"
    echo "2）卸载"
    echo "3）更新realm"

    read -p "请选择: " number
    if [ "$number" -eq 1 ];then
        create_dic
        if [ ! -f /etc/realm/realm ]; then
            down_realm
        fi
        get_param
        install_realm
    elif [ "$number" -eq 2 ];then
        uninstall_port
    elif [ "$number" -eq 3 ];then
        down_realm
    fi
}

function get_system_config()
{
    if [[ -f /etc/redhat-release ]]; then
        release="centos"
    elif cat /etc/issue | grep -q -E -i "debian"; then
        release="debian"
    elif cat /etc/issue | grep -q -E -i "ubuntu"; then
        release="ubuntu"
    elif cat /etc/issue | grep -q -E -i "centos|red hat|redhat"; then
        release="centos"
    elif cat /proc/version | grep -q -E -i "debian"; then
        release="debian"
    elif cat /proc/version | grep -q -E -i "ubuntu"; then
        release="ubuntu"
    elif cat /proc/version | grep -q -E -i "centos|red hat|redhat"; then
        release="centos"
    fi
    bit=$(uname -m)
        if test "$bit" != "x86_64"; then
           bit="arm64"
        else bit="amd64"
    fi
}

function create_dic()
{
    if [ ! -d /etc/realm/ ]; then
        mkdir /etc/realm
    fi
}

function down_realm()
{
    if [ -f /etc/realm/realm ]; then
        rm -f /etc/realm/realm
    fi

    if [[ ${bit} == "amd64" ]];then
        wget -q --show-progress --no-check-certificate -O /etc/realm/realm.tar.gz https://github.com/zhboner/realm/releases/download/v2.5.0/realm-x86_64-unknown-linux-gnu.tar.gz
    else
        wget -q --show-progress --no-check-certificate -O /etc/realm/realm.tar.gz https://github.com/zhboner/realm/releases/download/v2.5.0/realm-aarch64-unknown-linux-gnu.tar.gz
    fi
    tar -zxvf /etc/realm/realm.tar.gz -C /etc/realm/
    chmod +x /etc/realm/realm
    rm /etc/realm/realm.tar.gz
}

function get_param()
{
    echo "开始配置(覆盖)============================="
    read -p "是否为入口机(true/false): " isServer
    read -p "请输入本地端口(0-65535): " localPort
    read -p "请输入远程ip(x.x.x.x): " remoteHost
    read -p "请输入远程端口(0-65535): " remotePort
    read -p "请输入SNI域名(xxx.com): " customSni
}

function install_realm()
{
    echo "
[Unit]
Description=realm${localPort}
After=network.target
Wants=network.target

[Service]
Type=simple
User=root
LimitAS=infinity
LimitCORE=infinity
LimitNOFILE=102400
LimitNPROC=102400
ExecStart=/etc/realm/realm -c /etc/realm/${localPort}.json
ExecReload=/bin/kill -HUP \$MAINPID
ExecStop=/bin/kill \$MAINPID
Restart=on-failure
RestartSec=5
[Install]
WantedBy=multi-user.target
    " > /etc/systemd/system/realm${localPort}.service

    echo '{
    "log": {
        "level": "warn"
    },
    "dns": {
      "mode": "ipv4_and_ipv6",
      "protocol": "tcp_and_udp",
      "min_ttl": 0,
      "max_ttl": 60,
      "cache_size": 5
    },
    "network": {
      "use_udp": true,
      "zero_copy": true,
      "fast_open": true,
      "tcp_timeout": 300,
      "udp_timeout": 30,
      "send_proxy": false,
      "send_proxy_version": 2,
      "accept_proxy": false,
      "accept_proxy_timeout": 5
    },
    "endpoints": [
      {
        "listen": "",
        "remote": "",
        "listen_transport": "",
        "remote_transport": ""
      }
    ]
    }
    ' > /etc/realm/${localPort}.json
    sed -i "s/\"listen\":.*$/\"listen\":\"[::0]:$localPort\",/" /etc/realm/${localPort}.json
    sed -i "s/\"remote\":.*$/\"remote\":\"$remoteHost:$remotePort\",/" /etc/realm/${localPort}.json
    if [[ $isServer == "true" ]];then
        sed -i "s/\"remote_transport\":.*$/\"remote_transport\":\"tls;sni=${customSni};insecure\"/" /etc/realm/${localPort}.json
    else
        sed -i "s/\"listen_transport\":.*$/\"listen_transport\":\"tls;servername=${customSni}\",/" /etc/realm/${localPort}.json
    fi
    systemctl daemon-reload
    systemctl restart realm${localPort}
    systemctl enable realm${localPort}
    systemctl status realm${localPort}
}

function uninstall_port()
{
    echo "卸载============================="
    read -p "请输入本地端口(0-65535): " localPort
    systemctl stop realm${localPort}
    systemctl disable realm${localPort}
    rm -rf /etc/systemd/system/realm${localPort}.service
    rm -rf /etc/realm/${localPort}.json
}
main