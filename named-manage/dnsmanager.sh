#!/bin/bash
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
	echo -e "${v_RED}\nYou need sudo access without password to run this script! ${v_RESET}\n"
	exit
fi

v_domain_name=$(if [ -f /etc/named.conf ];then sudo grep 'zones-are-managed-by-dnsmanager' /etc/named.conf | awk '{print $2}';fi)

fn_check_existence_of_domain() {
	if [ -z "${v_domain_name}" ]
	then
		echo -e "\n${v_RED}> Seems like bind dns service is not being handled by dnsmanager! ${v_RESET}\n"
		echo -e "${v_YELLOW}> Please check and setup the same using dnsmanager utility itself! ${v_RESET}\n"
		exit
	fi
}

var_zone_dir='/var/named/zone-files'
v_fw_zone="${var_zone_dir}/${v_domain_name}-forward.db"

fn_split_network_into_cidr24subnets() {
	# Function to convert an IP address to a number
	fn_ip_to_int() {
    	local ip=${1}
    	local a b c d
    	IFS=. read -r a b c d <<< "$ip"
    	echo "$((a * 256 ** 3 + b * 256 ** 2 + c * 256 + d))"
	}
	
	# Function to convert a number back to an IP address
	fn_int_to_ip() {
    	local int=${1}
    	echo "$((int >> 24 & 255)).$((int >> 16 & 255)).$((int >> 8 & 255)).$((int & 255))"
	}
	
	# Function to generate /24 subnets within a given network
	fn_generate_subnets() {
    	local v_network=${1}
    	local v_cidr=${2}
	
    	# Convert network address to an integer
    	local v_network_int
    	v_network_int=$(fn_ip_to_int "${v_network}")
	
    	# Calculate the number of subnets to generate
    	local v_subnet_count
    	v_subnet_count=$(( 2 ** (32 - v_cidr) / 256 ))
	
    	# Generate subnets
    	for ((i = 0; i < v_subnet_count; i++)); do
        	local v_subnet_int=$(( v_network_int + i * 256 ))
        	local v_subnet
        	v_subnet=$(fn_int_to_ip "${v_subnet_int}")
        	echo "${v_subnet}/24"
    	done
	}

	v_dns_host_short_name=$(hostname -s)
	v_primary_interface=$(ip r | grep default | awk '{ print $5 }')
	v_primary_ip=$(ip r | grep -v default | grep "${v_primary_interface}" | head -n 1 | awk '{ print $9 }')
	v_network_gateway=$(ip r | grep default | awk '{ print $3 }')
	v_network_and_cidr=$(ip r | grep -v default | grep "${v_primary_interface}" | head -n 1 | awk '{ print $1 }')
	
	# Extract network and CIDR from input
	v_network=$(echo "${v_network_and_cidr}" | cut -d/ -f1)
	v_cidr=$(echo "${v_network_and_cidr}" | cut -d/ -f2)
	
	# Check if CIDR is valid
	if ! [[ "${v_cidr}" =~ ^[0-9]+$ ]] || [ "${v_cidr}" -lt 16 ] || [ "${v_cidr}" -gt 24 ]; then
    	echo "Invalid CIDR. Only Networks with CIDR between 16 and 24 is allowed."
    	exit 1
	fi
	
	# Generate and display the subnets
	fn_generate_subnets "${v_network}" "${v_cidr}" |  sed "s/\.0\/24//"
}

v_splited_subnets=$(fn_split_network_into_cidr24subnets)
v_total_ptr_zones=$(echo ${v_splited_subnets} | awk '{print NF}')

v_zone_number=1
for v_subnet_part in ${v_splited_subnets}
do
    eval "v_ptr_zone${v_zone_number}=\"${var_zone_dir}/${v_subnet_part}.${v_domain_name}-reverse.db\""
    eval "v_subnet${v_zone_number}=\"${v_subnet_part}\""
    let v_zone_number++
done

v_tmp_file_dnsmanager="/tmp/tmp_file_dnsmanager"


