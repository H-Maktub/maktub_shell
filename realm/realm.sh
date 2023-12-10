#! /bin/bash
PATH=/bin:/sbin:/usr/bin:/usr/sbin:/usr/local/bin:/usr/local/sbin:~/bin
export PATH



Green="\033[32m"
Font="\033[0m"
Blue="\033[33m"
port1=$1
port2=$localPort
remoteIp=$3

rootness(){
    if [[ $EUID -ne 0 ]]; then
       echo "请使用root用户登录!" 1>&2
       exit 1
    fi
}

delport(){
    systemctl stop xiandan${1}xiandan
    rm -f /etc/xiandan/realm/${1}*
    rm -f /etc/systemd/system/xiandan${localPort}xiandan.service
    echo "已关闭${1}端口的进程！"
    exit 0
}
disable_selinux(){
    update-alternatives --set iptables /usr/sbin/iptables-legacy
    if [ -s /etc/selinux/config ] && grep 'SELINUX=enforcing' /etc/selinux/config; then
        sed -i 's/SELINUX=enforcing/SELINUX=disabled/g' /etc/selinux/config
        setenforce 0
    fi
}
function check_sys()
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

function install(){
    check_sys
    disable_selinux
    if [[ ${release} == "centos" ]]; then
        rm -f /var/run/yum.pid
        yum install -y wget
        yum install -y lsof
    else
        apt-get install -y wget
        apt-get install -y lsof
    fi
    rm -rf /etc/xiandan/realm.sh
    wget --no-check-certificate -P /etc/xiandan raw.githubusercontent.com/H-Maktub/maktub_shell/main/realm/realm.sh
    if [ -f /etc/xiandan/realm/realm ]; then
        rm -f /etc/xiandan/realm/realm
        rm -f /etc/xiandan/realm/full.json
    fi
    if [[ ${bit} == "amd64" ]];then
        wget --no-check-certificate -P /etc/xiandan/realm raw.githubusercontent.com/H-Maktub/maktub_shell/main/realm/x86/realm
    else
        wget --no-check-certificate -P /etc/xiandan/realm raw.githubusercontent.com/H-Maktub/maktub_shell/main/realm/arm/realm
    fi
    chmod +x /etc/xiandan/realm/realm
    if [[ -z $1 ]];then
        exit 0
    fi
}
function uninstall(){
    rm -rf /etc/xiandan/realm*
    wget --no-check-certificate -P raw.githubusercontent.com/H-Maktub/maktub_shell/main/realm/realm.do
    chmod +x /etc/xiandan/realm.do
    exit 0
}
disable_selinux(){
    if [ -s /etc/selinux/config ] && grep 'SELINUX=enforcing' /etc/selinux/config; then
        sed -i 's/SELINUX=enforcing/SELINUX=disabled/g' /etc/selinux/config
        setenforce 0
    fi
}

disable_iptables(){
    systemctl stop firewalld.service >/dev/null 2>&1
    systemctl disable firewalld.service >/dev/null 2>&1
}

