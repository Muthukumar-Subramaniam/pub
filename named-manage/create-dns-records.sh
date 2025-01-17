#!/bin/bash
v_zone_dir='/var/named/zone-files'
v_fw_zone="${v_zone_dir}/ms.local-forward.db"
v_ptr_zone1="${v_zone_dir}/192.168.168.ms.local-reverse.db"
v_ptr_zone2="${v_zone_dir}/192.168.169.ms.local-reverse.db"
v_ptr_zone3="${v_zone_dir}/192.168.170.ms.local-reverse.db"
v_ptr_zone4="${v_zone_dir}/192.168.171.ms.local-reverse.db"
v_tmp_ptr_zone1_exhausted="/tmp/tmp_ptr_zone1_exhausted"
v_tmp_ptr_zone2_exhausted="/tmp/tmp_ptr_zone2_exhausted"
v_tmp_ptr_zone3_exhausted="/tmp/tmp_ptr_zone3_exhausted"
v_tmp_ptr_zone4_exhausted="/tmp/tmp_ptr_zone4_exhausted"

if ! sudo -l | grep NOPASSWD &> /dev/null
then
	echo -e "\nYou need sudo access without password to run this script ! \n"
	exit
fi

fn_check_free_ip() {

	local v_file_ptr_zone="${1}"
	local v_start_ip="${2}"
	local v_max_ip="${3}"
	local v_subnet="${4}"
	local v_capture_list_of_ips=$(sudo sed -n 's/^\([0-9]\+\).*/\1/p' "${v_file_ptr_zone}")
	declare -A v_existing_ips

	if [ -z "${v_capture_list_of_ips}" ]
	then
		v_host_part_of_current_ip="${v_start_ip}"
		v_previous_ip=';PTR-Records'
		v_current_ip="${v_subnet}.${v_host_part_of_current_ip}"
		v_ptr_zone="${v_file_ptr_zone}"
		return 0
	fi

	while IFS= read -r ip
	do
        	v_existing_ips["$ip"]=1
	done <<< "${v_capture_list_of_ips}"

	for ((v_num_ptr = ${v_start_ip}; v_num_ptr <= ${v_max_ip}; v_num_ptr++))
	do
		if [[ -z "${v_existing_ips[$v_num_ptr]+isset}" ]]
		then
			v_host_part_of_current_ip="${v_num_ptr}"
			v_host_part_of_previous_ip=$((v_num_ptr - 1))
			v_current_ip="${v_subnet}.${v_host_part_of_current_ip}"
			v_previous_ip="${v_subnet}.${v_host_part_of_previous_ip}"
			v_ptr_zone="${v_file_ptr_zone}"
			return 0
		fi
	done

	return 1
}	


