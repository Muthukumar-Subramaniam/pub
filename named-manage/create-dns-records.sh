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

fn_check_free_ip_in_ptr_zone4() {

#	v_existing_ips_ptr_zone4=$(sudo sed -n 's/^\([0-9]\+\).*/\1/p' "${v_ptr_zone4}")

	while IFS= read -r ip
	do
        	v_existing_ips_ptr_zone4["$ip"]=1
	done < <(sudo sed -n 's/^\([0-9]\+\).*/\1/p' "${v_ptr_zone4}")

	for ((v_num_ptr = 0; v_num_ptr <= 254; v_num_ptr++))
	do
#		if ! printf '%s\n' "${v_existing_ips_ptr_zone4}" | grep -qw "${v_num_ptr}"
		if [[ -z "${v_existing_ips_ptr_zone4[$v_num_ptr]}" ]]
		then
			v_ptr_ip="${v_num_ptr}"

			if [[ "${v_ptr_ip}" -eq 0 ]]
			then
				v_ptr_prev=';PTR-Records'
			else
				v_ptr_prev=$(( v_num_ptr - 1 ))                   #<--Capturing existing previous IP 
			fi

			if [[ "${v_ptr_prev}" == ';PTR-Records' ]]
			then
				v_ptr_prv_ip=';PTR-Records'
			else
				v_ptr_prv_ip="192.168.171.${v_ptr_prev}"
			fi

			v_ptr_current_ip="192.168.171.${v_ptr_ip}"
			v_ptr_zone="${v_ptr_zone4}"

			return 0
		fi
	done

	return 1
}	


fn_check_free_ip_in_ptr_zone3() {

#	v_existing_ips_ptr_zone3=$(sudo sed -n 's/^\([0-9]\+\).*/\1/p' "${v_ptr_zone3}")

	while IFS= read -r ip
	do
        	v_existing_ips_ptr_zone3["$ip"]=1
	done < <(sudo sed -n 's/^\([0-9]\+\).*/\1/p' "${v_ptr_zone3}")

	for ((v_num_ptr = 0; v_num_ptr <= 255; v_num_ptr++))
	do
	#	if ! printf '%s\n' "${v_existing_ips_ptr_zone3}" | grep -qw "${v_num_ptr}"
		if [[ -z "${v_existing_ips_ptr_zone3[$v_num_ptr]}" ]]
		then
			v_ptr_ip="${v_num_ptr}"

			if [[ "${v_ptr_ip}" -eq 0 ]]
			then
				v_ptr_prev=';PTR-Records'
			else
				v_ptr_prev=$(( v_num_ptr - 1 ))                   #<--Capturing existing previous IP 
			fi

			if [[ "${v_ptr_prev}" == ';PTR-Records' ]]
			then
				v_ptr_prv_ip=';PTR-Records'
			else
				v_ptr_prv_ip="192.168.170.${v_ptr_prev}"
			fi

			v_ptr_current_ip="192.168.170.${v_ptr_ip}"
			v_ptr_zone="${v_ptr_zone3}"

			return 0
		fi
	done

	return 1
}	


fn_check_free_ip_in_ptr_zone2() {

	#v_existing_ips_ptr_zone2=$(sudo sed -n 's/^\([0-9]\+\).*/\1/p' "${v_ptr_zone2}")
	while IFS= read -r ip
	do
        	v_existing_ips_ptr_zone2["$ip"]=1
	done < <(sudo sed -n 's/^\([0-9]\+\).*/\1/p' "${v_ptr_zone2}")

	for ((v_num_ptr = 0; v_num_ptr <= 255; v_num_ptr++))
	do
		#if ! printf '%s\n' "${v_existing_ips_ptr_zone2}" | grep -qw "${v_num_ptr}"
		if [[ -z "${v_existing_ips_ptr_zone2[$v_num_ptr]}" ]]
		then

			v_ptr_ip="${v_num_ptr}"

			if [[ "${v_ptr_ip}" -eq 0 ]]
			then
				v_ptr_prev=';PTR-Records'
			else
				v_ptr_prev=$(( v_num_ptr - 1 ))                   #<--Capturing existing previous IP 
			fi

			if [[ "${v_ptr_prev}" == ';PTR-Records' ]]
			then
				v_ptr_prv_ip=';PTR-Records'
			else
				v_ptr_prv_ip="192.168.169.${v_ptr_prev}"
			fi

			v_ptr_current_ip="192.168.169.${v_ptr_ip}"
			v_ptr_zone="${v_ptr_zone2}"

			return 0
		fi
	done

	return 1
}	