fn_configure_named_dns_server() {

	if [ ! -z "${v_domain_name}" ]
	then
		echo -e "\n${v_YELLOW}> Seems like bind dns server and domain is already setup and managed by dnsmanager! ${v_RESET}\n"
		echo -e "${v_GREEN}> Domain '${v_domain_name}' is already being managed by dnsmanager! ${v_RESET}\n"
		echo -e "${v_YELLOW}> Nothing to do!  ${v_RESET}\n"
		exit
	fi

	fn_instruct_on_valid_domain_name() {
		echo -e "\nFYI :"
		echo -e "${v_RED}> Only allowed TLD is 'local' ."
		echo -e "> Maximum 2 subdomains are only allowed."
		echo -e "> Only letters, numbers, and hyphens are allowed with subdomains."
		echo -e "> Hyphens cannot appear at the start or end of the subdomains."
		echo -e "> The total length must be between 1 and 63 characters."
		echo -e "> Follows the format defined in RFC 1035."
		echo -e "> Examples for Valid Domain Names :"  
		echo -e "	test.local, test.example.local, 123-example.local, test-lab1.local"
		echo -e "	123.example.local, test1.lab1.local, test-1.example-1.local${v_RESET}\n"
	}
	
	fn_instruct_on_valid_domain_name	

	while :
	do
		read -p "Provide the preferred local domain : " v_given_domain 
			
		if [[ "${#v_given_domain}" -le 63 ]] && [[ "${v_given_domain}" =~ ^[[:alnum:]]+([-.][[:alnum:]]+)*(\.[[:alnum:]]+){0,2}\.local$ ]]
		then
			break
		else
			fn_instruct_on_valid_domain_name
			continue
		fi
	done

	echo -ne "\n${v_CYAN}Fetching network information from the system . . . ${v_RESET}"

	fn_split_network_into_cidr24subnets &>/dev/null

	echo -e "${v_GREEN}[ done ]${v_RESET}"

	echo -ne "\n${v_CYAN}Checking whether required bind dns packages are installed . . . ${v_RESET}"

	if sudo rpm -q bind bind-utils &>/dev/null 
	then
		echo -e "${v_GREEN}[ already installed ]${v_RESET}"
	else
		echo -e "${v_YELLOW}[ not yet installed ]${v_RESET}"

		echo -ne "\n${v_CYAN}Installing the required bind dns packages . . . ${v_RESET}"

		if sudo dnf install bind bind-utils -y &>/dev/null
		then
			echo -e "${v_GREEN}[ installed ]${v_RESET}"
		else
			echo -e "${v_RED}[ failed to install ] ${v_RESET}"
			echo -e "\n${v_RED}Try installing the packages bind and bind-utils manually then try the script again! \n${v_RESET}"
			exit
		fi
	fi

	echo -ne "\n${v_CYAN}Taking backup of named.conf . . . ${v_RESET}"

	sudo cp -p /etc/named.conf /etc/named.conf_bkp_by_dnsmanager
	
	echo -e "${v_GREEN}[ done ]${v_RESET}"

	echo -ne "\n${v_CYAN}Configuring named.conf . . . ${v_RESET}"

	sudo sed -i "s/listen-on port 53 {\s*127.0.0.1;\s*};/listen-on port 53 { 127.0.0.1; ${v_primary_ip}; };/" /etc/named.conf

	sudo sed -i "s/allow-query\s*{\s*localhost;\s*};/allow-query     { localhost; ${v_network}\/${v_cidr}; };/" /etc/named.conf

	sudo sed -i '/dnssec-validation yes;/d' /etc/named.conf

	sudo sed -i '/recursion yes;/a # BEGIN google-dns-servers-as-forwarders\n\n        forwarders {\n                8.8.8.8;\n                8.8.4.4;\n        };\n\n        dnssec-validation no;\n# END google-dns-servers-as-forwarders' /etc/named.conf

	sudo tee -a /etc/named.conf > /dev/null << EOF
# BEGIN zones-of-${v_given_domain}-domain
# ${v_given_domain} zones-are-managed-by-dnsmanager
//Forward Zone for ${v_given_domain}
zone "${v_given_domain}" IN {
           type master;
           file "zone-files/${v_given_domain}-forward.db";
           allow-update { none; };
};
//Reverse Zones ms.local
EOF
	
	for v_subnet_part in ${v_splited_subnets}
	do
		v_reverse_subnet_part=$(echo "${v_subnet_part}" | awk -F. '{print $3"."$2"."$1}')
		sudo tee -a /etc/named.conf > /dev/null << EOF
zone "${v_reverse_subnet_part}.in-addr.arpa" IN {
             type master;
             file "zone-files/${v_subnet_part}.${v_given_domain}-reverse.db";
             allow-update { none; };
};
EOF
	done

	echo -e "# END zones-of-${v_given_domain}-domain" | sudo tee -a /etc/named.conf > /dev/null

	echo -e "${v_GREEN}[ done ]${v_RESET}"

	echo -ne "\n${v_CYAN}Creating and configuring zone files . . . ${v_RESET}"

	sudo mkdir -p "${var_zone_dir}"

	fn_update_dns_server_data_to_zone_file() {
		v_file_name="${1}"
		sudo tee -a "${v_file_name}" > /dev/null << EOF
\$TTL 86400
@   IN  SOA  ${v_dns_host_short_name}.${v_given_domain}. root.${v_given_domain}. (
        1	;Serial
        3600	;Refresh
        1800	;Retry
        604800	;Expire
        86400	;Minimum TTL
)

;Name Server Information
@ IN NS ${v_dns_host_short_name}.${v_given_domain}.
EOF
	}

	v_zone_file_name="${var_zone_dir}/${v_given_domain}-forward.db"

	fn_update_dns_server_data_to_zone_file "${v_zone_file_name}"
	echo -e "\n;A-Records" | sudo tee -a "${v_zone_file_name}" > /dev/null

	v_gateway_adjusted_space=$(printf "%-*s" 63 "gateway")

	echo -e "${v_gateway_adjusted_space} IN A ${v_subnet1}.1" | sudo tee -a  "${v_zone_file_name}" > /dev/null

	v_dns_host_short_name_adjusted_space=$(printf "%-*s" 63 "${v_dns_host_short_name}")
	
	echo -e "${v_dns_host_short_name_adjusted_space} IN A ${v_primary_ip}" | sudo tee -a "${v_zone_file_name}" > /dev/null

	for v_subnet_part in ${v_splited_subnets}
	do
		v_zone_file_name="${var_zone_dir}/${v_subnet_part}.${v_given_domain}-reverse.db"
		fn_update_dns_server_data_to_zone_file "${v_zone_file_name}"
		echo -e "\n;PTR-Records" | sudo tee -a "${v_zone_file_name}" > /dev/null
		if [[ "${v_subnet_part}" == "${v_subnet1}" ]]
		then
			echo -e "1   IN PTR gateway.${v_given_domain}." | sudo tee -a "${v_zone_file_name}" > /dev/null
			v_get_ip_part_primary_ip=$(echo "${v_primary_ip}" | awk -F. '{print $4}')
			v_ip_part_primary_ip_adjusted_space=$(printf "%-*s" 3 "${v_get_ip_part_primary_ip}")
			echo -e "${v_ip_part_primary_ip_adjusted_space} IN PTR ${v_dns_host_short_name}.${v_given_domain}." | sudo tee -a "${v_zone_file_name}" > /dev/null
		fi
	done

	echo -e "${v_GREEN}[ done ]${v_RESET}"

	echo -ne "\n${v_CYAN}Enabling and Starting named DNS Service . . . ${v_RESET}"

	sudo systemctl enable --now named &>/dev/null	

	echo -e "${v_GREEN}[ done ]${v_RESET}"

	echo -ne "\n${v_CYAN}Updating Network Manager to point the local dns server and domain . . . ${v_RESET}"

	v_active_connection_name=$(sudo nmcli connection show --active | grep "${v_primary_interface}" | head -n 1 | awk '{ print $1 }')

	sudo nmcli connection modify "${v_active_connection_name}" ipv4.dns-search "${v_given_domain}" &>/dev/null

	sudo nmcli connection modify "${v_active_connection_name}" ipv4.dns "127.0.0.1,8.8.8.8,8.8.4.4"  &>/dev/null

	sudo nmcli connection reload "${v_active_connection_name}" &>/dev/null

	sudo nmcli connection up "${v_active_connection_name}" &>/dev/null

	echo -e "${v_GREEN}[ done ]${v_RESET}"

	echo -e "\n${v_GREEN}All done! Your domain \"${v_given_domain}\" with DNS server ${v_primary_ip} [ ${v_dns_host_short_name}.${v_given_domain}  ] has been configured.${v_RESET}"
	echo -e "${v_YELLOW}Now you could manage the domain  \"${v_given_domain}\" with dnsmanager utility from command line.\n${v_RESET}"

	sudo cp -p $(pwd)/$0 /usr/local/bin/dnsmanager

	exit
}


