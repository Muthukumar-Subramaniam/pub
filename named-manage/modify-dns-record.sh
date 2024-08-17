#!/bin/bash
v_zone_dir='/var/named'
v_fw_zone="$v_zone_dir/ms.local-forward.db"
v_ptr_zone_prod="$v_zone_dir/192.168.168.ms.local-reverse.db"
v_ptr_zone_test="$v_zone_dir/10.10.10.ms.local-reverse.db"
v_ptr_zone_dev="$v_zone_dir/172.16.16.ms.local-reverse.db"

f_main_menu() {
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

	if ! grep "^$v_existing_record "  $v_fw_zone
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

	if grep  "^$v_modify_record "  $v_fw_zone
	then 
		echo -e "\nConflict : Existing A Record found for \"$v_modify_record\" in  \"$v_fw_zone\"\n"
		echo -e "Nothing to do ! Exiting !\n"
		exit
	fi
}

f_main_menu

f_rename_records() {
	while :
	do
		read -p "Please confirm to rename the record $1 to $2 (y/n) : " v_confirmation
		if [[ $v_confirmation == "y" ]]
		then

			sed -i "s/$6/$7/g" $3
			sed -i "s/$1.ms.local./$2.ms.local./g" $4
			echo -e "\nRenamed A and PTR records of $1 in $3 and $4 to $2.\n"

			echo -e "\nUpdating Serial Numbers of zone files . ..\n"
			
			v_current_serial_ptr_zone=$(grep ';Serial' $3 | cut -d ";" -f 1 | tr -d '[:space:]')
        		v_set_new_serial__ptr_zone=$(( v_current_serial_ptr_zone + 1 ))
        		sed -i "/;Serial/s/$v_current_serial_ptr_zone/$v_set_new_serial__ptr_zone/g" $3

			v_current_serial_ptr_zone=$(grep ';Serial' $4 | cut -d ";" -f 1 | tr -d '[:space:]')
        		v_set_new_serial__ptr_zone=$(( v_current_serial_ptr_zone + 1 ))
        		sed -i "/;Serial/s/$v_current_serial_ptr_zone/$v_set_new_serial__ptr_zone/g" $4


			echo -e "\nReloading the DNS service ( named ) . . .\n"

        		systemctl reload named &>/dev/null

        		if systemctl is-active named &>/dev/null;
        		then
                		echo "Reloaded, service  named is active and running ."
        		else
                		echo -e "\nSomething went wrong !\n\
				Service named is not running !\nPlease troubleshoot manually\n"
        		fi

        		echo -e "\nSuccessfully renamed DNS record of \"$1\" to \"$2\" \n"

			echo -e "Forward Lookup :\n"

			nslookup $2 | grep ^Name -A 1

			echo -e "\nReverse Lookup :\n"

			nslookup $5

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

v_a_record_exist=$(grep "^$v_existing_record " $v_fw_zone)
v_capture_a_record_ip=$(grep "^$v_existing_record " $v_fw_zone | cut -d "A" -f 2 | tr -d '[[:space:]]')

v_target_length=39
v_num_spaces=$(( v_target_length - ${#v_modify_record} ))
v_a_record_modify="${v_modify_record}$(printf '%*s' "$v_num_spaces")"
v_a_record_modify=$(echo "$v_a_record_modify IN A $v_capture_a_record_ip")


if echo $v_capture_a_record_ip | grep 192.168.168
then
	echo -e "\nMatch found in Prod Network ( 192.168.168.0/24) with IP $v_capture_a_record_ip for $v_existing_record.\n"
	f_rename_records "$v_existing_record" "$v_modify_record" "$v_fw_zone" "$v_ptr_zone_prod" "$v_capture_a_record_ip" "$v_a_record_exist" "$v_a_record_modify"

elif echo $v_capture_a_record_ip | grep 10.10.10
then
	echo -e "\nMatch found in Test Network ( 10.10.10.0/24) with IP $v_capture_a_record_ip for $v_existing_record.\n"
	f_rename_records "$v_existing_record" "$v_modify_record" "$v_fw_zone" "$v_ptr_zone_test" "$v_capture_a_record_ip" "$v_a_record_exist" "$v_a_record_modify"

elif echo $v_capture_a_record_ip | grep 172.16.16
then
	echo -e "\nMatch found in Dev Network ( 172.16.16.0/24) with IP $v_capture_a_record_ip for $v_existing_record.\n"
	f_rename_records "$v_existing_record" "$v_modify_record" "$v_fw_zone" "$v_ptr_zone_dev" "$v_capture_a_record_ip" "$v_a_record_exist" "$v_a_record_modify"
fi

exit