fn_check_free_ip_in_ptr_zone1() {

#	v_existing_ips_ptr_zone1=$(sudo sed -n 's/^\([0-9]\+\).*/\1/p' "${v_ptr_zone1}")
	while IFS= read -r ip
	do
        	v_existing_ips_ptr_zone1["$ip"]=1
	done < <(sudo sed -n 's/^\([0-9]\+\).*/\1/p' "${v_ptr_zone1}")

	for ((v_num_ptr = 2; v_num_ptr <= 255; v_num_ptr++))
	do
		#if ! printf '%s\n' "${v_existing_ips_ptr_zone1}" | grep -qw "${v_num_ptr}"
		if [[ -z "${v_existing_ips_ptr_zone1[$v_num_ptr]}" ]]
		then
			v_ptr_ip="${v_num_ptr}"                           #<--Capturing found free IP
			v_ptr_prev=$(( v_num_ptr - 1 ))                   #<--Capturing existing previous IP 
  			v_ptr_prv_ip="192.168.168.${v_ptr_prev}"
			v_ptr_current_ip="192.168.168.${v_ptr_ip}"
			v_ptr_zone="${v_ptr_zone1}"
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

	echo -e "\nUpdating A Record . . .\n"


	v_add_a_record=$(echo "${v_a_record_adjusted_space} IN A ${v_ptr_current_ip}")

	if [[ "${v_ptr_prv_ip}" == ';PTR-Records' ]]
	then
		echo "${v_add_a_record}" | sudo tee -a "${v_fw_zone}"
	else
		sudo sed -i "/${v_ptr_prv_ip}$/a \\${v_add_a_record}" "${v_fw_zone}"
	fi

	v_current_serial_ptr_zone=$(sudo grep ';Serial' ${v_fw_zone} | cut -d ";" -f 1 | tr -d '[:space:]')
	v_set_new_serial__ptr_zone=$(( v_current_serial_ptr_zone + 1 ))
	sudo sed -i "/;Serial/s/${v_current_serial_ptr_zone}/${v_set_new_serial__ptr_zone}/g" "${v_fw_zone}"

	##################  End of  A Record Updating Section ############################



	################## PTR Record Updating  Section ###################################
	echo -e "\nUpdating PTR Record . . .\n"


	# Checking number of digits in the IP
	if [[ "${#v_ptr_ip}" -eq 1 ]]
	then
  		v_digits=1

	elif [[ "${#v_ptr_ip}" -eq 2 ]]
	then
  		v_digits=2

	elif [[ "${#v_ptr_ip}" -eq 3 ]]
	then
  		v_digits=3
	fi


	if [[ "${v_digits}" -eq 1 ]]
	then
		v_add_ptr_record=$(echo "${v_ptr_ip}   IN PTR ${v_a_record}.ms.local.")
		if [[ "${v_ptr_prev}" == ';PTR-Records' ]]
		then
			echo "${v_add_ptr_record}" | sudo tee -a "${v_ptr_zone}"
		else
			sudo sed -i "/^${v_ptr_prev} /a\\${v_add_ptr_record}" "${v_ptr_zone}"
		fi
	elif [[ "${v_digits}" -eq 2 ]]
	then
		v_add_ptr_record=$(echo "${v_ptr_ip}  IN PTR ${v_a_record}.ms.local.")
		if [[ "${v_ptr_prev}" == ';PTR-Records' ]]
		then
			echo "${v_add_ptr_record}" | sudo tee "${v_ptr_zone}"
		else
			sudo sed -i "/^${v_ptr_prev} /a\\${v_add_ptr_record}" "${v_ptr_zone}"
		fi
	elif [[ "${v_digits}" -eq 3 ]]
	then
		v_add_ptr_record=$(echo "${v_ptr_ip} IN PTR ${v_a_record}.ms.local.")
		if [[ "${v_ptr_prev}" == ';PTR-Records' ]]
		then
			echo "${v_add_ptr_record}" | sudo tee "${v_ptr_zone}"
		else
			sudo sed -i "/^${v_ptr_prev} /a\\${v_add_ptr_record}" "${v_ptr_zone}"
		fi
	fi

	v_current_serial_ptr_zone=$(sudo grep ';Serial' "${v_ptr_zone}" | cut -d ";" -f 1 | tr -d '[:space:]')
	v_set_new_serial__ptr_zone=$(( v_current_serial_ptr_zone + 1 ))
	sudo sed -i "/;Serial/s/${v_current_serial_ptr_zone}/${v_set_new_serial__ptr_zone}/g" "${v_ptr_zone}"

	############# End of PTR Record Updating Section #######################

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

	nslookup ${v_ptr_current_ip} 
}


	
f_get_a_record() {
	v_input_host="${1}"
	if [[ ! -z ${v_input_host} ]]
	then
                v_a_record=${1}
		if [[ ! ${v_a_record} =~ ^[[:alpha:]]([-[:alnum:]]*)$ ]]
		then
                        echo -e "Provided input hostname \"${v_a_record}\" is invalid!\n"
			echo -e "Please use only letters, numbers, and hyphens.\n (cannot start with a number or hyphen).\n"
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

	if sudo grep -w "^${v_a_record} "  ${v_fw_zone}
	then 
		echo -e "\nA Record for \"${v_a_record}\" already exists in \"${v_fw_zone}\"\n"
		exit 8
	fi
}
	
	
f_get_a_record "${1}"

echo -e "\nLooking for available IPs in Network 192.168.168.0/22 . . .\n"

fn_check_free_ip_in_ptr_zone1 || \
fn_check_free_ip_in_ptr_zone2 || \
fn_check_free_ip_in_ptr_zone3 || \
fn_check_free_ip_in_ptr_zone4 || \
{ echo -e "\nNo more IPs available in 192.168.168.0/22 Network of ms.local domain! \n"; exit 255; }

f_update_dns_records

exit
