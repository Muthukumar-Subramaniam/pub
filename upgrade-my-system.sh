#!/bin/bash
V_Executing=$(tput bold && tput setaf 2 && echo Executing && tput sgr0)
V_Executing=${V_Executing//$'\n'/}

>/root/log.upgrade-my-system.sh

{
echo -e "\n System Upgrade started for $(hostname) at : $(date)"

if grep "openSUSE" /etc/os-release &>/dev/null ;then
echo -e "\n$V_Executing : zypper clean -a" 
zypper clean -a 
echo -e "\n$V_Executing : zypper refresh" 
zypper refresh
echo -e "\n$V_Executing : zypper update -y"
zypper update -y 
fi

if grep "Ubuntu" /etc/os-release &>/dev/null ;then
echo -e "\n$V_Executing : apt-get clean" 
apt-get clean 
echo -e "\n$V_Executing : apt-get update"
apt-get update
echo -e "\n$V_Executing : apt-get upgrade -y"
apt-get upgrade -y
fi

if grep -E "Rocky Linux|AlmaLinux|Oracle Linux" /etc/os-release &>/dev/null ;then
echo -e "\n$V_Executing : dnf clean all"
dnf clean all
echo -e "\n$V_Executing : dnf upgrade -y"
dnf upgrade -y
fi

if grep "Red Hat Enterprise Linux" /etc/os-release &>/dev/null ;then
echo -e "\n$V_Executing : dnf clean all"
dnf clean all
echo -e "\n$V_Executing : dnf upgrade -y"
dnf upgrade -y
echo -e "\n$V_Executing : dnf uploadprofile --force-upload"
dnf uploadprofile --force-upload
echo -e "\n$V_Executing : subscription-manager facts --update"
subscription-manager facts --update
echo -e "\n$V_Executing : subscription-manager refresh"
subscription-manager refresh
echo -e "\n$V_Executing : insights-client"
insights-client
fi

echo -e "\n System Upgrade ended $(hostname) at : $(date) \n"
} | tee -a /root/log.upgrade-my-system.sh
