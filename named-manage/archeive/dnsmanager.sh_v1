#!/bin/bash
# Define color codes
v_RED='\033[0;31m'      # Red
v_GREEN='\033[0;32m'    # Green
v_YELLOW='\033[0;33m'   # Yellow
v_BLUE='\033[0;34m'     # Blue
v_CYAN='\033[0;36m'     # Cyan
v_MAGENTA='\033[0;35m'  # Magenta
v_RESET='\033[0m'       # Reset to default color
var_named_manage_dir='/scripts_by_muthu/server/named-manage'
var_zone_dir='/var/named/zone-files'
v_fw_zone="${var_zone_dir}/ms.local-forward.db"
v_ptr_zone1="${var_zone_dir}/192.168.168.ms.local-reverse.db"
v_ptr_zone2="${var_zone_dir}/192.168.169.ms.local-reverse.db"
v_ptr_zone3="${var_zone_dir}/192.168.170.ms.local-reverse.db"
v_ptr_zone4="${var_zone_dir}/192.168.171.ms.local-reverse.db"
v_tmp_ptr_zone1_exhausted="/tmp/tmp_ptr_zone1_exhausted"
v_tmp_ptr_zone2_exhausted="/tmp/tmp_ptr_zone2_exhausted"
v_tmp_ptr_zone3_exhausted="/tmp/tmp_ptr_zone3_exhausted"
v_tmp_ptr_zone4_exhausted="/tmp/tmp_ptr_zone4_exhausted"
v_tmp_file_dnsmanager="/tmp/tmp_file_dnsmanager"

if ! sudo -l | grep NOPASSWD &> /dev/null
then
	echo -e "\nYou need sudo access without password to run this script! \n"
	exit
fi

fn_get_host_record() {
	v_input_host="${1}"
	v_action_requested="${2}"

	fn_instruct_on_valid_host_record() {
		echo -e "\n${v_RED}> Only letters, numbers, and hyphens are allowed."
		echo -e "> Hyphens cannot appear at the start or end."
		echo -e "> The total length must be between 1 and 63 characters."
		echo -e "> The domain name 'ms.local' will be appended if not present."
		echo -e "> Follows the format defined in RFC 1035.${v_RESET}\n"
		exit
	}

	fn_get_host_record_from_user() {

		while :
		do
			echo

			if [[ "${v_action_requested}" != "rename" ]]
			then
				read -p "Please Enter the name of host record to ${v_action_requested} : " v_input_host_record
			else
				if [ -z "${v_host_record}" ]
				then
					read -p "Please Enter the name of host record to ${v_action_requested} : " v_input_host_record
				else
					read -p "Please Enter the name of host record to ${v_action_requested} \"${v_host_record}\" : " v_input_host_record
				fi
			fi
				
			v_input_host_record="${v_input_host_record%.ms.local.}"  
			v_input_host_record="${v_input_host_record%.ms.local}"

			if [[ "${v_action_requested}" != "rename" ]]
			then
				v_host_record="${v_input_host_record}"
			else
				if [ -z "${v_host_record}" ]
				then
					v_host_record="${v_input_host_record}"
				else
					v_rename_record="${v_input_host_record}"
				fi
			fi

			if [[ "${#v_input_host_record}" -le 63 ]] && [[ "${v_input_host_record}" =~ ^[[:alnum:]]([-[:alnum:]]*[[:alnum:]])$ ]]
	       		then
				if [[ "${v_action_requested}" != "rename" ]]
				then
					v_host_record="${v_input_host_record}"
				else
					if [ -z "${v_host_record}" ]
					then
						v_host_record="${v_input_host_record}"
					else
						v_rename_record="${v_input_host_record}"
					fi
				fi

    				break
  			else
				fn_instruct_on_valid_host_record
  			fi
		done
	}

	if [[ ! -z ${v_input_host} ]]
	then
                v_host_record=${1}
		v_host_record="${v_host_record%.ms.local.}"  
		v_host_record="${v_host_record%.ms.local}"

		if [[ ! ${v_host_record} =~ ^[[:alnum:]]([-[:alnum:]]*[[:alnum:]])$ ]] || [[ ! "${#v_host_record}" -le 63 ]]
		then
                        if ${v_if_autorun_false}
			then
				fn_instruct_on_valid_host_record
			else
				return 9
			fi
		fi

	else
		fn_get_host_record_from_user
	fi

	if sudo grep "^${v_host_record} "  "${v_fw_zone}" &>/dev/null
	then 
		if [[ "${v_action_requested}" == "create" ]]
		then
			${v_if_autorun_false} && echo -e "\nA Record for \"${v_host_record}\" already exists in \"${v_fw_zone}\"\n"
			return 8

		elif [[ "${v_action_requested}" == "rename" ]]
		then
			fn_get_host_record_from_user

			if sudo grep "^${v_rename_record} "  "${v_fw_zone}" &>/dev/null
			then 
				echo -e "\nConflict : Existing A Record found for \"${v_rename_record}\" in  \"${v_fw_zone}\"\n"
				echo -e "Nothing to do ! Exiting !\n"
				exit
			fi
		fi

	elif [[ "${v_action_requested}" != "create" ]]
	then
		if ${v_if_autorun_false}
		then
			echo -e "\nA Record for \"${v_host_record}\" not found in \"${v_fw_zone}\"\n"
			echo -e "Nothing to do ! Exiting !\n"
			exit
		else
			return 8
		fi
		
	fi
}