startService(){
    if [ ! -f /etc/xiandan/flowRule.sh ];then
        wget -P /etc/xiandan -N --no-check-certificate "raw.githubusercontent.com/H-Maktub/maktub_shell/main/realm/flowRule.sh"
        chmod +x /etc/xiandan/flowRule.sh
    fi
    if [ ! -f /etc/xiandan/realm/realm ];then
        install true
    fi
    service xiandan${localPort}xiandan stop
    rm -f /etc/systemd/system/xiandan${localPort}xiandan.service
    rm -rf /etc/xiandan/realm/${localPort}.json
    if [ ! -f /etc/xiandan/realm/full.json ]; then
        mkdir /etc/xiandan/realm
        wget --no-check-certificate -P /etc/xiandan/realm -O /etc/xiandan/realm/full.json raw.githubusercontent.com/H-Maktub/maktub_shell/main/realm/full.json
    fi
    cp /etc/xiandan/realm/full.json /etc/xiandan/realm/${localPort}.json
    echo "
[Unit]
Description=xiandan${localPort}xiandan
After=network.target
Wants=network.target

[Service]
Type=simple
StandardError=none
User=root
LimitAS=infinity
LimitCORE=infinity
LimitNOFILE=102400
LimitNPROC=102400
ExecStart=/etc/xiandan/realm/realm -c /etc/xiandan/realm/${localPort}.json
ExecReload=/bin/kill -HUP \$MAINPID
ExecStop=/bin/kill \$MAINPID
Restart=on-failure
RestartSec=5
[Install]
WantedBy=multi-user.target
    " > /etc/systemd/system/xiandan${localPort}xiandan.service
    sed -i "s/\"listen\":.*$/\"listen\":\"[::0]:$localPort\",/" /etc/xiandan/realm/${localPort}.json
    sed -i "s/\"remote\":.*$/\"remote\":\"$remoteHost:$remotePort\",/" /etc/xiandan/realm/${localPort}.json
    if [[ $sendProxy == "true" ]];then
        sed -i "s/\"send_proxy\":.*$/\"send_proxy\":true,/" /etc/xiandan/realm/${localPort}.json
    fi
    if [[ $acceptProxy == "true" ]];then
        sed -i "s/\"accept_proxy\":.*$/\"accept_proxy\":true,/" /etc/xiandan/realm/${localPort}.json
    fi
    if [[ ! -z $customPath ]];then
        customPath=${customPath//\//\\\/}
    fi
    if [[ $isServer == "false" ]];then
		if [[ $protocol == "tls" ]]; then
		    if [[ $isSecure == "true" ]];then
		        sed -i "s/\"remote_transport\":.*$/\"remote_transport\":\"tls;sni=${customSni}\"/" /etc/xiandan/realm/${localPort}.json
		    else
		        sed -i "s/\"remote_transport\":.*$/\"remote_transport\":\"tls;sni=${customSni};insecure\"/" /etc/xiandan/realm/${localPort}.json
	        fi
		elif [[ $protocol == "ws" ]]; then
    		sed -i "s/\"remote_transport\":.*$/\"remote_transport\":\"ws;host=${customHost};path=\/${customPath}\"/" /etc/xiandan/realm/${localPort}.json
		elif [[ $protocol == "wss" ]]; then
		    if [[ $isSecure == "true" ]];then
		        sed -i "s/\"remote_transport\":.*$/\"remote_transport\":\"ws;host=${customHost};path=\/${customPath};tls;sni=${customSni}\"/" /etc/xiandan/realm/${localPort}.json
		    else
		        sed -i "s/\"remote_transport\":.*$/\"remote_transport\":\"ws;host=${customHost};path=\/${customPath};tls;sni=${customSni};insecure\"/" /etc/xiandan/realm/${localPort}.json
	        fi
		fi
	else
		if [[ $protocol == "tls" ]]; then
		    if [[ $isSecure == "true" ]];then
        		sed -i "s/\"listen_transport\":.*$/\"listen_transport\":\"tls;cert=\/etc\/xiandan\/realm\/$localPort\/${customSni}.crt;key=\/etc\/xiandan\/realm\/$localPort\/${customSni}.key\",/" /etc/xiandan/realm/${localPort}.json
    		else
    		    sed -i "s/\"listen_transport\":.*$/\"listen_transport\":\"tls;servername=${customSni}\",/" /etc/xiandan/realm/${localPort}.json
		    fi
		elif [[ $protocol == "ws" ]]; then
    		sed -i "s/\"listen_transport\":.*$/\"listen_transport\":\"ws;host=${customHost};path=\/${customPath}\",/" /etc/xiandan/realm/${localPort}.json
		elif [[ $protocol == "wss" ]]; then
		    if [[ $isSecure == "true" ]];then
        		sed -i "s/\"listen_transport\":.*$/\"listen_transport\":\"ws;host=$customHost;path=\/$customPath;tls;cert=\/etc\/xiandan\/realm\/$localPort\/${customSni}.crt;key=\/etc\/xiandan\/realm\/$localPort\/${customSni}.key\",/" /etc/xiandan/realm/${localPort}.json
    		else
    		    sed -i "s/\"listen_transport\":.*$/\"listen_transport\":\"ws;host=$customHost;path=\/$customPath;tls;servername=$customSni\",/" /etc/xiandan/realm/${localPort}.json
		    fi
		fi
	fi
	if [[ "$isBalance" == "false" ]];then
        systemctl daemon-reload
    	service xiandan${localPort}xiandan start
    	echo '指令发送成功！服务运行状态如下'
    	echo ' '
    	systemctl status xiandan${localPort}xiandan --no-pager
    	if [[ "$autoRestart" == "true" ]];then
    	    systemctl enable xiandan${localPort}xiandan
        fi
    fi
    exit 0
}


function main(){
    check_sys
    rootness
    disable_selinux
    disable_iptables
}

check_sys

#!/bin/sh
#说明
function showHelp () {
    echo "----------参数说明------------"
    echo "install 一键安装"
    echo "uninstall 一键卸载"
    echo "stop 端口号 停止端口"
    echo "-l | --localPort 本地端口 必填"
    echo "-r | --remoteHost 远程地址 必填"
    echo "-p | --remotePort 远程端口 必填"
    echo "--protocol 加解密协议 默认 none"
    echo "--isServer 是否为服务端 默认 false"
    echo "--isSecure 是否自定义证书 默认 false"
    echo "--sendProxy send-proxy 默认 false"
    echo "--acceptProxy accept-proxy 默认 false"
    echo "--customHost 自定义host"
    echo "--customSni 自定义sni"
    echo "--customPath 自定义path 默认 /"
    echo ""
    exit 0;
}
#参数
# #本地端口
localPort=''
# #远程地址
remoteHost=''
# #远程端口
remotePort=''
# #加密协议
protocol='none'
# #是否自定义证书
isSecure='false'
# #send-proxy
sendProxy='false'
# #accept_proxy
acceptProxy='false'
# #自定义host
customHost=''
# #自定义sni
customSni=''
# #自定义path
customPath=''
# #是否为服务端
isServer='false'

# #是否为负载均衡
isBalance='false'

if [[ $1 == "install" ]]; then
    install
elif [[ $1 == "uninstall" ]]; then
    uninstall
elif [[ $1 == "stop" ]]; then
    delport $2
fi
#处理参数，规范化参数

GETOPT_ARGS=`getopt -o h::l:r:p -al help::,localPort:,remoteHost:,remotePort:,protocol:,isSecure:,sendProxy:,acceptProxy:,customHost:,customSni:,customPath:,isServer:,autoRestart:,isBalance: -- "$@"`
eval set -- "$GETOPT_ARGS"
while [ -n "$1" ]
    do
        case "$1" in
            -l|--localPort) localPort=$2; shift 2;;
            -r|--remoteHost) remoteHost=$2; shift 2;;
            -p|--remotePort) remotePort=$2; shift 2;;
            --protocol) protocol=$2; shift 2;;
            --isSecure) isSecure=$2; shift 2;;
            --sendProxy) sendProxy=$2; shift 2;;
            --acceptProxy) acceptProxy=$2; shift 2;;
            --customHost) customHost=$2; shift 2;;
            --customSni) customSni=$2; shift 2;;
            --customPath) customPath=$2; shift 2;;
            --isServer) isServer=$2; shift 2;;
            --autoRestart) autoRestart=$2; shift 2;;
            --isBalance) isBalance=$2; shift 2;;
            -h|--help)
                showHelp
            ;;
            install) echo "安装" ;;
            *)  break ;;
        esac