fn_get_host_record() {
	v_input_host="${1}"
	v_action_requested="${2}"

	fn_instruct_on_valid_host_record() {
		echo -e "\n${v_RED}> Only letters, numbers, and hyphens are allowed."
		echo -e "> Hyphens cannot appear at the start or end."
		echo -e "> The total length must be between 1 and 63 characters."
		echo -e "> The domain name '${v_domain_name}' will be appended if not present."
		echo -e "> Follows the format defined in RFC 1035.${v_RESET}\n"
		exit
	}

	fn_get_host_record_from_user() {

		while :
		do
			echo

			if [[ "${v_action_requested}" != "rename" ]]
			then
				read -p "Please Enter the name of host record to ${v_action_requested} : " v_input_host_record
			else
				if [ -z "${v_host_record}" ]
				then
					read -p "Please Enter the name of host record to ${v_action_requested} : " v_input_host_record
				else
					read -p "Please Enter the name of host record to ${v_action_requested} ${v_host_record}.${v_domain_name} : " v_input_host_record
				fi
			fi
				
			v_input_host_record="${v_input_host_record%.${v_domain_name}.}"  
			v_input_host_record="${v_input_host_record%.${v_domain_name}}"

			if [[ "${v_action_requested}" != "rename" ]]
			then
				v_host_record="${v_input_host_record}"
			else
				if [ -z "${v_host_record}" ]
				then
					v_host_record="${v_input_host_record}"
				else
					v_rename_record="${v_input_host_record}"
				fi
			fi

			if [[ "${#v_input_host_record}" -le 63 ]] && [[ "${v_input_host_record}" =~ ^[[:alnum:]]([-[:alnum:]]*[[:alnum:]])$ ]]
	       		then
				if [[ "${v_action_requested}" != "rename" ]]
				then
					v_host_record="${v_input_host_record}"
				else
					if [ -z "${v_host_record}" ]
					then
						v_host_record="${v_input_host_record}"
					else
						v_rename_record="${v_input_host_record}"
					fi
				fi

    				break
  			else
				fn_instruct_on_valid_host_record
  			fi
		done
	}

	if [[ ! -z ${v_input_host} ]]
	then
                v_host_record=${1}
		v_host_record="${v_host_record%.${v_domain_name}.}"  
		v_host_record="${v_host_record%.${v_domain_name}}"

		if [[ ! ${v_host_record} =~ ^[[:alnum:]]([-[:alnum:]]*[[:alnum:]])$ ]] || [[ ! "${#v_host_record}" -le 63 ]]
		then
                        if ${v_if_autorun_false}
			then
				fn_instruct_on_valid_host_record
			else
				return 9
			fi
		fi

	else
		fn_get_host_record_from_user
	fi

	if sudo grep "^${v_host_record} "  "${v_fw_zone}" &>/dev/null
	then 
		if [[ "${v_action_requested}" == "create" ]]
		then
			${v_if_autorun_false} && echo -e "\n${v_RED}Host record for ${v_host_record}.${v_domain_name} already exists ! ${v_RESET}\n"
			${v_if_autorun_false} && echo -e "${v_RED}Nothing to do ! Exiting !  ${v_RESET}\n"
			return 8

		elif [[ "${v_action_requested}" == "rename" ]]
		then
			fn_get_host_record_from_user

			if sudo grep "^${v_rename_record} "  "${v_fw_zone}" &>/dev/null
			then 
				echo -e "\n${v_RED}Conflict ! Existing host record found for ${v_rename_record}.${v_domain_name} ! ${v_RESET}\n"
				echo -e "${v_RED}Nothing to do ! Exiting !  ${v_RESET}\n"
				exit
			fi
		fi

	elif [[ "${v_action_requested}" != "create" ]]
	then
		if ${v_if_autorun_false}
		then
			echo -e "\n${v_RED}Host record for ${v_host_record}.${v_domain_name} doesn't exist ! ${v_RESET}\n"
			echo -e "${v_RED}Nothing to do ! Exiting ! ${v_RESET}\n"
			exit
		else
			return 8
		fi
		
	fi
}

