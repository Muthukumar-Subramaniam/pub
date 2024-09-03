#!/bin/bash
v_zone_dir='/var/named'
v_fw_zone="${v_zone_dir}/ms.local-forward.db"
v_ptr_zone_prod="${v_zone_dir}/192.168.168.ms.local-reverse.db"
v_ptr_zone_test="${v_zone_dir}/10.10.10.ms.local-reverse.db"
v_ptr_zone_dev="${v_zone_dir}/172.16.16.ms.local-reverse.db"

if [[ "$(id -u)" -ne 0 ]]
then
	echo -e "\nPlease run this script as root or using sudo ! \n"
	exit
fi

f_update_dns_records() {
	v_set_record=${1}
	v_set_fw_zone=${2}
	v_ptr_zone=${3}

	if echo ${v_ptr_zone} | grep 192.168.168 &>/dev/null
	then
		v_network='Prod Network ( 192.168.168.0/24 )'
		v_net_part='192.168.168'

	elif echo ${v_ptr_zone} | grep 10.10.10 &>/dev/null
	then
		v_network='Test Network ( 10.10.10.0/24 )'
		v_net_part='10.10.10'

	elif echo ${v_ptr_zone} | grep 172.16.16 &>/dev/null
	then
		v_network='Dev Network ( 172.16.16.0/24 )'
		v_net_part='172.16.16'
	fi


	echo -e "\nLooking for available IPs in ${v_network} . . .\n"

	for v_num_ptr in $( seq 2 255 )    #<---Starting first IP from 2 to ignore Gateway IP 1
	do

		if grep "^${v_num_ptr} " ${v_ptr_zone} &>/dev/null     #<---Checking whether the IP already exists 
		then
			continue

		#elif [[ ${v_num_ptr} -ge 213 && ${v_num_ptr} -le 233 ]]   #<---Reserved for VMware Workstation DHCP Server
		#then
		#	continue

		elif [[ ${v_num_ptr} -ge 234 && ${v_num_ptr} -le 254 ]]   #<---Reserved for DHCP server from muthuks-server
		then
			continue

		else
			v_ptr_ip=${v_num_ptr}                               #<--Capturing found free IP
			v_ptr_prev=$(( v_num_ptr - 1 ))                   #<--Capturing existing previous IP 
			if [[ ${v_ptr_ip} -ge 255 ]]                        #<--Checking if max limit exceeded
			then
				echo -e "\nNo more free IPs available in selected ${v_network}! "
				#echo -e "\nNote : IPs from ${v_net_part}.213 to ${v_net_part}.233 are reserved.\n(VMware Workstation DHCP Server)" 
				echo -e "\nNote : IPs from ${v_net_part}.234 to ${v_net_part}.254 are reserved.\n(DHCP server from muthuks-server)\n" 
				exit
			fi
			break
		fi
	done

	############### A Record Updating Section ############################

  	v_target_length=39
        v_num_spaces=$(( v_target_length - ${#v_set_record} ))
  	v_set_record_adjusted_space="${v_set_record}$(printf '%*s' "${v_num_spaces}")"

	echo -e "\nUpdating A Record . . .\n"

  	v_ptr_prv_ip="${v_net_part}.${v_ptr_prev}"
	v_ptr_current_ip="${v_net_part}.${v_ptr_ip}"
	v_add_a_record=$(echo "${v_set_record_adjusted_space} IN A ${v_ptr_current_ip}")
	sed -i "/${v_ptr_prv_ip}$/a \\${v_add_a_record}" ${v_set_fw_zone}

	v_current_serial_ptr_zone=$(grep ';Serial' ${v_set_fw_zone} | cut -d ";" -f 1 | tr -d '[:space:]')
	v_set_new_serial__ptr_zone=$(( v_current_serial_ptr_zone + 1 ))
	sed -i "/;Serial/s/${v_current_serial_ptr_zone}/${v_set_new_serial__ptr_zone}/g" ${v_set_fw_zone}

	##################  End of  A Record Updating Section ############################



	################## PTR Record Updating  Section ###################################
	echo -e "\nUpdating PTR Record . . .\n"


	# Checking number of digits in the IP
	if [[ ${#v_ptr_ip} -eq 1 ]]
	then
  		v_digits=1

	elif [[ ${#v_ptr_ip} -eq 2 ]]
	then
  		v_digits=2

	elif [[ ${#v_ptr_ip} -eq 3 ]]
	then
  		v_digits=3
	fi


	if [[ ${v_digits} -eq 1 ]]
	then
		v_add_ptr_record=$(echo "${v_ptr_ip}   IN PTR ${v_set_record}.ms.local.")
		sed -i "/^${v_ptr_prev} /a\\${v_add_ptr_record}" ${v_ptr_zone}
	elif [[ ${v_digits} -eq 2 ]]
	then
		v_add_ptr_record=$(echo "${v_ptr_ip}  IN PTR ${v_set_record}.ms.local.")
		sed -i "/^${v_ptr_prev} /a\\${v_add_ptr_record}" ${v_ptr_zone}
	elif [[ ${v_digits} -eq 3 ]]
	then
		v_add_ptr_record=$(echo "${v_ptr_ip} IN PTR ${v_set_record}.ms.local.")
		sed -i "/^${v_ptr_prev} /a\\${v_add_ptr_record}" ${v_ptr_zone}
	fi

	v_current_serial_ptr_zone=$(grep ';Serial' ${v_ptr_zone} | cut -d ";" -f 1 | tr -d '[:space:]')
	v_set_new_serial__ptr_zone=$(( v_current_serial_ptr_zone + 1 ))
	sed -i "/;Serial/s/${v_current_serial_ptr_zone}/${v_set_new_serial__ptr_zone}/g" ${v_ptr_zone}

	############# End of PTR Record Updating Section #######################

	echo -e "\nReloading the DNS service ( named ) . . .\n"

	systemctl reload named &>/dev/null

	if systemctl is-active named &>/dev/null;
	then 
		echo "Reloaded, service  named is active and running ."
	else
		echo -e "\nSomething went wrong !\nService named is not running !\nPlease troubleshoot manually\n"
	fi
        
	echo -e "\nSuccessfully created DNS records for \"${v_set_record}\"\n"
	
	echo -e "\nForward Look Up ...\n"

	nslookup ${v_set_record} | grep -A 1 ^Name 
	
	echo -e "\nReverse Look Up ...\n"

	nslookup ${v_ptr_current_ip} 
}


f_main_menu() {
	v_input_host=${1}
	v_input_network=${2}
	echo -e "\n<< This script provitions fqdn from ms.local domain >>\n\nNote: A and PTR record updates are done automatically\n"
	
	f_get_a_record() {
		v_input_host=${1}
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

		if grep -w "${v_a_record} "  ${v_fw_zone}
		then 
			echo -e "\nA Record for \"${v_a_record}\" already exists in \"${v_fw_zone}\"\n"
			exit
		fi
	}
	
	f_get_network() {
		v_input_network=${1}
		if [[ ! -z ${v_input_network} ]]
		then 
			v_network=${1}
			if [[ ! ${v_network} =~ ^(1|2|3)$ ]]
			then
				echo -e "\n2nd command line parameter provided for notwork selection is not valid.\n"
				echo -e "FYI : The value should be 1, 2 or 3."
				echo -e "1) Prod Network ( 192.168.168.0/24 )"
        			echo -e "2) Test Network ( 10.10.10.0/24 )"
        			echo -e "3) Dev  Network ( 172.16.16.0/24 )\n"
				exit
			fi
		else
        		echo -e "Select the Network :\n"
        		echo -e "1) Prod Network ( 192.168.168.0/24)"
        		echo -e "2) Test Network ( 10.10.10.0/24)"
        		echo -e "3) Dev  Network ( 172.16.16.0/24)"
			echo -e "a) Go back to setting A Record"
        		echo -e "q) Exit the script without any changes\n"
        		read -p "Choose Option Number : " v_network
		fi

        	case ${v_network} in
                	1 ) f_update_dns_records "${v_a_record}" "${v_fw_zone}" "${v_ptr_zone_prod}"
                	;;

                	2 ) f_update_dns_records "${v_a_record}" "${v_fw_zone}" "${v_ptr_zone_test}"
                	;;

                	3 ) f_update_dns_records "${v_a_record}" "${v_fw_zone}" "${v_ptr_zone_dev}"
                	;;

			a) f_get_a_record 
		           f_get_network
			;;

               		q ) echo -e "\nExiting without any changes !\n"
                    	exit
                	;;

                	* ) echo -e "\nEntered Option is Wrong !!!\n"
                    	read -p"Press Enter to go back to main menu <ENTER>"
                    	f_get_network
                	;;
        	esac
	}
	
	f_get_a_record "${v_input_host}"
	f_get_network "${v_input_network}"
}

f_main_menu "${1}" "${2}"

exit
