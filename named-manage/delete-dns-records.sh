#!/bin/bash
v_zone_dir='/var/named/zone-files'
v_fw_zone="${v_zone_dir}/ms.local-forward.db"
v_ptr_zone1="${v_zone_dir}/192.168.168.ms.local-reverse.db"
v_ptr_zone2="${v_zone_dir}/192.168.169.ms.local-reverse.db"
v_ptr_zone3="${v_zone_dir}/192.168.170.ms.local-reverse.db"
v_ptr_zone4="${v_zone_dir}/192.168.171.ms.local-reverse.db"

if ! sudo -l | grep NOPASSWD &> /dev/null
then
	echo -e "\nYou need sudo access without password to run this script ! \n"
	exit
fi

fn_get_a_record() {
	v_input_host=${1}
	if [[ ! -z ${v_input_host} ]]
	then
		v_a_record=${v_input_host}
		if [[ ! ${v_a_record} =~ ^[[:alpha:]]([-[:alnum:]]*)$ ]]
                then
			if ${v_if_autorun_false}
			then
                        	echo -e "Provided input hostname \"${v_a_record}\" is invalid!\n"
                        	echo -e "Please use only letters, numbers, and hyphens.\n (cannot start with a number or hyphen).\n"
			fi

			exit 9
                fi

	else
		while :
		do
			echo -e "\nPlease use only letters, numbers, and hyphens.\n (Please do not start with a number or hyphen)."
			echo -e "No need to append the domain name ms.local\n"
			read -p "Please Enter the hostname to be deleted : " v_a_record
			if [[ ${v_a_record} =~ ^[[:alpha:]]([-[:alnum:]]*)$ ]]
	       		then
    				break
  			else
    				echo -e "Invalid name!\nPlease use only letters, numbers, and hyphens.\n (cannot start with a number or hyphen).\n"
  			fi
		done
	fi

	if ! sudo grep "^${v_a_record} "  ${v_fw_zone} &>/dev/null
	then 
		if ${v_if_autorun_false}
		then
			echo -e "\nA Record for \"${v_a_record}\" not found in \"${v_fw_zone}\"\n"
			echo -e "Nothing to do ! Exiting !\n"
		fi

		exit 8
	fi
}



f_delete_records() {
	v_ptr_zone="${1}"
	v_input_delete_confirmation="${2}"
	while :
	do
		if [[ ! ${v_input_delete_confirmation} == "-y" ]]
		then
			read -p "Please confirm deletion of records (y/n) : " v_confirmation
		else
			v_confirmation='y'
		fi

		if [[ ${v_confirmation} == "y" ]]
		then

			sudo sed -i "/^${v_capture_ptr_prefix} /d" "${v_ptr_zone}"
			sudo sed -i "/^${v_capture_a_record}/d" "${v_fw_zone}"
			${v_if_autorun_false} && echo -e "\nDeleted A and PTR records of ${v_a_record} from ${v_ptr_zone} and ${v_fw_zone}.\n"

			${v_if_autorun_false} && echo -e "\nUpdating Serial Numbers of zone files . ..\n"
			
			v_current_serial_ptr_zone=$(sudo grep ';Serial' "${v_ptr_zone}" | cut -d ";" -f 1 | tr -d '[:space:]')
        		v_set_new_serial__ptr_zone=$(( v_current_serial_ptr_zone + 1 ))
        		sudo sed -i "/;Serial/s/${v_current_serial_ptr_zone}/${v_set_new_serial__ptr_zone}/g" "${v_ptr_zone}"

			v_current_serial_ptr_zone=$(sudo grep ';Serial' ${v_fw_zone} | cut -d ";" -f 1 | tr -d '[:space:]')
        		v_set_new_serial__ptr_zone=$(( v_current_serial_ptr_zone + 1 ))
        		sudo sed -i "/;Serial/s/${v_current_serial_ptr_zone}/${v_set_new_serial__ptr_zone}/g" "${v_fw_zone}"

			if ${v_if_autorun_false}
			then

				echo -e "\nReloading the DNS service ( named ) . . .\n"

        			sudo systemctl reload named &>/dev/null

        			if sudo systemctl is-active named &>/dev/null;
        			then
                			echo "Reloaded, service  named is active and running ."
        			else
                			echo -e "\nSomething went wrong !\n\
					Service named is not running !\nPlease troubleshoot manually\n"
        			fi

        			echo -e "\nSuccessfully deleted DNS records of \"${v_a_record}\"\n"
			fi

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

if [[ "${3}" != "Automated-Execution" ]]
then
	v_if_autorun_false=true	
else
	v_if_autorun_false=false	
fi

fn_get_a_record "${1}"

v_capture_a_record=$(sudo grep "^${v_a_record} " "${v_fw_zone}" ) 
v_capture_a_record_ip=$(sudo grep "^${v_a_record} " ${v_fw_zone} | awk '{print $NF}' | tr -d '[:space:]')
v_capture_ptr_prefix=$(awk -F. '{ print $4 }' <<< ${v_capture_a_record_ip} )

if echo ${v_capture_a_record_ip} | grep '192.168.168' &>/dev/null
then
	${v_if_autorun_false} && echo -e "\nMatch found with IP ${v_capture_a_record_ip} for ${v_a_record}.\n"
	f_delete_records "${v_ptr_zone1}" "${2}"

elif echo ${v_capture_a_record_ip} | grep '192.168.169' &>/dev/null
then
	${v_if_autorun_false} && echo -e "\nMatch found with IP ${v_capture_a_record_ip} for ${v_a_record}.\n"
	f_delete_records "${v_ptr_zone2}" "${2}"

elif echo ${v_capture_a_record_ip} | grep '192.168.170' &>/dev/null
then
	${v_if_autorun_false} && echo -e "\nMatch found with IP ${v_capture_a_record_ip} for ${v_a_record}.\n"
	f_delete_records "${v_ptr_zone3}" "${2}"

elif echo ${v_capture_a_record_ip} | grep '192.168.171' &>/dev/null
then
	${v_if_autorun_false} && echo -e "\nMatch found with IP ${v_capture_a_record_ip} for ${v_a_record}.\n"
	f_delete_records "${v_ptr_zone4}" "${2}"
fi

exit
