#!/bin/bash
var_named_manage_dir='/scripts_by_muthu/server/named-manage'
var_create_record="${var_named_manage_dir}/create-dns-records.sh"
var_zone_dir='/var/named/zone-files'
var_fw_zone="${var_zone_dir}/ms.local-forward.db"

if ! sudo -l | grep NOPASSWD &> /dev/null
then
	echo -e "\nYou need sudo access without password to run this script ! \n"
	exit
fi

if [ -z "${1}" ]
then
	echo
	read -p "Name of the file containing the list of host records to create : " v_host_create_file
else
	v_host_create_file="${1}"
fi

if [[ ! -f ${v_host_create_file} ]];then echo -e "\nFile \"${v_host_create_file}\" doesn't exist!\n";exit;fi 

if [[ ! -s ${v_host_create_file} ]];then echo -e "\nFile \"${v_host_create_file}\" is emty!\n";exit;fi

sed -i '/^[[:space:]]*$/d' ${v_host_create_file}

sed -i 's/.ms.local.//g' ${v_host_create_file}

sed -i 's/.ms.local//g' ${v_host_create_file}


while :
do
	echo -e "\nRecords to be created : \n"
	cat ${v_host_create_file}
	echo -e "\nNote : If a record already exists, will be ignored .\n"

	read -p "Do you want to proceed? (y/n) : " v_confirmation

	if [[ ${v_confirmation} == "y" ]]
	then
		break

	elif [[ ${v_confirmation} == "n" ]]
	then
		echo -e "\nCancelled without any changes !\n"
		exit
	else
		echo -e "\nSelect either (y/n) only !\n"
		continue
	fi
done

> /tmp/temp-hold-host-records-created-by-dnsmanager

for v_host_to_create in $(cat ${v_host_create_file}) 
do
	v_current_serial_fw_zone=$(sudo grep ';Serial' ${var_fw_zone} | cut -d ";" -f 1 | tr -d '[:space:]')

	"${var_create_record}" "${v_host_to_create}"

	var_exit_status=$(echo $?)

	if [[ ${var_exit_status} -eq 9 ]]
	then
		echo "${v_host_to_create} Invalid-Host" >>/tmp/temp-hold-host-records-created-by-dnsmanager

	elif [[ ${var_exit_status} -eq 8 ]]
	then
		echo "${v_host_to_create} Already-Exists" >>/tmp/temp-hold-host-records-created-by-dnsmanager

	elif [[ ${var_exit_status} -eq 255 ]]
	then
		echo "${v_host_to_create} IP-Exhausted" >>/tmp/temp-hold-host-records-created-by-dnsmanager
	else
		v_serial_fw_zone_post_execution=$(sudo grep ';Serial' ${var_fw_zone} | cut -d ";" -f 1 | tr -d '[:space:]')

		if [[ "${v_current_serial_fw_zone}" -ne "${v_serial_fw_zone_post_execution}" ]]
		then
			echo "${v_host_to_create} Created" >>/tmp/temp-hold-host-records-created-by-dnsmanager
		else
			echo "${v_host_to_create} Failed-to-Create" >>/tmp/temp-hold-host-records-created-by-dnsmanager
		fi
	fi
done

echo -e "\nScript $(basename $0) completed execution !"
echo -e "\nPlease find the below details of the records :\n"
tput bold && tput setaf 6 && \
	echo -e "Action-Taken     FQDN ( IPv4-Address )" \
        && tput sgr0

for v_host in $(cat ${v_host_create_file})
do
	v_host_record_status=$(grep -w "^${v_host}" /tmp/temp-hold-host-records-created-by-dnsmanager | cut -d " " -f 2)

	if echo "${v_host_record_status}" | grep Created &>/dev/null
	then
		v_host_record_status="Created         "
	
	elif echo "${v_host_record_status}" | grep Invalid-Host &>/dev/null
	then
		v_host_record_status="Invalid-Host    "

	elif echo "${v_host_record_status}" | grep IP-Exhausted &>/dev/null
	then
		v_host_record_status="IP-Exhausted    "

	elif echo "${v_host_record_status}" | grep Already-Exists &>/dev/null
	then
		v_host_record_status="Already-Exists  "

	elif echo "${v_host_record_status}" | grep Failed-to-Create &>/dev/null
	then
		v_host_record_status="Failed-to-Create"
	fi

        v_fqdn="${v_host}.ms.local"

        v_ip_address=$(nslookup ${v_fqdn} | grep ^Name -A 1 | grep Address | cut -d ":" -f 2 | tr -d '[[:space:]]')

	echo "${v_host_record_status} ${v_fqdn} ( ${v_ip_address} )"
done
echo

rm -f /tmp/temp-hold-host-records-created-by-dnsmanager

exit
