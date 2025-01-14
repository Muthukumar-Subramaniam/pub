#!/bin/bash
var_named_manage_dir='/scripts_by_muthu/server/named-manage'
var_delete_record="${var_named_manage_dir}/delete-dns-records.sh"
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
	read -p "Name of the file containing the list of host records to delete : " v_host_delete_file
else
	v_host_delete_file="${1}"
fi

if [[ ! -f ${v_host_delete_file} ]];then echo -e "\nFile \"${v_host_delete_file}\" doesn't exist!\n";exit;fi 

if [[ ! -s ${v_host_delete_file} ]];then echo -e "\nFile \"${v_host_delete_file}\" is emty!\n";exit;fi

sed -i '/^[[:space:]]*$/d' ${v_host_delete_file}

sed -i 's/.ms.local.//g' ${v_host_delete_file}

sed -i 's/.ms.local//g' ${v_host_delete_file}

while :
do
	echo -e "\nRecords to be deleted : "
	cat ${v_host_delete_file} 
        echo -e "\nNote : If a record doesn't exist, will be ignored .\n"

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

> /tmp/temp-hold-host-records-deleted-by-dnsmanager

for v_host_to_delete in $(cat ${v_host_delete_file}) 
do
	v_current_serial_fw_zone=$(sudo grep ';Serial' ${var_fw_zone} | cut -d ";" -f 1 | tr -d '[:space:]')

	echo -e "\nRunning delete-dns-records.sh for ${v_host_to_delete} . . .\n"
 	"${var_delete_record}" "${v_host_to_delete}" -y

	var_exit_status=$(echo $?)

	if [[ ${var_exit_status} -eq 9 ]]
	then
		echo "${v_host_to_delete} Invalid-Host" >>/tmp/temp-hold-host-records-deleted-by-dnsmanager

	elif [[ ${var_exit_status} -eq 8 ]]
	then
		echo "${v_host_to_delete} Doesn't-Exist" >>/tmp/temp-hold-host-records-deleted-by-dnsmanager
	else
		v_serial_fw_zone_post_execution=$(sudo grep ';Serial' ${var_fw_zone} | cut -d ";" -f 1 | tr -d '[:space:]')

		if [[ "${v_current_serial_fw_zone}" -ne "${v_serial_fw_zone_post_execution}" ]]
		then
			echo "${v_host_to_delete} Deleted" >>/tmp/temp-hold-host-records-deleted-by-dnsmanager
		else
			echo "${v_host_to_delete} Failed-To-Delete" >>/tmp/temp-hold-host-records-deleted-by-dnsmanager
		fi
	fi
done

echo -e "\nScript $(basename $0) completed execution !"
echo -e "\nPlease find the below details of the records :\n"
tput bold && tput setaf 6 && \
        echo -e "Action-Taken     FQDN" \
        && tput sgr0

for v_host in $(cat ${v_host_delete_file})
do
	v_host_record_status=$(grep -w "^${v_host}" /tmp/temp-hold-host-records-deleted-by-dnsmanager | cut -d " " -f 2)

	if echo "${v_host_record_status}" | grep Deleted &>/dev/null
	then
		v_host_record_status="Deleted         "

	elif echo "${v_host_record_status}" | grep Invalid-Host &>/dev/null
	then
		v_host_record_status="Invalid-Host    "

	elif echo "${v_host_record_status}" | grep "Doesn't-Exist" &>/dev/null
	then
		v_host_record_status="Doesn't-Exist   "

	elif echo "${v_host_record_status}" | grep Failed-To-Delete &>/dev/null
	then
		v_host_record_status="Failed-To-Delete"
	fi

        v_fqdn="${v_host}.ms.local"

        echo "${v_host_record_status} ${v_fqdn}"
done
echo

rm -f /tmp/temp-hold-host-records-deleted-by-dnsmanager

exit
