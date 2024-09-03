#!/bin/bash
#This script utilizes another script "create-dns-records.sh" in the current directory

if [[ "$(id -u)" -ne 0 ]]
then
	echo -e "\nPlease run this script as root or using sudo ! \n"
	exit
fi

f_create_multiple_similar_records() {
	v_set_a_record=${1}
	v_set_num_of_hosts=${2}
	v_set_network_num=${3}	

for v_host_suffix_num in $( seq 1 ${v_set_num_of_hosts} )
do
clear
echo -e "\nRunning create-dns-records.sh for ${v_set_a_record}${v_host_suffix_num} . . .\n"
./create-dns-records.sh ${v_set_a_record}${v_host_suffix_num} ${v_set_network_num} 
sleep 0.25
clear
done

}


f_main_menu() {
	echo -e "\n<< This script automates create-dns-records.sh >>\n\nUse Case : for example if you want to create records from muthuks-dev-vm1 to muthuks-dev-vm10.\nIn this case all you need to provide is muthuks-dev-vm, how many ( Ex.10), and the network.\n"

	f_get_hostname_and_count() {
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

		while :
		do
			echo -e "\n"
			read -p "Enter number of hosts required (minimum 2) : " v_num_of_hosts
			
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


	}

	f_get_network() {
        	echo -e "Select the Network :\n"
        	echo -e "1) Prod Network ( 192.168.168.0/24)"
        	echo -e "2) Test Network ( 10.10.10.0/24)"
        	echo -e "3) Dev  Network ( 172.16.16.0/24)"
		echo -e "a) Go back to setting A Record"
        	echo -e "q) Exit the script without any changes\n"
        	read -p "Choose Option Number : " v_network

        	case ${v_network} in
                	1|2|3)  while :
				do
					echo -e "\nRecords to be created : \n"
					for v_host_num in $(seq 1 ${v_num_of_hosts} );do echo "${v_a_record}${v_host_num}";done
					echo -e "\nNote : If a record already exists, will be ignored .\n"

					read -p "Do you want to proceed? (y/n) :" v_confirmation

                			if [[ ${v_confirmation} == "y" ]]
                			then
						f_create_multiple_similar_records "${v_a_record}" "${v_num_of_hosts}"  "${v_network}"
						break

					elif [[ ${v_confirmation} == "n" ]]
					then
						echo -e "\nCancelled without any changes !\n"
						break

					else
						echo -e "\nSelect either (y/n) only !\n"
						continue

					fi
				done
                	;;

			a) f_get_hostname_and_count
		           f_get_network
			;;

               		q) echo -e "\nExiting without any changes !\n"
                    	   exit
                	;;

                	*) echo -e "\nEntered Option is Wrong !!!\n"
                    	   read -p"Press Enter to go back to main menu <ENTER>"
                    	   f_get_network
                	;;
        	esac
	}

	f_get_hostname_and_count
	f_get_network
}

f_main_menu

echo -e "\nScript $(basename $0) completed execution !"
echo -e "\nPlease find the below details of the records :\n"
tput bold && tput setaf 6 && \
	echo -e "Fully Qualified Domain Name                        IPv4 Address" \
	&& tput sgr0

for v_host_num in $(seq 1 ${v_num_of_hosts} )
do
	v_fqdn="${v_a_record}${v_host_num}.ms.local"
	v_ip_address=$(nslookup ${v_a_record}${v_host_num} | grep ^Name -A 1 | grep Address | cut -d ":" -f 2 | tr -d '[[:space:]]')
	v_target_length=50
        v_num_spaces=$(( v_target_length - ${#v_fqdn} ))
  	v_fqdn_space_adjusted="${v_fqdn}$(printf '%*s' "${v_num_spaces}")"
	echo "${v_fqdn_space_adjusted} ${v_ip_address}"
done
echo

exit
