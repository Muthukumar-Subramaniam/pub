#!/bin/bash
v_zone_dir='/var/named/zone-files'
v_fw_zone="$v_zone_dir/ms.local-forward.db"
v_ptr_zone1="${v_zone_dir}/192.168.168.ms.local-reverse.db"
v_ptr_zone2="${v_zone_dir}/192.168.169.ms.local-reverse.db"
v_ptr_zone3="${v_zone_dir}/192.168.170.ms.local-reverse.db"
v_ptr_zone4="${v_zone_dir}/192.168.171.ms.local-reverse.db"

if ! sudo -l | grep NOPASSWD &> /dev/null
then
	echo -e "\nYou need sudo access without password to run this script ! \n"
	exit
fi

fn_get_existing_record() {
	echo -e "\n<< This script modifies fqdn in ms.local domain >>\n\nNote: Both A and PTR record will be modified automatically\n"
	
	while :
	do
		echo -e "\nPlease use only letters, numbers, and hyphens.\n (Please do not start with a number)."
		echo -e "No need to append the domain name ms.local\n"
		read -p "Please Enter the hostname to be modified : " v_existing_record
		if [[ $v_existing_record =~ ^[[:alpha:]]([-[:alnum:]]*)$ ]]
	       	then
    			break
  		else
    			echo -e "Invalid name!\nPlease use only letters, numbers, and hyphens.\n (cannot start with a number).\n"
  		fi
	done

	if ! sudo grep "^$v_existing_record "  $v_fw_zone
        then
                echo -e "\nA Record for \"$v_existing_record\" not found in \"$v_fw_zone\"\n"
                echo -e "Nothing to do ! Exiting !\n"
                exit
        fi

	
	while :
	do
		echo -e "\nPlease use only letters, numbers, and hyphens.\n (Please do not start with a number)."
		echo -e "No need to append the domain name ms.local\n"
		read -p "Please Enter the hostname to replace \"$v_existing_record\" : " v_modify_record
		if [[ $v_modify_record =~ ^[[:alpha:]]([-[:alnum:]]*)$ ]]
	       	then
    			break
  		else
    			echo -e "Invalid name!\nPlease use only letters, numbers, and hyphens.\n (cannot start with a number).\n"
  		fi
	done

	if sudo grep  "^$v_modify_record "  $v_fw_zone
	then 
		echo -e "\nConflict : Existing A Record found for \"$v_modify_record\" in  \"$v_fw_zone\"\n"
		echo -e "Nothing to do ! Exiting !\n"
		exit
	fi
}



f_rename_records() {

	v_ptr_zone="${1}"

	while :
	do
		read -p "Please confirm to rename the record ${v_existing_record} to ${v_modify_record} (y/n) : " v_confirmation
		if [[ $v_confirmation == "y" ]]
		then

			sudo sed -i "s/${v_a_record_exist}/${v_a_record_modify}/g" ${v_fw_zone}
			sudo sed -i "s/${v_existing_record}.ms.local./${v_modify_record}.ms.local./g" ${v_ptr_zone}
			echo -e "\nRenamed A and PTR records of ${v_existing_record} in ${v_fw_zone} and ${v_ptr_zone} to ${v_modify_record}.\n"

			echo -e "\nUpdating Serial Numbers of zone files . ..\n"
			
			v_current_serial_ptr_zone=$(sudo grep ';Serial' ${v_fw_zone} | cut -d ";" -f 1 | tr -d '[:space:]')
        		v_set_new_serial__ptr_zone=$(( v_current_serial_ptr_zone + 1 ))
        		sudo sed -i "/;Serial/s/$v_current_serial_ptr_zone/$v_set_new_serial__ptr_zone/g" ${v_fw_zone}

			v_current_serial_ptr_zone=$(sudo grep ';Serial' ${v_ptr_zone} | cut -d ";" -f 1 | tr -d '[:space:]')
        		v_set_new_serial__ptr_zone=$(( v_current_serial_ptr_zone + 1 ))
        		sudo sed -i "/;Serial/s/$v_current_serial_ptr_zone/$v_set_new_serial__ptr_zone/g" ${v_ptr_zone}


			echo -e "\nReloading the DNS service ( named ) . . .\n"

        		sudo systemctl reload named &>/dev/null

        		if sudo systemctl is-active named &>/dev/null;
        		then
                		echo "Reloaded, service  named is active and running ."
        		else
                		echo -e "\nSomething went wrong !\n\
				Service named is not running !\nPlease troubleshoot manually\n"
        		fi

        		echo -e "\nSuccessfully renamed DNS record of \"${v_existing_record}\" to \"${v_modify_record}\" \n"

			echo -e "Forward Lookup :\n"

			nslookup ${v_modify_record} | grep ^Name -A 1

			echo -e "\nReverse Lookup :\n"

			nslookup ${v_capture_a_record_ip}

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

fn_get_existing_record

v_a_record_exist=$(sudo grep "^$v_existing_record " $v_fw_zone)
v_capture_a_record_ip=$(sudo grep "^$v_existing_record " $v_fw_zone | cut -d "A" -f 2 | tr -d '[[:space:]]')

v_target_length=39
v_num_spaces=$(( v_target_length - ${#v_modify_record} ))
v_a_record_modify="${v_modify_record}$(printf '%*s' "$v_num_spaces")"
v_a_record_modify=$(echo "$v_a_record_modify IN A ${v_capture_a_record_ip}")


if echo ${v_capture_a_record_ip} | grep '192.168.168'
then
	echo -e "\nMatch found with IP ${v_capture_a_record_ip} for ${v_existing_record}.\n"
	f_rename_records "${v_ptr_zone1}"

elif echo ${v_capture_a_record_ip} | grep '192.168.169'
then
	echo -e "\nMatch found with IP ${v_capture_a_record_ip} for $v_existing_record.\n"
	f_rename_records "${v_ptr_zone2}"

elif echo ${v_capture_a_record_ip} | grep '192.168.170'
then
	echo -e "\nMatch found with IP ${v_capture_a_record_ip} for $v_existing_record.\n"
	f_rename_records "${v_ptr_zone3}"

elif echo ${v_capture_a_record_ip} | grep '192.168.171'
then
	echo -e "\nMatch found with IP ${v_capture_a_record_ip} for $v_existing_record.\n"
	f_rename_records "${v_ptr_zone4}"
fi

exit