fn_update_serial_number_of_zones() {

	${v_if_autorun_false} && echo -ne "\n${v_CYAN}Updating serial numbers of zone files . . . ${v_RESET}"

	v_current_serial_fw_zone=$(sudo grep ';Serial' ${v_fw_zone} | cut -d ";" -f 1 | tr -d '[:space:]')
	v_set_new_serial_fw_zone=$(( v_current_serial_fw_zone + 1 ))
	sudo sed -i "/;Serial/s/${v_current_serial_fw_zone}/${v_set_new_serial_fw_zone}/g" "${v_fw_zone}"

	v_current_serial_ptr_zone=$(sudo grep ';Serial' "${v_ptr_zone}" | cut -d ";" -f 1 | tr -d '[:space:]')
	v_set_new_serial_ptr_zone=$(( v_current_serial_ptr_zone + 1 ))
	sudo sed -i "/;Serial/s/${v_current_serial_ptr_zone}/${v_set_new_serial_ptr_zone}/g" "${v_ptr_zone}"

	${v_if_autorun_false} && echo -ne "${v_GREEN}[ done ]${v_RESET}\n"
}


fn_reload_named_dns_service() {

	echo -ne "\n${v_CYAN}Reloading the DNS service ( named ) . . . ${v_RESET}"

	sudo systemctl reload named &>/dev/null

	if sudo systemctl is-active named &>/dev/null;
	then 
		echo -ne "${v_GREEN}[ ok ]${v_RESET}\n"
	else
		echo -ne "${v_RED}[ failed ]${v_RESET}\n"
	fi
        

	if [[  "${v_action_requested}" == "create" ]]
	then
		echo -e "\n${v_GREEN}Successfully created host record ${v_host_record}.${v_domain_name}${v_RESET}\n"
	 
	elif [[ "${v_action_requested}" == "delete" ]]
	then
		echo -e "\n${v_GREEN}Successfully deleted host record ${v_host_record}.${v_domain_name}${v_RESET}\n"

	elif [[ "${v_action_requested}" == "rename" ]]
	then
        	echo -e "\n${v_GREEN}Successfully renamed host ${v_host_record}.${v_domain_name} to ${v_rename_record}.${v_domain_name}${v_RESET}\n"
	fi


	if [[ "${v_action_requested}" != "delete" ]]
	then

		echo -ne "${v_CYAN}Validating forward look up . . . "

		if  [[ "${v_action_requested}" == "rename" ]]
		then
			if nslookup ${v_rename_record} &>/dev/null
			then
				echo -ne "${v_GREEN}[ ok ]${v_RESET}\n"
			else
				echo -ne "${v_RED}[ failed ]${v_RESET}\n"
			fi
		else
			if nslookup ${v_host_record} &>/dev/null
			then
				echo -ne "${v_GREEN}[ ok ]${v_RESET}\n"
			else
				echo -ne "${v_RED}[ failed ]${v_RESET}\n"
			fi
		fi
	
		echo -ne "\n${v_CYAN}Validating reverse look up . . . "

		if nslookup ${v_current_ip_of_host_record} &>/dev/null
		then
                	echo -ne "${v_GREEN}[ ok ]${v_RESET}\n"
                else
                	echo -ne "${v_RED}[ failed ]${v_RESET}\n"
                fi

		if  [[ "${v_action_requested}" == "rename" ]]
                then
			echo -e "\n${v_GREEN}FYI : $(host ${v_rename_record}.${v_domain_name})${v_RESET}\n"
		else
			echo -e "\n${v_GREEN}FYI : $(host ${v_host_record}.${v_domain_name})${v_RESET}\n"
		fi
	fi
}