fn_update_serial_number_of_zones() {

	${v_if_autorun_false} && echo -e "\nUpdating serial numbers of zone files . . .\n"

	v_current_serial_ptr_zone=$(sudo grep ';Serial' ${v_fw_zone} | cut -d ";" -f 1 | tr -d '[:space:]')
	v_set_new_serial__ptr_zone=$(( v_current_serial_ptr_zone + 1 ))
	sudo sed -i "/;Serial/s/${v_current_serial_ptr_zone}/${v_set_new_serial__ptr_zone}/g" "${v_fw_zone}"

	v_current_serial_ptr_zone=$(sudo grep ';Serial' "${v_ptr_zone}" | cut -d ";" -f 1 | tr -d '[:space:]')
	v_set_new_serial__ptr_zone=$(( v_current_serial_ptr_zone + 1 ))
	sudo sed -i "/;Serial/s/${v_current_serial_ptr_zone}/${v_set_new_serial__ptr_zone}/g" "${v_ptr_zone}"
}


fn_reload_named_dns_service() {

	echo -e "\nReloading the DNS service ( named ) . . .\n"

	sudo systemctl reload named &>/dev/null

	if sudo systemctl is-active named &>/dev/null;
	then 
		echo "Reloaded, service  named is active and running ."
	else
		echo -e "\nSomething went wrong !\nService named is not running !\nPlease troubleshoot manually\n"
	fi
        

	if [[  "${v_action_requested}" == "create" ]]
	then
		echo -e "\nSuccessfully created DNS host record \"${v_host_record}\"\n"
	 
	elif [[ "${v_action_requested}" == "delete" ]]
	then
		echo -e "\nSuccessfully deleted DNS host record \"${v_host_record}\"\n"

	elif [[ "${v_action_requested}" == "rename" ]]
	then
        	echo -e "\nSuccessfully renamed DNS record of \"${v_host_record}\" to \"${v_rename_record}\" \n"
	fi


	if [[ "${v_action_requested}" != "delete" ]]
	then

		echo -e "\nForward Look Up ...\n"

		if  [[ "${v_action_requested}" == "rename" ]]
		then
			nslookup ${v_rename_record} | grep -A 1 ^Name
		else
			nslookup ${v_host_record} | grep -A 1 ^Name 
		fi
	
		echo -e "\nReverse Look Up ...\n"

		nslookup ${v_current_ip_of_host_record} 
	fi
}

