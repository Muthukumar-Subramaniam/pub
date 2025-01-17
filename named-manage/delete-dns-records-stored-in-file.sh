#!/bin/bash
var_named_manage_dir='/scripts_by_muthu/server/named-manage'
var_delete_record="${var_named_manage_dir}/delete-dns-records.sh"
var_zone_dir='/var/named/zone-files'
var_fw_zone="${var_zone_dir}/ms.local-forward.db"
# Define color codes
v_RED='\033[0;31m'      # Red
v_GREEN='\033[0;32m'    # Green
v_YELLOW='\033[0;33m'   # Yellow
v_BLUE='\033[0;34m'     # Blue
v_CYAN='\033[0;36m'     # Cyan
v_MAGENTA='\033[0;35m'  # Magenta
v_RESET='\033[0m'       # Reset to default color

if ! sudo -l | grep NOPASSWD &> /dev/null
then
	echo -e "\n${v_RED}You need sudo access without password to run this script ! ${v_RESET}\n"
	exit
fi

clear
		
echo -e "###########################(DNS-MultiDestroyer)############################"

if [ -z "${1}" ]
then
	echo
	echo -ne "${v_CYAN}Name of the file containing the list of host records to delete : ${v_RESET}" 
	read -e v_host_delete_file
else
	v_host_delete_file="${1}"
fi

if [[ ! -f ${v_host_delete_file} ]];then echo -e "\n${v_RED}File \"${v_host_delete_file}\" doesn't exist!${v_RESET}\n";exit;fi 

if [[ ! -s ${v_host_delete_file} ]];then echo -e "\n${v_RED}File \"${v_host_delete_file}\" is emty!${v_RESET}\n";exit;fi

sed -i '/^[[:space:]]*$/d' ${v_host_delete_file}

sed -i 's/.ms.local.//g' ${v_host_delete_file}

sed -i 's/.ms.local//g' ${v_host_delete_file}


while :
do
	echo -e "\n${v_CYAN}Records to be deleted : ${v_RESET}\n"

	cat ${v_host_delete_file}

	echo -ne "\n${v_YELLOW}Provide your confirmation to delete the above host records (y/n) : ${v_RESET}"
	
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

v_tmp_file_host_record_details="/tmp/tmp_file_host_record_details"

> "${v_tmp_file_host_record_details}"

v_successefull="${v_GREEN}[ succeded ]${v_RESET}"
v_failed="${v_RED}[ failed ]${v_RESET}"

v_pre_execution_serial_fw_zone=$(sudo grep ';Serial' ${var_fw_zone} | cut -d ";" -f 1 | tr -d '[:space:]')

v_total_host_records=$(wc -l < "${v_host_delete_file}")

v_host_count=0

while read -r v_host_to_delete
do
	clear

	echo -e "###########################(DNS-MultiDestroyer)############################\n"

	if [[ ${v_host_count} -le ${v_total_host_records} ]];then

		echo -e "#############################( Running )###############################"
		echo -ne "\n${v_GREEN}Status : [ ${v_host_count}/${v_total_host_records} ] host records are being processed${v_RESET}"
	fi

	let v_host_count++

	echo -ne "\n\n${v_CYAN}Attempting to delete the host record ${v_host_to_delete}.ms.local . . . ${v_RESET}"

	v_serial_fw_zone_pre_execution=$(sudo grep ';Serial' ${var_fw_zone} | cut -d ";" -f 1 | tr -d '[:space:]')

	"${var_delete_record}" "${v_host_to_delete}" -y "Automated-Execution"

	var_exit_status=${?}

	v_serial_fw_zone_post_execution=$(sudo grep ';Serial' ${var_fw_zone} | cut -d ";" -f 1 | tr -d '[:space:]')

        v_fqdn="${v_host_to_delete}.ms.local"

	v_host_record_details="${v_fqdn}${v_RESET}"
		
	if [[ ${var_exit_status} -eq 9 ]]
	then
        	echo -e "${v_RED}Invalid-Host     ${v_host_record_details}" >> "${v_tmp_file_host_record_details}" && echo -ne "${v_failed}" 

	elif [[ ${var_exit_status} -eq 8 ]]
	then
        	echo -e "${v_YELLOW}Doesn't-Exist    ${v_host_record_details}" >> "${v_tmp_file_host_record_details}" && echo -ne "${v_failed}"
	else
		v_serial_fw_zone_post_execution=$(sudo grep ';Serial' ${var_fw_zone} | cut -d ";" -f 1 | tr -d '[:space:]')

		if [[ "${v_serial_fw_zone_pre_execution}" -ne "${v_serial_fw_zone_post_execution}" ]]
		then
			echo -e "${v_GREEN}Deleted          ${v_host_record_details}" >> "${v_tmp_file_host_record_details}" && echo -ne "${v_successefull}"
		else
        		echo -e "${v_RED}Failed-to-Delete ${v_host_record_details}" >> "${v_tmp_file_host_record_details}" && echo -ne "${v_failed}"
		fi
	fi

	if [[ ${v_host_count} -eq ${v_total_host_records} ]];then

		clear
		echo -e "###########################(DNS-MultiDestroyer)############################\n"
		echo -e "#############################( Completed )#############################\n"
		echo -ne "${v_GREEN}Status : [ ${v_host_count}/${v_total_host_records} ] host records have been processed${v_RESET}"
	fi


done < "${v_host_delete_file}"

v_post_execution_serial_fw_zone=$(sudo grep ';Serial' ${var_fw_zone} | cut -d ";" -f 1 | tr -d '[:space:]')

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

echo -e "${v_CYAN}Action-Taken     FQDN ( IPv4-Address )${v_RESET}"

cat "${v_tmp_file_host_record_details}"

echo

rm -f "${v_tmp_file_host_record_details}"

exit
