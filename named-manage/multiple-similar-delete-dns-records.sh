#!/bin/bash
#This script utilizes another script "delete-dns-records.sh" in the current directory

if [[ "$(id -u)" -ne 0 ]]
then
	echo -e "\nPlease run this script as root or using sudo ! \n"
	exit
fi

f_delete_multiple_similar_records() {
	v_set_a_record=${1}
	v_set_num_of_hosts=${2}

for v_host_suffix_num in $( seq 1 ${v_set_num_of_hosts} )
do

./delete-dns-records.sh ${v_set_a_record}${v_host_suffix_num} -y

done

}

f_get_hostname_and_count() {
	echo -e "\n<< This script automates delete-dns-records.sh >>\n\nUse Case : for example if you want to delete records from muthuks-dev-vm1 to muthuks-dev-vm10.\nIn this case all you need to provide is muthuks-dev-vm, how many ( Ex.10)\n"
	while :
	do
		echo -e "\nPlease use only letters, numbers, and hyphens.\n (Please do not start with a number)."
		echo -e "No need to append the domain name ms.local\n"
		read -p "Please Enter the required prefix name : " v_a_record

		if [[ ${v_a_record} =~ ^[[:alpha:]]([-[:alnum:]]*)$ ]]
	       	then
    			break
  		else
    			echo -e "Invalid name!\nPlease use only letters, numbers, and hyphens.\n (cannot start with a number).\n"
  		fi
	done

	while :
	do
		echo -e "\n"
		read -p "Enter number of \"${v_a_record}\" to delete (minimum 2) : " v_num_of_hosts
			
		# Check if input is a number using regular expression
		if [[ ! ${v_num_of_hosts} =~ ^[0-9]+$ ]]
		then
  			echo -e "\nInvalid! Please enter a valid number.\n"
  			continue
		fi

		# Check if the number is greater than or equal to 2
		if [[ ${v_num_of_hosts} -lt 2 ]]
		then
  			echo -e "\nInvalid! Please enter a number greater than or equal to 2.\n"
			continue
		fi

		break
	done

	while :
        do
        	echo -e "\nRecords to be deleted : "
		for v_host_num in $(seq 1 ${v_num_of_hosts} );do echo "${v_a_record}${v_host_num}";done
              	echo -e "\nNote : If a record doesn't exist, will be ignored .\n"

              	read -p "Do you want to proceed? (y/n) :" v_confirmation

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

}

f_get_hostname_and_count
f_delete_multiple_similar_records "${v_a_record}" "${v_num_of_hosts}"

exit