fn_set_ptr_zone() {

	if echo ${v_current_ip_of_host_record} | grep '192.168.168' &>/dev/null
	then
		${v_if_autorun_false} && echo -e "\nMatch found with IP ${v_current_ip_of_host_record} for ${v_host_record}.\n"
		v_ptr_zone="${v_ptr_zone1}"

	elif echo ${v_current_ip_of_host_record} | grep '192.168.169' &>/dev/null
	then
		${v_if_autorun_false} && echo -e "\nMatch found with IP ${v_current_ip_of_host_record} for ${v_host_record}.\n"
		v_ptr_zone="${v_ptr_zone2}"

	elif echo ${v_current_ip_of_host_record} | grep '192.168.170' &>/dev/null
	then
		${v_if_autorun_false} && echo -e "\nMatch found with IP ${v_current_ip_of_host_record} for ${v_host_record}.\n"
		v_ptr_zone="${v_ptr_zone3}"

	elif echo ${v_current_ip_of_host_record} | grep '192.168.171' &>/dev/null
	then
		${v_if_autorun_false} && echo -e "\nMatch found with IP ${v_current_ip_of_host_record} for ${v_host_record}.\n"
		v_ptr_zone="${v_ptr_zone4}"
	fi
}


fn_create_host_record() {

	if [[ "${2}" != "Automated-Execution" ]]
	then
		v_if_autorun_false=true	
	else
		v_if_autorun_false=false	
	fi

	fn_get_host_record "${1}" "create"

	v_exit_status_fn_get_host_record=${?}

	if [[ ${v_exit_status_fn_get_host_record} -ne 0 ]]
	then
		return ${v_exit_status_fn_get_host_record}
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
			v_current_ip_of_host_record="${v_subnet}.${v_host_part_of_current_ip}"
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
				v_current_ip_of_host_record="${v_subnet}.${v_host_part_of_current_ip}"
				v_previous_ip="${v_subnet}.${v_host_part_of_previous_ip}"
				v_ptr_zone="${v_file_ptr_zone}"
				return 0
			fi
		done

		return 1
	}	
	
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
			return 255
		fi

	}

	fn_check_zones_and_find_ip
	
	v_exit_status_fn_check_zones_and_find_ip=${?}

	if [[ ${v_exit_status_fn_check_zones_and_find_ip} -eq 255 ]]
	then
		return 255
	fi

	############### A Record Creation Section ############################

	v_host_record_adjusted_space=$(printf "%-*s" 63 "${v_host_record}")

	${v_if_autorun_false} && echo -e "\nUpdating A Record . . .\n"

	v_add_host_record=$(echo "${v_host_record_adjusted_space} IN A ${v_current_ip_of_host_record}")

	if [[ "${v_previous_ip}" == ';PTR-Records' ]]
	then
		echo "${v_add_host_record}" | sudo tee -a "${v_fw_zone}" &>/dev/null
	else
		sudo sed -i "/${v_previous_ip}$/a \\${v_add_host_record}" "${v_fw_zone}"
	fi

	##################  End of  A Record Create Section ############################



	################## PTR Record Create  Section ###################################
	${v_if_autorun_false} && echo -e "\nUpdating PTR Record . . .\n"

	v_space_adjusted_host_part_of_current_ip=$(printf "%-*s" 3 "${v_host_part_of_current_ip}")

	v_add_ptr_record=$(echo "${v_space_adjusted_host_part_of_current_ip} IN PTR ${v_host_record}.ms.local.")

	if [[ "${v_previous_ip}" == ';PTR-Records' ]]
	then
		echo "${v_add_ptr_record}" | sudo tee -a "${v_ptr_zone}" &>/dev/null
	else
		sudo sed -i "/^${v_host_part_of_previous_ip} /a\\${v_add_ptr_record}" "${v_ptr_zone}"
	fi

	############# End of PTR Record Create Section #######################

	fn_update_serial_number_of_zones

	if ${v_if_autorun_false}
	then
		fn_reload_named_dns_service
	fi
}


