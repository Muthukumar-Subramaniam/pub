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
	for v_num_ptr in $( seq 0 255 )  
	do
		if sudo grep "^${v_num_ptr} " "${v_ptr_zone4}" &>/dev/null     #<---Checking whether the IP already exists 
		then
			continue
		else
			if [[ "${v_num_ptr}" -eq 255 ]]                        #<--Checking if max limit exceeded in zone4
			then
				echo "\nNo more IPs available in 192.168.168.0/22 Network of ms.local domain! \n"
				exit
			else
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

				break
			fi
		fi
	done
}	

fn_check_free_ip_in_ptr_zone3() {
	for v_num_ptr in $( seq 0 256 )  
	do
		if sudo grep "^${v_num_ptr} " "${v_ptr_zone3}" &>/dev/null     #<---Checking whether the IP already exists 
		then
			continue
		else
			if [[ "${v_num_ptr}" -eq 256 ]]                        #<--Checking if max limit exceeded in zone3
			then
				fn_check_free_ip_in_ptr_zone4
				break
			else
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

				break
			fi

		fi
	done
}	

fn_check_free_ip_in_ptr_zone2() {
	for v_num_ptr in $( seq 0 256 ) 
	do
		if sudo grep "^${v_num_ptr} " "${v_ptr_zone2}" &>/dev/null     #<---Checking whether the IP already exists 
		then
			continue
		else
			if [[ "${v_num_ptr}" -eq 256 ]]                        #<--Checking if max limit exceeded in zone2
			then
				fn_check_free_ip_in_ptr_zone3
				break
			else
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

				break
			fi
		fi
	done
}	

fn_check_free_ip_in_ptr_zone1() {
	for v_num_ptr in $( seq 2 256 )    #<---Starting first IP from 2 to ignore Gateway IP 1
	do
		if sudo grep "^${v_num_ptr} " "${v_ptr_zone1}" &>/dev/null     #<---Checking whether the IP already exists 
		then
			continue
		else
			if [[ "${v_num_ptr}" -eq 256 ]]                        #<--Checking if max limit exceeded in zone1
			then
				fn_check_free_ip_in_ptr_zone2
				break
			else
				v_ptr_ip="${v_num_ptr}"                           #<--Capturing found free IP
				v_ptr_prev=$(( v_num_ptr - 1 ))                   #<--Capturing existing previous IP 
  				v_ptr_prv_ip="192.168.168.${v_ptr_prev}"
				v_ptr_current_ip="192.168.168.${v_ptr_ip}"
				v_ptr_zone="${v_ptr_zone1}"
				break
			fi
		fi
	done
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
	echo -e "\n<< This script provitions fqdn from ms.local domain >>\n\nNote: A and PTR record updates are done automatically\n"
	v_input_host="${1}"
	if [[ ! -z ${v_input_host} ]]
	then
                v_a_record=${1}
		if [[ ! ${v_a_record} =~ ^[[:alpha:]]([-[:alnum:]]*)$ ]]
		then
                        echo -e "1st command line parameter provided is invalid!\n"
			echo -e "Please use only letters, numbers, and hyphens.\n (cannot start with a number).\n"
			exit
		fi

	else
		while :
		do
			echo -e "\nPlease use only letters, numbers, and hyphens.\n (Please do not start with a number)."
			echo -e "No need to append the domain name ms.local\n"

			read -p "Please Enter the required hostname : " v_a_record

			if [[ ${v_a_record} =~ ^[[:alpha:]]([-[:alnum:]]*)$ ]]
	       		then
    				break
  			else
    				echo -e "Invalid name!\nPlease use only letters, numbers, and hyphens.\n (cannot start with a number).\n"
  			fi
		done
	fi

	if sudo grep -w "${v_a_record} "  ${v_fw_zone}
	then 
		echo -e "\nA Record for \"${v_a_record}\" already exists in \"${v_fw_zone}\"\n"
		exit
	fi
}
	
	
f_get_a_record "${1}"

echo -e "\nLooking for available IPs in Network 192.168.168.0/22 . . .\n"

fn_check_free_ip_in_ptr_zone1

f_update_dns_records

exit