done

function getLocalPort () {
    echo "请输入本地端口"
    read -p "请输入: " localPort
    if [[ ! -n $localPort ]];then
        echo -e "本地端口号必填"
    	getLocalPort
    	exit 0
    fi
    if [ "$localPort" -gt 0 ] 2>/dev/null;then
        if [[ $localPort -lt 0 || $localPort -gt 65535 ]];then
             echo -e "端口号不正确"
             getLocalPort
             exit 0
        fi
	else
	    echo -e "端口号不正确"
        getLocalPort
        exit 0
    fi
}

function getRemotePort () {
    echo "请输入远程端口"
    read -p "请输入: " remotePort
    if [[ ! -n $remotePort ]];then
    	getRemotePort
    	exit 0
    fi
    if [ "$remotePort" -gt 0 ] 2>/dev/null;then
		if [[ $remotePort -lt 0 || $remotePort -gt 65535 ]];then
		 echo -e "端口号不正确"
		 getRemotePort
		 exit 0
		fi
	else
        echo -e "端口号不正确"
	    getRemotePort
	    exit 0
    fi
}

function getRemoteHost () {
    echo "请输入远程地址"
    read -p "请输入(默认 [::0]): " remoteHost
    if [[ -z "$remoteHost" ]];then
    	remoteHost="[::0]"
    fi
}

if [[ -z "$localPort" && -z "$remoteHost" && -z "$remotePort" ]]; then
    showHelp
fi

if [[ -z "$localPort" ]];then
    getLocalPort
fi
if [[ -z "$remoteHost" ]];then
    getRemoteHost
fi
if [[ -z "$remotePort" ]];then
    getRemotePort
fi

# echo -e "是否开机自启动？"
# read -p "请输入：Y 是 N 否" isAutoStart
# if [[ "$isAutoStart" == "Y" || "$isAutoStart" == "y" ]];then
# 	isAutoStart="Y"
# fi

startService