fn_delete_host_record() {

	if [[ "${3}" != "Automated-Execution" ]]
	then
		v_if_autorun_false=true	
	else
		v_if_autorun_false=false	
	fi

	fn_get_host_record "${1}" "delete"

	v_exit_status_fn_get_host_record=${?}

	if [[ ${v_exit_status_fn_get_host_record} -ne 0 ]]
	then
		return ${v_exit_status_fn_get_host_record}
	fi

	v_capture_host_record=$(sudo grep "^${v_host_record} " "${v_fw_zone}" ) 
	v_current_ip_of_host_record=$(sudo grep "^${v_host_record} " ${v_fw_zone} | awk '{print $NF}' | tr -d '[:space:]')
	v_capture_ptr_prefix=$(awk -F. '{ print $4 }' <<< ${v_current_ip_of_host_record} )

	fn_set_ptr_zone
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
			sudo sed -i "/^${v_capture_host_record}/d" "${v_fw_zone}"
			${v_if_autorun_false} && echo -e "\nDeleted A and PTR records of ${v_host_record} from ${v_ptr_zone} and ${v_fw_zone}.\n"

			fn_update_serial_number_of_zones

			if ${v_if_autorun_false}
			then
				fn_reload_named_dns_service
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

fn_rename_host_record() {

	if [[ "${3}" != "Automated-Execution" ]]
	then
		v_if_autorun_false=true	
	else
		v_if_autorun_false=false	
	fi

	fn_get_host_record "${1}" "rename"

	v_exit_status_fn_get_host_record=${?}

	if [[ ${v_exit_status_fn_get_host_record} -ne 0 ]]
	then
		return ${v_exit_status_fn_get_host_record}
	fi

	v_host_record_exist=$(sudo grep "^$v_host_record " $v_fw_zone)
	v_current_ip_of_host_record=$(sudo grep "^$v_host_record " $v_fw_zone | cut -d "A" -f 2 | tr -d '[[:space:]]')

	fn_set_ptr_zone

	v_target_length=39
	v_num_spaces=$(( v_target_length - ${#v_rename_record} ))
	v_host_record_rename="${v_rename_record}$(printf '%*s' "$v_num_spaces")"
	v_host_record_rename=$(echo "$v_host_record_rename IN A ${v_current_ip_of_host_record}")
	
	while :
	do
		read -p "Please confirm to rename the record ${v_host_record} to ${v_rename_record} (y/n) : " v_confirmation
		if [[ $v_confirmation == "y" ]]
		then

			sudo sed -i "s/${v_host_record_exist}/${v_host_record_rename}/g" ${v_fw_zone}
			sudo sed -i "s/${v_host_record}.ms.local./${v_rename_record}.ms.local./g" ${v_ptr_zone}
			echo -e "\nRenamed A and PTR records of ${v_host_record} in ${v_fw_zone} and ${v_ptr_zone} to ${v_rename_record}.\n"

			fn_update_serial_number_of_zones

			if ${v_if_autorun_false}
			then
				fn_reload_named_dns_service
			fi

			break

		elif [[ $v_confirmation == "n" ]]
		then
			echo -e "\nCancelled without any changes !\n"
			break

		else
			echo -e "\nSelect only either (y/n) !\n"
			continue

		fi
	done
}

fn_handle_multiple_host_record() {		

	v_host_list_file="${1}"
	v_action_required="${2}"

	clear

	fn_progress_title() {
	
		if [[ ${v_action_required} == "create" ]]
		then
			echo -e "#############################(DNS-MultiMaker)##############################"

		elif [[ ${v_action_required} == "delete" ]]
		then
			echo -e "###########################(DNS-MultiDestroyer)############################"
		fi
	}

	fn_progress_title
	
	rm -f /tmp/tmp_ptr_zone*
	
	if [ -z "${v_host_list_file}" ]
	then
		echo
		echo -ne "${v_CYAN}Name of the file containing the list of host records to ${v_action_required} : ${v_RESET}" 
		read -e v_host_list_file
	fi
	
	if [[ ! -f ${v_host_list_file} ]];then echo -e "\n${v_RED}File \"${v_host_list_file}\" doesn't exist!${v_RESET}\n";exit;fi 
	
	if [[ ! -s ${v_host_list_file} ]];then echo -e "\n${v_RED}File \"${v_host_list_file}\" is emty!${v_RESET}\n";exit;fi
	
	sed -i '/^[[:space:]]*$/d' ${v_host_list_file}
	
	sed -i 's/.ms.local.//g' ${v_host_list_file}
	
	sed -i 's/.ms.local//g' ${v_host_list_file}
	
	
	while :
	do
		echo -e "\n${v_CYAN}Records to be  ${v_action_required^}d : ${v_RESET}\n"
	
		cat ${v_host_list_file}
	
		echo -ne "\n${v_YELLOW}Provide your confirmation to ${v_action_required} the above host records (y/n) : ${v_RESET}"
		
		read v_confirmation
	
		if [[ ${v_confirmation} == "y" ]]
		then
			break
	
		elif [[ ${v_confirmation} == "n" ]]
		then
			echo -e "\n${v_RED}Cancelled without any changes !!${v_RESET}\n"
			exit
		else
			echo -e "\n${v_RED}Select either (y/n) only !${v_RESET}\n"
			continue
		fi
	done
	
	> "${v_tmp_file_dnsmanager}"
	
	v_successefull="${v_GREEN}[ succeded ]${v_RESET}"
	v_failed="${v_RED}[ failed ]${v_RESET}"
	
	v_pre_execution_serial_fw_zone=$(sudo grep ';Serial' ${v_fw_zone} | cut -d ";" -f 1 | tr -d '[:space:]')
	
	v_total_host_records=$(wc -l < "${v_host_list_file}")
	
	v_host_count=0
	
	while read -r v_host_record
	do
		clear

		fn_progress_title
	
		if [[ ${v_host_count} -le ${v_total_host_records} ]];then
	
			echo -e "################################( Running )################################"

			echo -ne "\n${v_GREEN}Status : [ ${v_host_count}/${v_total_host_records} ] host records are being processed${v_RESET}"
		fi
	
		let v_host_count++
	
		echo -ne "\n\n${v_CYAN}Attempting to ${v_action_required} the host record ${v_host_record}.ms.local . . . ${v_RESET}"
	
		v_serial_fw_zone_pre_execution=$(sudo grep ';Serial' ${v_fw_zone} | cut -d ";" -f 1 | tr -d '[:space:]')
	
		if [[ ${v_action_required} == "create" ]]
                then
			fn_create_host_record "${v_host_record}" "Automated-Execution"
			var_exit_status=${?}

		elif [[ ${v_action_required} == "delete" ]]
		then
			fn_delete_host_record "${v_host_record}" -y "Automated-Execution"
			var_exit_status=${?}
		fi
	
		v_serial_fw_zone_post_execution=$(sudo grep ';Serial' ${v_fw_zone} | cut -d ";" -f 1 | tr -d '[:space:]')
	
	        v_fqdn="${v_host_record}.ms.local"
	
	        
		if [[ ${v_action_required} == "create" ]]
		then
			v_ip_address=$(sudo grep -w "^${v_host_record} "  "${v_fw_zone}" | awk '{print $NF}' | tr -d '[:space:]')
	
			if [[ -z "${v_ip_address}" ]]; then
	        		v_ip_address="N/A"
	    		fi
		fi
	
		if [[ ${v_action_required} == "create" ]]
		then
			v_details_of_host_record="${v_fqdn} ( ${v_ip_address} )${v_RESET}"

		elif [[ ${v_action_required} == "delete" ]]
		then
			v_details_of_host_record="${v_fqdn}${v_RESET}"
		fi
			
		if [[ ${var_exit_status} -eq 9 ]]
		then
	        	echo -e "${v_RED}Invalid-Host     ${v_details_of_host_record}" >> "${v_tmp_file_dnsmanager}" && echo -ne "${v_failed}" 
	
		elif [[ ${var_exit_status} -eq 8 ]]
		then
			if [[ ${v_action_required} == "create" ]]
                	then
				v_existence_state="Already-Exists  "

			elif [[ ${v_action_required} == "delete" ]]
			then
				v_existence_state="Doesn't-Exist   "
			fi

	        	echo -e "${v_YELLOW}${v_existence_state} ${v_details_of_host_record}" >> "${v_tmp_file_dnsmanager}" && echo -ne "${v_failed}"
	
		elif [[ ${var_exit_status} -eq 255 ]]
		then
	        	echo -e "${v_RED}IP-Exhausted     ${v_details_of_host_record}" >> "${v_tmp_file_dnsmanager}" && echo -ne "${v_failed}"
		else
			v_serial_fw_zone_post_execution=$(sudo grep ';Serial' ${v_fw_zone} | cut -d ";" -f 1 | tr -d '[:space:]')
	
			if [[ "${v_serial_fw_zone_pre_execution}" -ne "${v_serial_fw_zone_post_execution}" ]]
			then
				echo -e "${v_GREEN}${v_action_required^}d          ${v_details_of_host_record}" >> "${v_tmp_file_dnsmanager}" && echo -ne "${v_successefull}"
			else
	        		echo -e "${v_RED}Failed-to-${v_action_required^} ${v_details_of_host_record}" >> "${v_tmp_file_dnsmanager}" && echo -ne "${v_failed}"
			fi
		fi
	
		if [[ ${v_host_count} -eq ${v_total_host_records} ]];then
	
			clear
			fn_progress_title
			echo -e "################################( Completed )##############################\n"
			echo -ne "${v_GREEN}Status : [ ${v_host_count}/${v_total_host_records} ] host records have been processed${v_RESET}"
		fi
	
	
	done < "${v_host_list_file}"

	v_post_execution_serial_fw_zone=$(sudo grep ';Serial' ${v_fw_zone} | cut -d ";" -f 1 | tr -d '[:space:]')
	
	if [[ "${v_pre_execution_serial_fw_zone}" -ne "${v_post_execution_serial_fw_zone}" ]]
	then
		echo -e "\n\n${v_YELLOW}Reloading the DNS service ( named ) for the changes to take effect . . .${v_RESET}\n"
	
		sudo systemctl reload named &>/dev/null
	
		if sudo systemctl is-active named &>/dev/null;
		then 
			echo -e "${v_GREEN}Reloaded, service  named is active and running. ${v_RESET}"
		else
			echo -e "\n${v_RED}Something went wrong !\nService named is not running !\nPlease troubleshoot manually${v_RESET}\n"
		fi
	else
		echo -e "\n\n${v_YELLOW}No changes done! Nothing to do!${v_RESET}"
	fi
		
	echo -e "\n${v_YELLOW}Please find the below details of the records :\n${v_RESET}"

	if [[ ${v_action_required} == "create" ]]
	then
		echo -e "${v_CYAN}Action-Taken     FQDN ( IPv4-Address )${v_RESET}"

	elif [[ ${v_action_required} == "delete" ]]
	then
		echo -e "${v_CYAN}Action-Taken     FQDN${v_RESET}"
	fi
	
	cat "${v_tmp_file_dnsmanager}"
	
	echo
	
	rm -f "${v_tmp_file_dnsmanager}"
	rm -f /tmp/tmp_ptr_zone*
}

fn_main_menu() {
cat << EOF
Manage DNS host records with ms.local domain,
1) Create a DNS host record
2) Delete a DNS host record
3) Rename an existing DNS host record
4) Create multiple DNS host records provided in a file
5) Delete multiple DNS host records provided in a file
q) Quit without any changes

