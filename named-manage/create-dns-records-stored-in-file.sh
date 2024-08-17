#!/bin/bash
v_host_create_file='hosts-create-list'

if [[ ! -f ${v_host_create_file} ]];then echo -e "\nFile \"${v_host_create_file}\" doesn't exist!\n";exit;fi 

if [[ ! -s ${v_host_create_file} ]];then echo -e "\nFile \"${v_host_create_file}\" is emty!\n";exit;fi

sed -i '/^[[:space:]]*$/d' ${v_host_create_file}

sed -i 's/.ms.local.//g' ${v_host_create_file}

sed -i 's/.ms.local//g' ${v_host_create_file}


f_get_network_id() {
	echo -e "Select the Network :\n"
        echo -e "1) Prod Network ( 192.168.168.0/24)"
        echo -e "2) Test Network ( 10.10.10.0/24)"
        echo -e "3) Dev  Network ( 172.16.16.0/24)"
        echo -e "q) Exit the script without any changes\n"
        read -p "Choose Option Number : " v_network

        case ${v_network} in
                1|2|3)  while :
			do
				echo -e "\nRecords to be created : \n"
				cat ${v_host_create_file}
				echo -e "\nNote : If a record already exists, will be ignored .\n"

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
                	;;

               		q) echo -e "\nExiting without any changes !\n"
                    	   exit
                	;;

                	*) echo -e "\nEntered Option is Wrong !!!\n"
                    	   read -p"Press Enter to go back to main menu <ENTER>"
                    	   f_get_network_id
                	;;
        	esac
}

f_get_network_id

for v_host_to_create in $(cat ${v_host_create_file}) 
do

./create-dns-records.sh ${v_host_to_create} ${v_network}
clear

done

echo -e "\nScript $(basename $0) completed execution !"
echo -e "\nPlease find the below details of the records :\n"
tput bold && tput setaf 6 && \
        echo -e "Fully Qualified Domain Name                        IPv4 Address" \
        && tput sgr0

for v_host in $(cat ${v_host_create_file})
do
        v_fqdn="${v_host}.ms.local"
        v_ip_address=$(nslookup ${v_fqdn} | grep ^Name -A 1 | grep Address | cut -d ":" -f 2 | tr -d '[[:space:]]')
        v_target_length=50
        v_num_spaces=$(( v_target_length - ${#v_fqdn} ))
        v_fqdn_space_adjusted="${v_fqdn}$(printf '%*s' "${v_num_spaces}")"
        echo "${v_fqdn_space_adjusted} ${v_ip_address}"
done
echo

exit
