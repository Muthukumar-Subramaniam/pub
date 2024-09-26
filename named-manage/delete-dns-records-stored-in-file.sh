#!/bin/bash
v_host_delete_file='./hosts-delete-list'

if [[ "$(id -u)" -ne 0 ]]
then
	echo -e "\nPlease run this script as root or using sudo ! \n"
	exit
fi

if [[ ! -f ${v_host_delete_file} ]];then echo -e "\nFile \"${v_host_delete_file}\" doesn't exist!\n";exit;fi 

if [[ ! -s ${v_host_delete_file} ]];then echo -e "\nFile \"${v_host_delete_file}\" is emty!\n";exit;fi

sed -i '/^[[:space:]]*$/d' ${v_host_delete_file}

sed -i 's/.ms.local.//g' ${v_host_delete_file}

sed -i 's/.ms.local//g' ${v_host_delete_file}

while :
do
	echo -e "\nRecords to be deleted : "
	cat ${v_host_delete_file} 
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


for v_host_to_delete in $(cat ${v_host_delete_file}) 
do

echo -e "\nRunning delete-dns-records.sh for ${v_host_to_delete} . . .\n"
./delete-dns-records.sh ${v_host_to_delete} -y
clear

done