EOF

read -p "Please Select an Option from Above : " var_function

case ${var_function} in
	1)
		fn_create_host_record
		exit
		;;
	2)
		fn_delete_host_record
		exit
		;;
	3)
		fn_rename_host_record
		exit
		;;
	4)
		fn_handle_multiple_host_record "${2}" "create"
		exit
		;;
	5)
		fn_handle_multiple_host_record "${2}" "delete"
		exit
		;;
	q)
		exit
		;;
	*)
		echo -e "\nInvalid Option! Try Again! \n"
		fn_main_menu
		;;
esac

}

if [ ! -z "${1}" ]
then
	case "${1}" in
		-c)
			fn_create_host_record "${2}"
			exit
			;;
		-d)
			fn_delete_host_record "${2}"
			exit
			;;
		-r)
			fn_rename_host_record "${2}"
			exit
			;;
		-cf)
			fn_handle_multiple_host_record "${2}" "create"
			exit
			;;
		-df)
			fn_handle_multiple_host_record "${2}" "delete"
			exit
			;;
		*)
			if [[ ! "${1}" =~ ^-h|--help$ ]]
			then
				echo "Invalid Option \"${1}\"!"
			fi

			cat << EOF
Usage: dnsmanager [ option ] [ DNS host record ]
Use one of the following Options :
	-c 	To create a DNS host record
	-d 	To delete a DNS host record
	-r 	To rename an existing DNS host record
	-cf 	To create multiple DNS host records provided in a file 
	-df	To delete multiple DNS host records provided in a file
[ Or ]
Run dnsmanager utility without any arguements to get menu driven actions.

EOF
			;;
	esac
else
	fn_main_menu
fi