fn_set_ptr_zone() {

	arr_subnets=()
	arr_ptr_zones=()

	for ((v_zone_number=1; v_zone_number<=v_total_ptr_zones; v_zone_number++))
	do
    		arr_subnet_var="v_subnet${v_zone_number}"
    		arr_ptr_zone_var="v_ptr_zone${v_zone_number}"
    		arr_subnets+=( "$(eval echo \${${arr_subnet_var}})" )
    		arr_ptr_zones+=( "$(eval echo \${${arr_ptr_zone_var}})" )
	done

	for i in "${!arr_subnets[@]}"
	do
    		if [[ "${v_current_ip_of_host_record}" =~ ${arr_subnets[i]} ]]
		then
        		${v_if_autorun_false} && echo -e "\n${v_GREEN}Match found with IP ${v_current_ip_of_host_record} for host record ${v_host_record}.${v_domain_name} ${v_RESET}\n"
        		v_ptr_zone="${arr_ptr_zones[i]}"
        		break
    		fi
	done
}


fn_create_host_record() {

	if [[ "${2}" != "Automated-Execution" ]]
	then
		v_if_autorun_false=true	
	else
		v_if_autorun_false=false	
	fi

	fn_get_host_record "${1}" "create"

	v_exit_status_fn_get_host_record=${?}

	if [[ ${v_exit_status_fn_get_host_record} -ne 0 ]]
	then
		return ${v_exit_status_fn_get_host_record}
	fi

	fn_check_free_ip() {

		local v_file_ptr_zone="${1}"
		local v_start_ip="${2}"
		local v_max_ip="${3}"
		local v_subnet="${4}"
		local v_capture_list_of_ips=$(sudo sed -n 's/^\([0-9]\+\).*/\1/p' "${v_file_ptr_zone}")
		declare -A v_existing_ips

		if [ -z "${v_capture_list_of_ips}" ]
		then
			v_host_part_of_current_ip="${v_start_ip}"
			v_previous_ip=';PTR-Records'
			v_current_ip_of_host_record="${v_subnet}.${v_host_part_of_current_ip}"
			v_ptr_zone="${v_file_ptr_zone}"
			return 0
		fi

		while IFS= read -r ip
		do
        		v_existing_ips["$ip"]=1
		done <<< "${v_capture_list_of_ips}"

		for ((v_num_ptr = ${v_start_ip}; v_num_ptr <= ${v_max_ip}; v_num_ptr++))
		do
			if [[ -z "${v_existing_ips[$v_num_ptr]+isset}" ]]
			then
				v_host_part_of_current_ip="${v_num_ptr}"
				v_host_part_of_previous_ip=$((v_num_ptr - 1))
				v_current_ip_of_host_record="${v_subnet}.${v_host_part_of_current_ip}"
				v_previous_ip="${v_subnet}.${v_host_part_of_previous_ip}"
				v_ptr_zone="${v_file_ptr_zone}"
				return 0
			fi
		done
	}	
	
		
	for ((v_zone_number=1; v_zone_number<=v_total_ptr_zones; v_zone_number++))
	do
		eval "v_total_ips_in_ptr_zone${v_zone_number}=\$(sudo sed -n 's/^\([0-9]\+\).*/\1/p' \"\${v_ptr_zone${v_zone_number}}\" | wc -l)"

		v_total_ips_in_current_zone=$(eval "echo \${v_total_ips_in_ptr_zone${v_zone_number}}")

		v_current_zubnet=$(eval "echo \${v_subnet${v_zone_number}}")

		v_current_ptr_zone_file=$(eval "echo \${v_ptr_zone${v_zone_number}}")

		if [[ "${v_zone_number}" -eq 1 ]]
		then
			if [[ -z ${v_total_ips_in_current_zone} ]] || [[ ${v_total_ips_in_current_zone} -ne 255 ]]
			then
				fn_check_free_ip "${v_current_ptr_zone_file}" "1" "255" "${v_current_zubnet}"
				break
			else
				continue
			fi

		elif [[ "${v_zone_number}" -ne "${v_total_ptr_zones}" ]]
		then
			if [[ -z ${v_total_ips_in_current_zone} ]] || [[ ${v_total_ips_in_current_zone} -ne 256 ]]
			then
				fn_check_free_ip "${v_current_ptr_zone_file}" "0" "255" "${v_current_zubnet}"
				break
			else
				continue
			fi
		else
			if [[ -z ${v_total_ips_in_current_zone} ]] || [[ ${v_total_ips_in_current_zone} -ne 255 ]]
			then
				fn_check_free_ip "${v_current_ptr_zone_file}" "0" "254" "${v_current_zubnet}"
				break
			else
				${v_if_autorun_false} && echo -e "\n${v_RED}No more IPs available in ${v_network_and_cidr} Network of ${v_domain_name} domain! ${v_RESET}\n"
				return 255
			fi
		fi
	done


	${v_if_autorun_false} && echo -ne "\n${v_CYAN}Creating host record ${v_host_record}.${v_domain_name} . . . ${v_RESET}"

	############### A Record Creation Section ############################

	v_host_record_adjusted_space=$(printf "%-*s" 63 "${v_host_record}")

	v_add_host_record=$(echo "${v_host_record_adjusted_space} IN A ${v_current_ip_of_host_record}")

	if [[ "${v_previous_ip}" == ';PTR-Records' ]]
	then
		echo "${v_add_host_record}" | sudo tee -a "${v_fw_zone}" &>/dev/null
	else
		sudo sed -i "/${v_previous_ip}$/a \\${v_add_host_record}" "${v_fw_zone}"
	fi

	##################  End of  A Record Create Section ############################



	################## PTR Record Create  Section ###################################

	v_space_adjusted_host_part_of_current_ip=$(printf "%-*s" 3 "${v_host_part_of_current_ip}")

	v_add_ptr_record=$(echo "${v_space_adjusted_host_part_of_current_ip} IN PTR ${v_host_record}.${v_domain_name}.")

	if [[ "${v_previous_ip}" == ';PTR-Records' ]]
	then
		echo "${v_add_ptr_record}" | sudo tee -a "${v_ptr_zone}" &>/dev/null
	else
		sudo sed -i "/^${v_host_part_of_previous_ip} /a\\${v_add_ptr_record}" "${v_ptr_zone}"
	fi

	############# End of PTR Record Create Section #######################


	${v_if_autorun_false} && echo -ne "${v_GREEN}[ done ]${v_RESET}\n"

	fn_update_serial_number_of_zones

	if ${v_if_autorun_false}
	then
		fn_reload_named_dns_service
	fi
}


