#! /bin/bash
count=`iptables -nvxL OUTPUT --line-number | grep xiandan${1}xiandan | grep :${1} |awk '{print $1}' |cut -d: -f1 |wc -l`
for((i=1;i<=$count;i++));
do
    index=`iptables -nvxL OUTPUT --line-number | grep xiandan${1}xiandan | grep :${1} |awk '{print $1}' |head -1`
    iptables -D OUTPUT $index;
done;

count=`iptables -nvxL INPUT --line-number | grep xiandan${1}xiandan | grep :${1} |awk '{print $1}' |cut -d: -f1 |wc -l`
for((i=1;i<=$count;i++));
do
    index=`iptables -nvxL INPUT --line-number | grep xiandan${1}xiandan | grep :${1} |awk '{print $1}' |head -1`
    iptables -D INPUT $index;
done;
iptables -A INPUT -p tcp --dport $1 -m comment --comment xiandan${1}xiandan
iptables -A OUTPUT -p tcp --sport $1 -m comment --comment xiandan${1}xiandan
iptables -A INPUT -p udp --dport $1 -m comment --comment xiandan${1}xiandan
iptables -A OUTPUT -p udp --sport $1 -m comment --comment xiandan${1}xiandan