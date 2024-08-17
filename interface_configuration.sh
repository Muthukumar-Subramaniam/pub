#!/bin/bash

mkdir -p /etc/systemd/network

V_count=0
for v_interface in $(ls /sys/class/net | grep -v lo)
do
	echo -e "[Match]\nMACAddress=$(ip link | grep $v_interface -A 1 | grep link/ether | cut -d " " -f 6)\n\n[Link]\nName=eth$V_count" >/etc/systemd/network/7$V_count-eth$V_count.link;V_count=$((V_count+1))
done

rm -rf /etc/NetworkManager/system-connections/*

nmcli connection add connection.id eth0 connection.interface-name eth0 type ethernet ipv4.method manual ipv4.addresses 192.168.168.253/24 ipv4.gateway 192.168.168.1 ipv4.dns 192.168.168.201 ipv4.dns-search ms.local ipv6.method disabled

v_iface_total=$(ls /sys/class/net | grep -v lo | wc -l)
v_iface_dhcp=$((v_iface_total-1))
for v_iface in $(seq $v_iface_dhcp)
do 
	nmcli connection add connection.id eth$v_iface connection.interface-name eth$v_iface type ethernet ipv4.method auto ipv6.method disabled
done