fn_delete_host_record() {

	if [[ "${3}" != "Automated-Execution" ]]
	then
		v_if_autorun_false=true	
	else
		v_if_autorun_false=false	
	fi

	fn_get_host_record "${1}" "delete"

	v_exit_status_fn_get_host_record=${?}

	if [[ ${v_exit_status_fn_get_host_record} -ne 0 ]]
	then
		return ${v_exit_status_fn_get_host_record}
	fi

	v_capture_host_record=$(sudo grep "^${v_host_record} " "${v_fw_zone}" ) 
	v_current_ip_of_host_record=$(sudo grep "^${v_host_record} " ${v_fw_zone} | awk '{print $NF}' | tr -d '[:space:]')
	v_capture_ptr_prefix=$(awk -F. '{ print $4 }' <<< ${v_current_ip_of_host_record} )

	fn_set_ptr_zone
	v_input_delete_confirmation="${2}"

	while :
	do
		if [[ ! ${v_input_delete_confirmation} == "-y" ]]
		then
			read -p "Please confirm deletion of records (y/n) : " v_confirmation
		else
			v_confirmation='y'
		fi

		if [[ ${v_confirmation} == "y" ]]
		then
			${v_if_autorun_false} && echo -ne "\n${v_CYAN}Deleting host record ${v_host_record}.${v_domain_name} . . . ${v_RESET}"

			sudo sed -i "/^${v_capture_ptr_prefix} /d" "${v_ptr_zone}"
			sudo sed -i "/^${v_capture_host_record}/d" "${v_fw_zone}"

			${v_if_autorun_false} && echo -ne "${v_GREEN}[ done ]${v_RESET}\n"

			fn_update_serial_number_of_zones

			if ${v_if_autorun_false}
			then
				fn_reload_named_dns_service
			fi

			break

		elif [[ ${v_confirmation} == "n" ]]
		then
			echo -e "\n${v_YELLOW}Cancelled without any changes ! ${v_RESET}\n"
			break

		else
			echo -e "\n${v_RED}Select only either (y/n) ! ${v_RESET}\n"
			continue

		fi
	done
}

