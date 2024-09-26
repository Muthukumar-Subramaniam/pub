#!/bin/bash
v_zone_dir='/var/named'
v_fw_zone="${v_zone_dir}/ms.local-forward.db"
v_ptr_zone1="${v_zone_dir}/192.168.168.ms.local-reverse.db"
v_ptr_zone2="${v_zone_dir}/192.168.169.ms.local-reverse.db"
v_ptr_zone3="${v_zone_dir}/192.168.170.ms.local-reverse.db"
v_ptr_zone4="${v_zone_dir}/192.168.171.ms.local-reverse.db"

if [[ "$(id -u)" -ne 0 ]]
then
	echo -e "\nPlease run this script as root or using sudo ! \n"
	exit
fi

fn_get_a_record() {
	v_input_host=${1}
	if [[ ! -z ${v_input_host} ]]
	then
		v_a_record=${v_input_host}
		if [[ ! ${v_a_record} =~ ^[[:alpha:]]([-[:alnum:]]*)$ ]]
                then
			echo -e "1st command line parameter \"${v_a_record}\" provided is invalid!\n"
                        echo -e "Please use only letters, numbers, and hyphens.\n (cannot start with a number).\n"
			exit
                fi

	else
		echo -e "\n<< This script deletes fqdn from ms.local domain >>\n\nNote: Both A and PTR record will be deleted automatically\n"
		while :
		do
			echo -e "\nPlease use only letters, numbers, and hyphens.\n (Please do not start with a number)."
			echo -e "No need to append the domain name ms.local\n"
			read -p "Please Enter the hostname to be deleted : " v_a_record
			if [[ ${v_a_record} =~ ^[[:alpha:]]([-[:alnum:]]*)$ ]]
	       		then
    				break
  			else
    				echo -e "Invalid name!\nPlease use only letters, numbers, and hyphens.\n (cannot start with a number).\n"
  			fi
		done
	fi

	if ! grep "^${v_a_record} "  ${v_fw_zone}
	then 
		echo -e "\nA Record for \"${v_a_record}\" not found in \"${v_fw_zone}\"\n"
		echo -e "Nothing to do ! Exiting !\n"
		exit
	fi
}



f_delete_records() {
	v_ptr_zone="${1}"
	v_input_delete_confirmation="${2}"
	while :
	do
		if [[ ! ${v_input_delete_confirmation} == "-y" ]]
		then
			read -p "Please confirm deletion of records (y/n) :" v_confirmation
		else
			v_confirmation='y'
		fi

		if [[ ${v_confirmation} == "y" ]]
		then

			sed -i "/^${v_capture_ptr_prefix} /d" "${v_ptr_zone}"
			sed -i "/^${v_capture_a_record}/d" "${v_fw_zone}"
			echo -e "\nDeleted A and PTR records of ${v_a_record} from ${v_ptr_zone} and ${v_fw_zone}.\n"

			echo -e "\nUpdating Serial Numbers of zone files . ..\n"
			
			v_current_serial_ptr_zone=$(grep ';Serial' "${v_ptr_zone}" | cut -d ";" -f 1 | tr -d '[:space:]')
        		v_set_new_serial__ptr_zone=$(( v_current_serial_ptr_zone + 1 ))
        		sed -i "/;Serial/s/${v_current_serial_ptr_zone}/${v_set_new_serial__ptr_zone}/g" "${v_ptr_zone}"

			v_current_serial_ptr_zone=$(grep ';Serial' ${v_fw_zone} | cut -d ";" -f 1 | tr -d '[:space:]')
        		v_set_new_serial__ptr_zone=$(( v_current_serial_ptr_zone + 1 ))
        		sed -i "/;Serial/s/${v_current_serial_ptr_zone}/${v_set_new_serial__ptr_zone}/g" "${v_fw_zone}"


			echo -e "\nReloading the DNS service ( named ) . . .\n"

        		systemctl reload named &>/dev/null

        		if systemctl is-active named &>/dev/null;
        		then
                		echo "Reloaded, service  named is active and running ."
        		else
                		echo -e "\nSomething went wrong !\n\
				Service named is not running !\nPlease troubleshoot manually\n"
        		fi

        		echo -e "\nSuccessfully deleted DNS records of \"${v_a_record}\"\n"
			break

		elif [[ ${v_confirmation} == "n" ]]
		then
			echo -e "\nCancelled without any changes !\n"
			break

		else
			echo -e "\nSelect only either (y/n) !\n"
			continue

		fi
	done
}

fn_get_a_record "${1}"

v_capture_a_record=$(grep "^${v_a_record} " "${v_fw_zone}" ) 
v_capture_a_record_ip=$(grep "^${v_a_record} " ${v_fw_zone} | cut -d "A" -f 2 | tr -d '[[:space:]]')
v_capture_ptr_prefix=$(echo ${v_capture_a_record_ip} | cut -d "." -f 4 )

if echo ${v_capture_a_record_ip} | grep '192.168.168' &>/dev/null
then
	echo -e "\nMatch found with IP ${v_capture_a_record_ip} for ${v_a_record}.\n"
	f_delete_records "${v_ptr_zone1}" "${2}"

elif echo ${v_capture_a_record_ip} | grep '192.168.169' &>/dev/null
then
	echo -e "\nMatch found with IP ${v_capture_a_record_ip} for ${v_a_record}.\n"
	f_delete_records "${v_ptr_zone2}" "${2}"

elif echo ${v_capture_a_record_ip} | grep '192.168.170' &>/dev/null
then
	echo -e "\nMatch found with IP ${v_capture_a_record_ip} for ${v_a_record}.\n"
	f_delete_records "${v_ptr_zone3}" "${2}"

elif echo ${v_capture_a_record_ip} | grep '192.168.171' &>/dev/null
then
	echo -e "\nMatch found with IP ${v_capture_a_record_ip} for ${v_a_record}.\n"
	f_delete_records "${v_ptr_zone4}" "${2}"
fi

exit