f_update_dns_records() {

	############### A Record Updating Section ############################

  	v_target_length=39
        v_num_spaces=$(( v_target_length - ${#v_a_record} ))
  	v_a_record_adjusted_space="${v_a_record}$(printf '%*s' "${v_num_spaces}")"

	${v_if_autorun_false} && echo -e "\nUpdating A Record . . .\n"

	v_add_a_record=$(echo "${v_a_record_adjusted_space} IN A ${v_current_ip}")

	if [[ "${v_previous_ip}" == ';PTR-Records' ]]
	then
		echo "${v_add_a_record}" | sudo tee -a "${v_fw_zone}" &>/dev/null
	else
		sudo sed -i "/${v_previous_ip}$/a \\${v_add_a_record}" "${v_fw_zone}"
	fi

	v_current_serial_ptr_zone=$(sudo grep ';Serial' ${v_fw_zone} | cut -d ";" -f 1 | tr -d '[:space:]')
	v_set_new_serial__ptr_zone=$(( v_current_serial_ptr_zone + 1 ))
	sudo sed -i "/;Serial/s/${v_current_serial_ptr_zone}/${v_set_new_serial__ptr_zone}/g" "${v_fw_zone}"

	##################  End of  A Record Updating Section ############################



	################## PTR Record Updating  Section ###################################
	${v_if_autorun_false} && echo -e "\nUpdating PTR Record . . .\n"


	# Checking number of digits in the IP
	if [[ "${#v_host_part_of_current_ip}" -eq 1 ]]
	then
  		v_digits=1

	elif [[ "${#v_host_part_of_current_ip}" -eq 2 ]]
	then
  		v_digits=2

	elif [[ "${#v_host_part_of_current_ip}" -eq 3 ]]
	then
  		v_digits=3
	fi


	if [[ "${v_digits}" -eq 1 ]]
	then
		v_add_ptr_record=$(echo "${v_host_part_of_current_ip}   IN PTR ${v_a_record}.ms.local.")
		if [[ "${v_previous_ip}" == ';PTR-Records' ]]
		then
			echo "${v_add_ptr_record}" | sudo tee -a "${v_ptr_zone}" &>/dev/null
		else
			sudo sed -i "/^${v_host_part_of_previous_ip} /a\\${v_add_ptr_record}" "${v_ptr_zone}"
		fi

	elif [[ "${v_digits}" -eq 2 ]]
	then
		v_add_ptr_record=$(echo "${v_host_part_of_current_ip}  IN PTR ${v_a_record}.ms.local.")
		sudo sed -i "/^${v_host_part_of_previous_ip} /a\\${v_add_ptr_record}" "${v_ptr_zone}"

	elif [[ "${v_digits}" -eq 3 ]]
	then
		v_add_ptr_record=$(echo "${v_host_part_of_current_ip} IN PTR ${v_a_record}.ms.local.")
		sudo sed -i "/^${v_host_part_of_previous_ip} /a\\${v_add_ptr_record}" "${v_ptr_zone}"
	fi

	v_current_serial_ptr_zone=$(sudo grep ';Serial' "${v_ptr_zone}" | cut -d ";" -f 1 | tr -d '[:space:]')
	v_set_new_serial__ptr_zone=$(( v_current_serial_ptr_zone + 1 ))
	sudo sed -i "/;Serial/s/${v_current_serial_ptr_zone}/${v_set_new_serial__ptr_zone}/g" "${v_ptr_zone}"

	############# End of PTR Record Updating Section #######################

	if ${v_if_autorun_false}
	then
		echo -e "\nReloading the DNS service ( named ) . . .\n"

		sudo systemctl reload named &>/dev/null

		if sudo systemctl is-active named &>/dev/null;
		then 
			echo "Reloaded, service  named is active and running ."
		else
			echo -e "\nSomething went wrong !\nService named is not running !\nPlease troubleshoot manually\n"
		fi
        
		echo -e "\nSuccessfully created DNS records for \"${v_a_record}\"\n"
	
		echo -e "\nForward Look Up ...\n"

		nslookup ${v_a_record} | grep -A 1 ^Name 
	
		echo -e "\nReverse Look Up ...\n"

		nslookup ${v_current_ip} 
	fi
}


	
f_get_a_record() {
	v_input_host="${1}"
	if [[ ! -z ${v_input_host} ]]
	then
                v_a_record=${1}
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

			read -p "Please Enter the name of host record to create : " v_a_record

			if [[ ${v_a_record} =~ ^[[:alpha:]]([-[:alnum:]]*)$ ]]
	       		then
    				break
  			else
    				echo -e "Invalid name!\nPlease use only letters, numbers, and hyphens.\n (cannot start with a number or hyphen).\n"
  			fi
		done
	fi

	if sudo grep -w "^${v_a_record} "  ${v_fw_zone} &>/dev/null
	then 
		${v_if_autorun_false} && echo -e "\nA Record for \"${v_a_record}\" already exists in \"${v_fw_zone}\"\n"
		exit 8
	fi
}
	
if [[ "${2}" != "Automated-Execution" ]]
then
	v_if_autorun_false=true	
else
	v_if_autorun_false=false	
fi

f_get_a_record "${1}"

${v_if_autorun_false} && echo -e "\nLooking for available IPs in Network 192.168.168.0/22 . . .\n"

fn_check_zones_and_find_ip() {

	if [ ! -f "${v_tmp_ptr_zone1_exhausted}" ]
	then 
		if ! fn_check_free_ip "${v_ptr_zone1}" "1" "255" "192.168.168"
		then
			touch "${v_tmp_ptr_zone1_exhausted}"
			fn_check_zones_and_find_ip
		fi

	elif [ ! -f "${v_tmp_ptr_zone2_exhausted}" ]
	then 
		if ! fn_check_free_ip "${v_ptr_zone2}" "0" "255" "192.168.169"
		then
			touch "${v_tmp_ptr_zone2_exhausted}"
			fn_check_zones_and_find_ip
		fi

	elif [ ! -f "${v_tmp_ptr_zone3_exhausted}" ]
	then 
		if ! fn_check_free_ip "${v_ptr_zone3}" "0" "255" "192.168.170"
		then
			touch "${v_tmp_ptr_zone3_exhausted}"
			fn_check_zones_and_find_ip
		fi

	elif [ ! -f "${v_tmp_ptr_zone4_exhausted}" ]
	then 
		if ! fn_check_free_ip "${v_ptr_zone4}" "0" "254" "192.168.171"
		then
			touch "${v_tmp_ptr_zone4_exhausted}"
			fn_check_zones_and_find_ip
		fi
	else
		${v_if_autorun_false} && echo -e "\nNo more IPs available in 192.168.168.0/22 Network of ms.local domain! \n"
		exit 255
	fi
}

fn_check_zones_and_find_ip

f_update_dns_records

exit