fn_rename_host_record() {

	if [[ "${3}" != "Automated-Execution" ]]
	then
		v_if_autorun_false=true	
	else
		v_if_autorun_false=false	
	fi

	fn_get_host_record "${1}" "rename"

	v_exit_status_fn_get_host_record=${?}

	if [[ ${v_exit_status_fn_get_host_record} -ne 0 ]]
	then
		return ${v_exit_status_fn_get_host_record}
	fi

	v_host_record_exist=$(sudo grep "^$v_host_record " $v_fw_zone)
	v_current_ip_of_host_record=$(sudo grep "^$v_host_record " $v_fw_zone | cut -d "A" -f 2 | tr -d '[[:space:]]')

	fn_set_ptr_zone

	v_target_length=39
	v_num_spaces=$(( v_target_length - ${#v_rename_record} ))
	v_host_record_rename="${v_rename_record}$(printf '%*s' "$v_num_spaces")"
	v_host_record_rename=$(echo "$v_host_record_rename IN A ${v_current_ip_of_host_record}")
	
	while :
	do
		read -p "Please confirm to rename the record ${v_host_record}.${v_domain_name} to ${v_rename_record}.${v_domain_name} (y/n) : " v_confirmation
		if [[ $v_confirmation == "y" ]]
		then
			echo -ne "\n${v_CYAN}Renaming host record ${v_host_record}.${v_domain_name} to ${v_rename_record}.${v_domain_name} . . . ${v_RESET}"

			sudo sed -i "s/${v_host_record_exist}/${v_host_record_rename}/g" ${v_fw_zone}
			sudo sed -i "s/${v_host_record}.${v_domain_name}./${v_rename_record}.${v_domain_name}./g" ${v_ptr_zone}

			echo -ne "${v_GREEN}[ done ]${v_RESET}\n"
			
			fn_update_serial_number_of_zones

			if ${v_if_autorun_false}
			then
				fn_reload_named_dns_service
			fi

			break

		elif [[ $v_confirmation == "n" ]]
		then
			echo -e "\n${v_YELLOW}Cancelled without any changes ! ${v_RESET}\n"
			break

		else
			echo -e "\n${v_RED}Select only either (y/n) ! ${v_RESET}\n"
			continue

		fi
	done
}

fn_handle_multiple_host_record() {		

	v_host_list_file="${1}"
	v_action_required="${2}"

	clear

	fn_progress_title() {
	
		if [[ ${v_action_required} == "create" ]]
		then
			echo -e "#############################(DNS-MultiMaker)##############################"

		elif [[ ${v_action_required} == "delete" ]]
		then
			echo -e "###########################(DNS-MultiDestroyer)############################"
		fi
	}

	fn_progress_title
	
	if [ -z "${v_host_list_file}" ]
	then
		echo
		echo -ne "${v_CYAN}Name of the file containing the list of host records to ${v_action_required} : ${v_RESET}" 
		read -e v_host_list_file
	fi
	
	if [[ ! -f ${v_host_list_file} ]];then echo -e "\n${v_RED}File \"${v_host_list_file}\" doesn't exist!${v_RESET}\n";exit;fi 
	
	if [[ ! -s ${v_host_list_file} ]];then echo -e "\n${v_RED}File \"${v_host_list_file}\" is emty!${v_RESET}\n";exit;fi
	
	sed -i '/^[[:space:]]*$/d' ${v_host_list_file}
	
	sed -i 's/.${v_domain_name}.//g' ${v_host_list_file}
	
	sed -i 's/.${v_domain_name}//g' ${v_host_list_file}
	
	
	while :
	do
		echo -e "\n${v_CYAN}Records to be ${v_action_required^}d : ${v_RESET}\n"
	
		cat ${v_host_list_file}
	
		echo -ne "\n${v_YELLOW}Provide your confirmation to ${v_action_required} the above host records (y/n) : ${v_RESET}"
		
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
	
	> "${v_tmp_file_dnsmanager}"
	
	v_successfull="${v_GREEN}[ succeded ]${v_RESET}"
	v_failed="${v_RED}[ failed ]${v_RESET}"
	v_count_successfull=0
	v_count_failed=0
	
	v_pre_execution_serial_fw_zone=$(sudo grep ';Serial' ${v_fw_zone} | cut -d ";" -f 1 | tr -d '[:space:]')
	
	v_total_host_records=$(wc -l < "${v_host_list_file}")
	
	v_host_count=0
	
	while read -r v_host_record
	do
		clear

		fn_progress_title
	
		if [[ ${v_host_count} -le ${v_total_host_records} ]];then
	
			echo -e "################################( Running )################################"
			echo -e "${v_CYAN}Status     : [ ${v_host_count}/${v_total_host_records} ] host records have been processed${v_RESET}"
			echo -e "${v_GREEN}Successful : ${v_count_successfull}${v_RESET}"
			echo -ne "${v_RED}Failed     : ${v_count_failed}${v_RESET}"
		fi
	
		let v_host_count++
	
		echo -ne "\n\n${v_CYAN}Attempting to ${v_action_required} the host record ${v_host_record}.${v_domain_name} . . . ${v_RESET}"
	
		v_serial_fw_zone_pre_execution=$(sudo grep ';Serial' ${v_fw_zone} | cut -d ";" -f 1 | tr -d '[:space:]')
	
		if [[ ${v_action_required} == "create" ]]
                then
			fn_create_host_record "${v_host_record}" "Automated-Execution"
			var_exit_status=${?}

		elif [[ ${v_action_required} == "delete" ]]
		then
			fn_delete_host_record "${v_host_record}" -y "Automated-Execution"
			var_exit_status=${?}
		fi
	
		v_serial_fw_zone_post_execution=$(sudo grep ';Serial' ${v_fw_zone} | cut -d ";" -f 1 | tr -d '[:space:]')
	
	        v_fqdn="${v_host_record}.${v_domain_name}"
	
	        
		if [[ ${v_action_required} == "create" ]]
		then
			v_ip_address=$(sudo grep -w "^${v_host_record} "  "${v_fw_zone}" | awk '{print $NF}' | tr -d '[:space:]')
	
			if [[ -z "${v_ip_address}" ]]; then
	        		v_ip_address="N/A"
	    		fi
		fi
	
		if [[ ${v_action_required} == "create" ]]
		then
			v_details_of_host_record="${v_fqdn} ( ${v_ip_address} )${v_RESET}"

		elif [[ ${v_action_required} == "delete" ]]
		then
			v_details_of_host_record="${v_fqdn}${v_RESET}"
		fi
			
		if [[ ${var_exit_status} -eq 9 ]]
		then
	        	echo -e "${v_RED}Invalid-Host     ${v_details_of_host_record}" >> "${v_tmp_file_dnsmanager}"
			echo -ne "${v_failed}"
			let v_count_failed++ 
	
		elif [[ ${var_exit_status} -eq 8 ]]
		then
			if [[ ${v_action_required} == "create" ]]
                	then
				v_existence_state="Already-Exists  "

			elif [[ ${v_action_required} == "delete" ]]
			then
				v_existence_state="Doesn't-Exist   "
			fi

	        	echo -e "${v_YELLOW}${v_existence_state} ${v_details_of_host_record}" >> "${v_tmp_file_dnsmanager}"
			echo -ne "${v_failed}"
			let v_count_failed++
	
		elif [[ ${var_exit_status} -eq 255 ]]
		then
	        	echo -e "${v_RED}IP-Exhausted     ${v_details_of_host_record}" >> "${v_tmp_file_dnsmanager}"
			echo -ne "${v_failed}"
			let v_count_failed++
		else
			v_serial_fw_zone_post_execution=$(sudo grep ';Serial' ${v_fw_zone} | cut -d ";" -f 1 | tr -d '[:space:]')
	
			if [[ "${v_serial_fw_zone_pre_execution}" -ne "${v_serial_fw_zone_post_execution}" ]]
			then
				echo -e "${v_GREEN}${v_action_required^}d          ${v_details_of_host_record}" >> "${v_tmp_file_dnsmanager}"
				echo -ne "${v_successfull}"
				let v_count_successfull++
			else
	        		echo -e "${v_RED}Failed-to-${v_action_required^} ${v_details_of_host_record}" >> "${v_tmp_file_dnsmanager}"
				echo -ne "${v_failed}"
				let v_count_failed++
			fi
		fi
	
		if [[ ${v_host_count} -eq ${v_total_host_records} ]];then
	
			clear
			fn_progress_title
			echo -e "################################( Completed )##############################\n"
			echo -e "${v_CYAN}Status     : [ ${v_host_count}/${v_total_host_records} ] host records have been processed${v_RESET}"
			echo -e "${v_GREEN}Successful : ${v_count_successfull}${v_RESET}"
			echo -ne "${v_RED}Failed     : ${v_count_failed}${v_RESET}"
		fi
	
	
	done < "${v_host_list_file}"

	v_post_execution_serial_fw_zone=$(sudo grep ';Serial' ${v_fw_zone} | cut -d ";" -f 1 | tr -d '[:space:]')
	
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

	if [[ ${v_action_required} == "create" ]]
	then
		echo -e "${v_CYAN}Action-Taken     FQDN ( IPv4-Address )${v_RESET}"

	elif [[ ${v_action_required} == "delete" ]]
	then
		echo -e "${v_CYAN}Action-Taken     FQDN${v_RESET}"
	fi
	
	cat "${v_tmp_file_dnsmanager}"
	
	echo
	
	rm -f "${v_tmp_file_dnsmanager}"
}


fn_main_menu() {

	v_domain_if_present=$(if [ ! -z "${v_domain_name}" ];then echo -n "${v_domain_name}";else echo '[not-yet-configured]';fi)
	v_domain_if_present=$(printf "%-*s" 54 "${v_domain_if_present}")

cat << EOF
##################################################################
#-------------------------[ DNS-MANAGER ]------------------------#
# Domain : ${v_domain_if_present}#
#----------------------------------------------------------------#
# 1) Create a DNS host record                                    #
# 2) Delete a DNS host record                                    #
# 3) Rename an existing DNS host record                          #
# 4) Create multiple DNS host records provided in a file         #
# 5) Delete multiple DNS host records provided in a file         #
#----------------------------------------------------------------#
# 0) Configure local dns server and domain if not done already   #
#----------------------------------------------------------------#
# q) Quit without any changes                                    #
#----------------------------------------------------------------#
EOF

read -p "# Please Select an Option from Above : " var_function

case ${var_function} in
	0) 	
		fn_configure_named_dns_server
		exit
		;;
	1)
		fn_check_existence_of_domain
		fn_create_host_record
		exit
		;;
	2)
		fn_check_existence_of_domain
		fn_delete_host_record
		exit
		;;
	3)
		fn_check_existence_of_domain
		fn_rename_host_record
		exit
		;;
	4)
		fn_check_existence_of_domain
		fn_handle_multiple_host_record "${2}" "create"
		exit
		;;
	5)
		fn_check_existence_of_domain
		fn_handle_multiple_host_record "${2}" "delete"
		exit
		;;
	q)
		exit
		;;
	*)
		echo -e "\nInvalid Option! Try Again! \n"
		fn_main_menu
		;;
esac

}

if [ ! -z "${1}" ]
then

	case "${1}" in
		-c)
			fn_check_existence_of_domain
			fn_create_host_record "${2}"
			exit
			;;
		-d)
			fn_check_existence_of_domain
			fn_delete_host_record "${2}"
			exit
			;;
		-r)
			fn_check_existence_of_domain
			fn_rename_host_record "${2}"
			exit
			;;
		-cf)
			fn_check_existence_of_domain
			fn_handle_multiple_host_record "${2}" "create"
			exit
			;;
		-df)
			fn_check_existence_of_domain
			fn_handle_multiple_host_record "${2}" "delete"
			exit
			;;

		--setup)
			fn_configure_named_dns_server
			exit
			;;

		*)
			if [[ ! "${1}" =~ ^-h|--help$ ]]
			then
				echo "Invalid Option \"${1}\"!"
			fi

			cat << EOF
Usage: dnsmanager [ option ] [ DNS host record ]
Use one of the following Options :
	-c      To create a DNS host record
	-d      To delete a DNS host record
	-r      To rename an existing DNS host record
	-cf     To create multiple DNS host records provided in a file 
	-df     To delete multiple DNS host records provided in a file
	--setup	To configure local dns server and domain if not done already
[ Or ]
Run dnsmanager utility without any arguements to get menu driven actions.

EOF
			;;
	esac
else
	fn_main_menu
fi
