#!/bin/bash

if [[ "${UID}" -ne 0 ]]
then
    echo -e "${v_RED}\nRun with sudo or run from root account ! ${v_RESET}\n"
    exit 1
fi

# Define color codes
v_RED='\033[0;31m'      # Red
v_GREEN='\033[0;32m'    # Green
v_YELLOW='\033[0;33m'   # Yellow
v_BLUE='\033[0;34m'     # Blue
v_CYAN='\033[0;36m'     # Cyan
v_MAGENTA='\033[0;35m'  # Magenta
v_RESET='\033[0m'       # Reset to default color

v_tmp_file_dnsbinder="/tmp/tmp_file_dnsbinder"

v_domain_name=$(if [ -f /etc/named.conf ];then grep 'zones-are-managed-by-dnsbinder' /etc/named.conf | awk '{print $2}';fi)
dnsbinder_network=$(if [ -f /etc/named.conf ];then grep 'dnsbinder-network' /etc/named.conf | awk '{print $3}';fi)
var_zone_dir='/var/named/zone-files'
v_fw_zone="${var_zone_dir}/${v_domain_name}-forward.db"

fn_check_existence_of_domain() {
	if [ -z "${v_domain_name}" ]
	then
		echo -e "\n${v_RED}> Seems like bind dns service is not being handled by dnsbinder! ${v_RESET}\n"
		echo -e "${v_YELLOW}> Please check and setup the same using dnsbinder utility itself! ${v_RESET}\n"
		exit
	fi
}

fn_calculate_network_cidr() {
    local ipv4_address="${1}"
    local subnet_mask="${2}"

    IFS=. read -r ipv4_octet1 ipv4_octet2 ipv4_octet3 ipv4_octet4 <<< "${ipv4_address}"
    IFS=. read -r mask_octet1 mask_octet2 mask_octet3 mask_octet4 <<< "${subnet_mask}"

    # Perform bitwise AND operation using arithmetic expansion
    local network_octet1=$((ipv4_octet1 & mask_octet1))
    local network_octet2=$((ipv4_octet2 & mask_octet2))
    local network_octet3=$((ipv4_octet3 & mask_octet3))
    local network_octet4=$((ipv4_octet4 & mask_octet4))

    local network_cidr=0
    for octet in ${mask_octet1} ${mask_octet2} ${mask_octet3} ${mask_octet4}; do
	for bit in {7..0}; do
            if (( (octet >> bit) & 1 )); then
                ((network_cidr++))
            fi
        done
    done
    local ipv4_address="${1}"
    local subnet_mask="${2}"

    IFS=. read -r ipv4_octet1 ipv4_octet2 ipv4_octet3 ipv4_octet4 <<< "${ipv4_address}"
    IFS=. read -r mask_octet1 mask_octet2 mask_octet3 mask_octet4 <<< "${subnet_mask}"

    # Perform bitwise AND operation using arithmetic expansion
    local network_octet1=$((ipv4_octet1 & mask_octet1))
    local network_octet2=$((ipv4_octet2 & mask_octet2))
    local network_octet3=$((ipv4_octet3 & mask_octet3))
    local network_octet4=$((ipv4_octet4 & mask_octet4))

    echo "${network_octet1}.${network_octet2}.${network_octet3}.${network_octet4}/${network_cidr}"
}

fn_split_network_into_cidr24subnets() {

	v_network_and_cidr="${1}"

	# Function to convert an IP address to a number
	fn_ip_to_int() {
    		local ipv4_address=${1}
    		local ipv4_octet1 ipv4_octet2 ipv4_octet3 ipv4_octet4
    		IFS=. read -r ipv4_octet1 ipv4_octet2 ipv4_octet3 ipv4_octet4 <<< "${ipv4_address}"
    		echo "$((ipv4_octet1 * 256 ** 3 + ipv4_octet2 * 256 ** 2 + ipv4_octet3 * 256 + ipv4_octet4))"
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

	if [[ -z "${v_network_and_cidr}" ]];
	then
		if "${server_is_hosted_on_gcp}" ; then
			gcp_subnet_mask=$(curl -sH "Metadata-Flavor: Google" http://169.254.169.254/computeMetadata/v1/instance/network-interfaces/0/subnetmask)
			v_network_and_cidr=$(fn_calculate_network_cidr "${v_primary_ip}" "${gcp_subnet_mask}")
		else
			v_network_and_cidr=$(ip r | grep -v default | grep "${v_primary_interface}" | head -n 1 | awk '{ print $1 }')
		fi
	fi

	# Extract network and CIDR from input
	v_network=$(echo "${v_network_and_cidr}" | cut -d "/" -f 1)
	v_cidr=$(echo "${v_network_and_cidr}" | cut -d "/" -f 2)
	
	# Check if CIDR is valid
	if ! [[ "${v_cidr}" =~ ^[0-9]+$ ]] || [ "${v_cidr}" -lt 16 ] || [ "${v_cidr}" -gt 24 ]; then
    		echo "Invalid CIDR. Only Networks with CIDR between 16 and 24 is allowed."
    		exit 1
	fi
	
	# Generate and display the subnets
	v_splited_subnets=$(fn_generate_subnets "${v_network}" "${v_cidr}" |  sed "s/\.0\/24//")
}

if [[ ! -z "${dnsbinder_network}" ]]; then
	v_splited_subnets=$(ls "${var_zone_dir}"/*-reverse.db | awk -F'/' '{print $NF}' | awk -F'.' '{print $1"."$2"."$3}' | sort -n)
	v_total_ptr_zones=$(ls "${var_zone_dir}"/*-reverse.db | wc -l)

	v_zone_number=1
	for v_subnet_part in ${v_splited_subnets}
	do
    		eval "v_ptr_zone${v_zone_number}=\"${var_zone_dir}/${v_subnet_part}.${v_domain_name}-reverse.db\""
    		eval "v_subnet${v_zone_number}=\"${v_subnet_part}\""
    		let v_zone_number++
	done
fi

fn_configure_named_dns_server() {

	server_is_hosted_on_gcp="false"

	if grep -q -i google <<< $(sudo dmidecode -s system-manufacturer)
	then
		server_is_hosted_on_gcp="true"
	fi

	if [ ! -z "${v_domain_name}" ]
	then
		echo -e "\n${v_YELLOW}> Seems like bind dns server and domain is already setup and managed by dnsbinder! ${v_RESET}\n"
		echo -e "${v_GREEN}> Domain '${v_domain_name}' is already being managed by dnsbinder! ${v_RESET}\n"
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

	v_dns_host_short_name=$(hostname -s)
	v_primary_interface=$(ip r | grep default | awk '{ print $5 }')
	v_primary_ip=$(ip r | grep -v default | grep "${v_primary_interface}" | head -n 1 | awk '{ print $9 }')
	v_network_gateway=$(ip r | grep default | awk '{ print $3 }')

	fn_split_network_into_cidr24subnets

	echo -e "${v_GREEN}[ done ]${v_RESET}"

	echo -ne "\n${v_CYAN}Checking whether required bind dns packages are installed . . . ${v_RESET}"

	if rpm -q bind bind-utils &>/dev/null 
	then
		echo -e "${v_GREEN}[ already installed ]${v_RESET}"
	else
		echo -e "${v_YELLOW}[ not yet installed ]${v_RESET}"

		echo -ne "\n${v_CYAN}Installing the required bind dns packages . . . ${v_RESET}"

		if dnf install bind bind-utils -y &>/dev/null
		then
			echo -e "${v_GREEN}[ installed ]${v_RESET}"
		else
			echo -e "${v_RED}[ failed to install ] ${v_RESET}"
			echo -e "\n${v_RED}Try installing the packages bind and bind-utils manually then try the script again! \n${v_RESET}"
			exit
		fi
	fi

	echo -ne "\n${v_CYAN}Taking backup of named.conf . . . ${v_RESET}"

	cp -p /etc/named.conf /etc/named.conf_bkp_by_dnsbinder
	
	echo -e "${v_GREEN}[ done ]${v_RESET}"

	echo -ne "\n${v_CYAN}Configuring named.conf . . . ${v_RESET}"

	sed -i "s/listen-on port 53 {\s*127.0.0.1;\s*};/listen-on port 53 { 127.0.0.1; ${v_primary_ip}; };/" /etc/named.conf

	sed -i "s/allow-query\s*{\s*localhost;\s*};/allow-query     { localhost; ${v_network}\/${v_cidr}; };/" /etc/named.conf

	sed -i '/dnssec-validation yes;/d' /etc/named.conf


	if "${server_is_hosted_on_gcp}" ; then
		sed -i '/recursion yes;/a # BEGIN google-dns-servers-as-forwarders\n\n        forwarders {\n                169.254.169.254;\n        };\n\n        dnssec-validation no;\n# END google-dns-servers-as-forwarders' /etc/named.conf
	else
		sed -i '/recursion yes;/a # BEGIN google-dns-servers-as-forwarders\n\n        forwarders {\n                8.8.8.8;\n                8.8.4.4;\n        };\n\n        dnssec-validation no;\n# END google-dns-servers-as-forwarders' /etc/named.conf
	fi


	tee -a /etc/named.conf > /dev/null << EOF
# BEGIN zones-of-${v_given_domain}-domain
# dnsbinder-network ${v_network}/${v_cidr} 
# ${v_given_domain} zones-are-managed-by-dnsbinder
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
		if [[ -z "${v_first_subnet_part}" ]]; then
			v_first_subnet_part="${v_subnet_part}"
		fi

		v_reverse_subnet_part=$(echo "${v_subnet_part}" | awk -F. '{print $3"."$2"."$1}')
		tee -a /etc/named.conf > /dev/null << EOF
zone "${v_reverse_subnet_part}.in-addr.arpa" IN {
             type master;
             file "zone-files/${v_subnet_part}.${v_given_domain}-reverse.db";
             allow-update { none; };
};
EOF
		v_last_subnet_part="${v_subnet_part}"
	done

	echo -e "# END zones-of-${v_given_domain}-domain" | tee -a /etc/named.conf > /dev/null

	echo -e "${v_GREEN}[ done ]${v_RESET}"

	echo -ne "\n${v_CYAN}Creating and configuring zone files . . . ${v_RESET}"

	mkdir -p "${var_zone_dir}"

	fn_update_dns_server_data_to_zone_file() {
		v_file_name="${1}"
		tee -a "${v_file_name}" > /dev/null << EOF
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
	echo -e "\n;A-Records" | tee -a "${v_zone_file_name}" > /dev/null

	v_gateway_adjusted_space=$(printf "%-*s" 63 "gateway")

	echo -e "${v_gateway_adjusted_space} IN A ${v_first_subnet_part}.1" | tee -a  "${v_zone_file_name}" > /dev/null

	v_dns_host_short_name_adjusted_space=$(printf "%-*s" 63 "${v_dns_host_short_name}")
	
	echo -e "${v_dns_host_short_name_adjusted_space} IN A ${v_primary_ip}" | tee -a "${v_zone_file_name}" > /dev/null

	v_broadcast_adjusted_space=$(printf "%-*s" 63 "broadcast")

	echo -e "${v_broadcast_adjusted_space} IN A ${v_last_subnet_part}.255" | tee -a  "${v_zone_file_name}" > /dev/null

	echo -e "\n;CNAME-Records" | tee -a "${v_zone_file_name}" > /dev/null

	for v_subnet_part in ${v_splited_subnets}
	do
		v_zone_file_name="${var_zone_dir}/${v_subnet_part}.${v_given_domain}-reverse.db"
		fn_update_dns_server_data_to_zone_file "${v_zone_file_name}"
		echo -e "\n;PTR-Records" | tee -a "${v_zone_file_name}" > /dev/null
		if [[ "${v_subnet_part}" == "${v_first_subnet_part}" ]]
		then
			echo -e "1   IN PTR gateway.${v_given_domain}." | tee -a "${v_zone_file_name}" > /dev/null
			v_get_ip_part_primary_ip=$(echo "${v_primary_ip}" | awk -F. '{print $4}')
			v_ip_part_primary_ip_adjusted_space=$(printf "%-*s" 3 "${v_get_ip_part_primary_ip}")
			echo -e "${v_ip_part_primary_ip_adjusted_space} IN PTR ${v_dns_host_short_name}.${v_given_domain}." | tee -a "${v_zone_file_name}" > /dev/null
		elif [[ "${v_subnet_part}" == "${v_last_subnet_part}" ]]
		then
			echo -e "255 IN PTR broadcast.${v_given_domain}." | tee -a "${v_zone_file_name}" > /dev/null
		fi
	done

	echo -e "${v_GREEN}[ done ]${v_RESET}"

	echo -ne "\n${v_CYAN}Enabling and starting named DNS Service . . . ${v_RESET}"

	systemctl enable --now named &>/dev/null	
	
	echo -e "${v_GREEN}[ done ]${v_RESET}"

	echo -ne "\n${v_CYAN}Doing a final restart of named DNS Service . . . ${v_RESET}"

	systemctl restart named &>/dev/null	

	echo -e "${v_GREEN}[ done ]${v_RESET}"

	if ! "${server_is_hosted_on_gcp}" ; then

		echo -ne "\n${v_CYAN}Updating Network Manager to point the local dns server and domain . . . ${v_RESET}"

		v_active_connection_name=$(nmcli connection show --active | grep "${v_primary_interface}" | head -n 1 | awk '{ print $1 }')

		nmcli connection modify "${v_active_connection_name}" ipv4.dns-search "${v_given_domain}" &>/dev/null

		nmcli connection modify "${v_active_connection_name}" ipv4.dns "127.0.0.1,8.8.8.8,8.8.4.4"  &>/dev/null

		nmcli connection reload "${v_active_connection_name}" &>/dev/null

		nmcli connection up "${v_active_connection_name}" &>/dev/null

		echo -e "${v_GREEN}[ done ]${v_RESET}"
	fi

	echo -e "\n${v_GREEN}All done! Your domain \"${v_given_domain}\" with DNS server ${v_primary_ip} [ ${v_dns_host_short_name}.${v_given_domain}  ] has been configured.${v_RESET}"
	echo -e "${v_YELLOW}Now you could manage the domain  \"${v_given_domain}\" with dnsbinder utility from command line.\n${v_RESET}"

	cp -p $(pwd)/$0 /usr/bin/dnsbinder

	exit
}

fn_instruct_on_valid_host_record() {
	echo -e "\n${v_RED}> Only letters, numbers, and hyphens are allowed."
	echo -e "> Hyphens cannot appear at the start or end."
	echo -e "> The total length must be between 1 and 63 characters."
	echo -e "> The domain name '${v_domain_name}' will be appended if not present."
	echo -e "> Follows the format defined in RFC 1035.${v_RESET}\n"
	exit 1
}

fn_get_host_record() {
	v_input_host="${1}"
	v_action_requested="${2}"

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

	if grep "^${v_host_record} "  "${v_fw_zone}" &>/dev/null
	then 
		if [[ "${v_action_requested}" == "create" ]]
		then
			${v_if_autorun_false} && echo -e "\n${v_RED}Host record for ${v_host_record}.${v_domain_name} already exists ! ${v_RESET}\n"
			${v_if_autorun_false} && echo -e "${v_RED}Nothing to do ! Exiting !  ${v_RESET}\n"
			return 8

		elif [[ "${v_action_requested}" == "rename" ]]
		then
			fn_get_host_record_from_user

			if grep "^${v_rename_record} "  "${v_fw_zone}" &>/dev/null
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

	v_current_serial_fw_zone=$(grep ';Serial' "${v_fw_zone}" | cut -d ";" -f 1 | tr -d '[:space:]')
	v_set_new_serial_fw_zone=$(( v_current_serial_fw_zone + 1 ))
	sed -i "/;Serial/s/${v_current_serial_fw_zone}/${v_set_new_serial_fw_zone}/g" "${v_fw_zone}"

	v_current_serial_ptr_zone=$(grep ';Serial' "${v_ptr_zone}" | cut -d ";" -f 1 | tr -d '[:space:]')
	v_set_new_serial_ptr_zone=$(( v_current_serial_ptr_zone + 1 ))
	sed -i "/;Serial/s/${v_current_serial_ptr_zone}/${v_set_new_serial_ptr_zone}/g" "${v_ptr_zone}"

	${v_if_autorun_false} && echo -ne "${v_GREEN}[ done ]${v_RESET}\n"
}


fn_reload_named_dns_service() {

	echo -ne "\n${v_CYAN}Reloading the DNS service ( named ) . . . ${v_RESET}"

	systemctl reload named &>/dev/null

	if systemctl is-active named &>/dev/null;
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

fn_get_ipv4_address() {

	ipv4_provided="${1}"

	fn_validate_ipv4_address() {
    		local ipv4_provided="$1"
    		local octet

    		# Use a regex pattern for IPv4 validation
    		if [[ "$ipv4_provided" =~ ^([0-9]{1,3})\.([0-9]{1,3})\.([0-9]{1,3})\.([0-9]{1,3})$ ]]; then
        		# Check if each octet is in the range 0-255
        		for octet in ${BASH_REMATCH[@]:1}; do
            			if (( octet < 0 || octet > 255 )); then
                			echo "Invalid input provided for IPv4 Address !"
					fn_get_ipv4_address
            			fi
        		done
    		else
    			echo "Invalid input provided for IPv4 Address !"
			fn_get_ipv4_address
    		fi
	}

	if [[ -z "${ipv4_provided}" ]]; then
		read -p "Provide the required IPv4 Address ( within ${dnsbinder_network} ) : " ipv4_provided
	fi

	fn_validate_ipv4_address "${ipv4_provided}"

	# Convert IP to decimal
	fn_convert_ip_to_decimal() {
    		IFS=. read -r ipv4_octet1 ipv4_octet2 ipv4_octet3 ipv4_octet4 <<< "${1}"
    		echo $(( (ipv4_octet1 << 24) + (ipv4_octet2 << 16) + (ipv4_octet3 << 8) + ipv4_octet4 ))
	}

	# Function to check if an IP is within a CIDR range
	fn_check_whether_ip_in_range() {
    		local ipv4_provided="${1}"
    		local dnsbinder_network="${2}"

    		# Split network into base IP and prefix length
    		IFS='/'
    		read -r network_base network_mask <<< "${dnsbinder_network}"

    		# Convert IPs to decimal
    		decimal_value_of_ipv4=$(fn_convert_ip_to_decimal "${ipv4_provided}")
    		decimal_value_of_network=$(fn_convert_ip_to_decimal "${network_base}")

    		# Calculate network range
    		range_size=$(( 32 - network_mask ))
    		net_start=$(( decimal_value_of_network & (0xFFFFFFFF << range_size) ))
    		net_end=$(( net_start | ((1 << range_size) - 1) ))

    		# Check if IP falls within range
    		if (( decimal_value_of_ipv4 >= net_start && decimal_value_of_ipv4 <= net_end )); then
        		return 0  # IP is in range
    		else
        		return 1  # IP is NOT in range
    		fi
	}

	while :
	do
		if fn_check_whether_ip_in_range "${ipv4_provided}" "${dnsbinder_network}"; then
			break
		else
			echo "Provided IPv4 address is not within the network ${dnsbinder_network} !"
			fn_get_ipv4_address
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

	if [ ! -z "${specific_ipv4_requested}" ] ; then
		fn_get_ipv4_address "${2}"
	fi

	fn_check_free_ip() {

		local v_file_ptr_zone="${1}"
		local v_start_ip="${2}"
		local v_max_ip="${3}"
		local v_subnet="${4}"
		local v_capture_list_of_ips=$(sed -n 's/^\([0-9]\+\).*/\1/p' "${v_file_ptr_zone}")
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
		v_current_ptr_zone_file="v_ptr_zone${v_zone_number}"

		v_current_ptr_zone_file="${!v_current_ptr_zone_file}"

		v_total_ips_in_current_zone=$(sed -n 's/^\([0-9]\+\).*/\1/p' "${v_current_ptr_zone_file}" | wc -l)

		v_current_subnet="v_subnet${v_zone_number}"

		v_current_subnet="${!v_current_subnet}"

		if [[ ! -z "${ipv4_provided}" ]]
		then
			IFS='.' read -r ipv4_octet1 ipv4_octet2 ipv4_octet3 ipv4_octet4 <<< "${ipv4_provided}"
			subnet_part_of_ipv4_provided="${ipv4_octet1}.${ipv4_octet2}.${ipv4_octet3}"
			host_part_of_ipv4_provided="${ipv4_octet4}"
			
			if [[ "${v_current_subnet}" == "${subnet_part_of_ipv4_provided}" ]]
			then	
				if grep "^${host_part_of_ipv4_provided} " "${v_current_ptr_zone_file}" &>/dev/null  	
				then
					echo "Record already exists for provided IPv4 address ${ipv4_provided} !"
					host  ${ipv4_provided}
					echo "Please try again with another IPv4 address !"
					exit 1
				else
					mapfile -t v_list_of_ips_in_zone < <(sed -n 's/^\([0-9]\+\).*/\1/p' "${v_current_ptr_zone_file}" | sort -n)
					v_host_part_of_current_ip="${host_part_of_ipv4_provided}"
					v_current_ip_of_host_record="${subnet_part_of_ipv4_provided}.${v_host_part_of_current_ip}"
					v_ptr_zone="${v_current_ptr_zone_file}"
					if [[ ! -z "${v_list_of_ips_in_zone[@]}" ]]
					then
						v_count_less=0
						for ptr_ip in "${v_list_of_ips_in_zone[@]}"
						do
							if [[ "${ptr_ip}" -lt "${v_host_part_of_current_ip}" ]]
							then
								v_host_part_of_previous_ip="${ptr_ip}"
								((v_count_less++))
								continue
							else
								break
							fi
						done

						if [[ "${v_count_less}" -eq 0 ]]
						then
							v_previous_ip=';PTR-Records'
						else	
							v_previous_ip="${subnet_part_of_ipv4_provided}.${v_host_part_of_previous_ip}"
						fi
					else
						v_previous_ip=';PTR-Records'
					fi
				fi
			else
				continue
			fi

		else
			if [[ "${v_zone_number}" -eq 1 ]]
			then
				if [[ -z ${v_total_ips_in_current_zone} ]] || [[ ${v_total_ips_in_current_zone} -ne 255 ]]
				then
					fn_check_free_ip "${v_current_ptr_zone_file}" "1" "255" "${v_current_subnet}"
					break
				else
					continue
				fi

			elif [[ "${v_zone_number}" -ne "${v_total_ptr_zones}" ]]
			then
				if [[ -z ${v_total_ips_in_current_zone} ]] || [[ ${v_total_ips_in_current_zone} -ne 256 ]]
				then
					fn_check_free_ip "${v_current_ptr_zone_file}" "0" "255" "${v_current_subnet}"
					break
				else
					continue
				fi
			else
				if [[ -z ${v_total_ips_in_current_zone} ]] || [[ ${v_total_ips_in_current_zone} -ne 255 ]]
				then
					fn_check_free_ip "${v_current_ptr_zone_file}" "0" "254" "${v_current_subnet}"
					break
				else
					${v_if_autorun_false} && echo -e "\n${v_RED}No more IPs available in ${v_network_and_cidr} Network of ${v_domain_name} domain! ${v_RESET}\n"
					return 255
				fi
			fi
		fi
	done


	${v_if_autorun_false} && echo -ne "\n${v_CYAN}Creating host record ${v_host_record}.${v_domain_name} . . . ${v_RESET}"

	############### A Record Creation Section ############################

	v_host_record_adjusted_space=$(printf "%-*s" 63 "${v_host_record}")

	v_add_host_record=$(echo "${v_host_record_adjusted_space} IN A ${v_current_ip_of_host_record}")

	if [[ "${v_previous_ip}" == ';PTR-Records' ]]
	then
		sed -i "/^broadcast /i \\${v_add_host_record}" "${v_fw_zone}"
	else
		sed -i "/${v_previous_ip}$/a \\${v_add_host_record}" "${v_fw_zone}"
	fi

	##################  End of  A Record Create Section ############################



	################## PTR Record Create  Section ###################################

	v_space_adjusted_host_part_of_current_ip=$(printf "%-*s" 3 "${v_host_part_of_current_ip}")

	v_add_ptr_record=$(echo "${v_space_adjusted_host_part_of_current_ip} IN PTR ${v_host_record}.${v_domain_name}.")

	if [[ "${v_previous_ip}" == ';PTR-Records' ]]
	then
		sed -i "/^;PTR-Records/a\\${v_add_ptr_record}" "${v_ptr_zone}"
	else
		sed -i "/^${v_host_part_of_previous_ip} /a\\${v_add_ptr_record}" "${v_ptr_zone}"
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

	v_capture_host_record=$(grep "^${v_host_record} " "${v_fw_zone}" ) 
	v_current_ip_of_host_record=$(grep "^${v_host_record} " ${v_fw_zone} | awk '{print $NF}' | tr -d '[:space:]')
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

			sed -i "/^${v_capture_ptr_prefix} /d" "${v_ptr_zone}"
			sed -i "/^${v_capture_host_record}/d" "${v_fw_zone}"

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

	v_host_record_exist=$(grep "^$v_host_record " $v_fw_zone)
	v_current_ip_of_host_record=$(grep "^$v_host_record " $v_fw_zone | cut -d "A" -f 2 | tr -d '[[:space:]]')

	fn_set_ptr_zone

	v_host_record_rename=$(printf "%-*s" 63 "${v_rename_record}")
	v_host_record_rename=$(echo "$v_host_record_rename IN A ${v_current_ip_of_host_record}")
	
	while :
	do
		read -p "Please confirm to rename the record ${v_host_record}.${v_domain_name} to ${v_rename_record}.${v_domain_name} (y/n) : " v_confirmation
		if [[ $v_confirmation == "y" ]]
		then
			echo -ne "\n${v_CYAN}Renaming host record ${v_host_record}.${v_domain_name} to ${v_rename_record}.${v_domain_name} . . . ${v_RESET}"

			sed -i "s/${v_host_record_exist}/${v_host_record_rename}/g" ${v_fw_zone}
			sed -i "s/${v_host_record}.${v_domain_name}./${v_rename_record}.${v_domain_name}./g" ${v_ptr_zone}

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

	touch /tmp/dnsbinder_fn_handle_multiple_host_record.lock

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
	
	> "${v_tmp_file_dnsbinder}"
	
	v_successfull="${v_GREEN}[ succeded ]${v_RESET}"
	v_failed="${v_RED}[ failed ]${v_RESET}"
	v_count_successfull=0
	v_count_failed=0
	
	v_pre_execution_serial_fw_zone=$(grep ';Serial' ${v_fw_zone} | cut -d ";" -f 1 | tr -d '[:space:]')
	
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
	
		v_serial_fw_zone_pre_execution=$(grep ';Serial' ${v_fw_zone} | cut -d ";" -f 1 | tr -d '[:space:]')
	
		if [[ ${v_action_required} == "create" ]]
                then
			fn_create_host_record "${v_host_record}" "Automated-Execution"
			var_exit_status=${?}

		elif [[ ${v_action_required} == "delete" ]]
		then
			fn_delete_host_record "${v_host_record}" -y "Automated-Execution"
			var_exit_status=${?}
		fi
	
		v_serial_fw_zone_post_execution=$(grep ';Serial' ${v_fw_zone} | cut -d ";" -f 1 | tr -d '[:space:]')
	
	        v_fqdn="${v_host_record}.${v_domain_name}"
	
	        
		if [[ ${v_action_required} == "create" ]]
		then
			v_ip_address=$(grep -w "^${v_host_record} "  "${v_fw_zone}" | awk '{print $NF}' | tr -d '[:space:]')
	
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
	        	echo -e "${v_RED}Invalid-Host     ${v_details_of_host_record}" >> "${v_tmp_file_dnsbinder}"
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

	        	echo -e "${v_YELLOW}${v_existence_state} ${v_details_of_host_record}" >> "${v_tmp_file_dnsbinder}"
			echo -ne "${v_failed}"
			let v_count_failed++
	
		elif [[ ${var_exit_status} -eq 255 ]]
		then
	        	echo -e "${v_RED}IP-Exhausted     ${v_details_of_host_record}" >> "${v_tmp_file_dnsbinder}"
			echo -ne "${v_failed}"
			let v_count_failed++
		else
			v_serial_fw_zone_post_execution=$(grep ';Serial' ${v_fw_zone} | cut -d ";" -f 1 | tr -d '[:space:]')
	
			if [[ "${v_serial_fw_zone_pre_execution}" -ne "${v_serial_fw_zone_post_execution}" ]]
			then
				echo -e "${v_GREEN}${v_action_required^}d          ${v_details_of_host_record}" >> "${v_tmp_file_dnsbinder}"
				echo -ne "${v_successfull}"
				let v_count_successfull++
			else
	        		echo -e "${v_RED}Failed-to-${v_action_required^} ${v_details_of_host_record}" >> "${v_tmp_file_dnsbinder}"
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

	v_post_execution_serial_fw_zone=$(grep ';Serial' ${v_fw_zone} | cut -d ";" -f 1 | tr -d '[:space:]')
	
	if [[ "${v_pre_execution_serial_fw_zone}" -ne "${v_post_execution_serial_fw_zone}" ]]
	then
		echo -e "\n\n${v_YELLOW}Reloading the DNS service ( named ) for the changes to take effect . . .${v_RESET}\n"
	
		systemctl reload named &>/dev/null
	
		if systemctl is-active named &>/dev/null;
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
	
	cat "${v_tmp_file_dnsbinder}"
	
	echo
	
	rm -f "${v_tmp_file_dnsbinder}"

	rm -f /tmp/dnsbinder_fn_handle_multiple_host_record.lock
}

fn_get_cname_record() {

	v_action_requested="${1}"

	fn_get_cname_record_from_user() {
		while :
		do
			if [ -z "${v_input_cname}" ]
			then
				if [[ "${v_action_requested}" == "create" ]]
				then
					read -p "Please Enter the name of CNAME record to ${v_action_requested} : " v_input_cname
				elif  [[ "${v_action_requested}" == "delete" ]]
				then
					read -p "Please Enter the name of CNAME record to ${v_action_requested} : " v_input_cname
				fi
			fi
				
			v_input_cname="${v_input_cname%.${v_domain_name}.}"  
			v_input_cname="${v_input_cname%.${v_domain_name}}"

			if [[ ! "${#v_input_cname}" -le 63 ]] || [[ ! "${v_input_cname}" =~ ^[[:alnum:]]([-[:alnum:]]*[[:alnum:]])$ ]]
	       		then
				fn_instruct_on_valid_host_record
  			fi

			break
		done
	}

	fn_get_hostname_record_from_user() {
		while :
		do
			if [ -z "${v_input_hostname}" ]
			then
				read -p "Please Enter the host record to which CNAME \"${v_input_cname}\" is required : " v_input_hostname
			fi
				
			v_input_hostname="${v_input_hostname%.${v_domain_name}.}"  
			v_input_hostname="${v_input_hostname%.${v_domain_name}}"

			if [[ ! "${#v_input_hostname}" -le 63 ]] || [[ ! "${v_input_hostname}" =~ ^[[:alnum:]]([-[:alnum:]]*[[:alnum:]])$ ]]
	       		then
				fn_instruct_on_valid_host_record
  			fi
		done
	}

	fn_get_cname_record_from_user

	if [[ "${v_action_requested}" == "create" ]]
	then
		fn_get_hostname_record_from_user

		if grep -q "^${v_input_cname} " <<< $(sed -n '/;CNAME-Records/{$!p;}' "${v_fw_zone}")
		then 
			echo "CNAME record for ${v_input_cname} already exists! \n"
			exit 1
		elif ! grep -q "^${v_input_hostname} "  <<< $(sed -n '/;A-Records/,/;CNAME-Records/{//!p;}' "${v_fw_zone}")
		then
			echo "Provided host record \"${v_input_hostname}\" doesn't exist! "
			exit 1
		elif grep -q "^${v_input_cname} "  <<< $(sed -n '/;A-Records/,/;CNAME-Records/{//!p;}' "${v_fw_zone}")
		then
			echo "Conflict! Already a host record exists with the same name of CNAME \"^${v_input_cname}\" !"
			exit 1
		fi
	fi

	if [[ "${v_action_requested}" == "delete" ]]
	then
		if ! grep -q "^${v_input_cname} " <<< $(sed -n '/;CNAME-Records/{$!p;}' "${v_fw_zone}")
		then 
			echo "CNAME record for ${v_input_cname} doesn't exist! \n"
			exit 1
		fi
	fi
}

fn_create_cname_record() {
	v_input_cname="${1}"
	v_input_hostname="${2}"
	
	fn_get_cname_record "create"

	echo -ne "\n${v_CYAN}Creating CNAME record \"${v_input_cname}.${v_domain_name}\" for the host record \"${v_input_hostname}.${v_domain_name}\" . . . ${v_RESET}"

	v_cname_adjusted_space=$(printf "%-*s" 63 "${v_input_cname}")

	v_name_record=$(echo "${v_cname_adjusted_space} IN CNAME ${v_input_hostname}.${v_domain_name}")

	sed -i "/^;CNAME-Records/a \\${v_name_record}" "${v_fw_zone}"

	echo -ne "${v_GREEN}[ done ]${v_RESET}\n"

	fn_update_serial_number_of_zones

	fn_reload_named_dns_service
}

fn_delete_cname_record() {
	v_input_cname="${1}"
	fn_get_cname_record "delete"
}

fn_main_menu() {

	v_domain_if_present=$(if [ ! -z "${v_domain_name}" ];then echo -n "${v_domain_name}";else echo '[dnsbinder-not-yet-configured]';fi)
	v_domain_if_present=$(printf "%-*s" 53 "${v_domain_if_present}")
	v_network_if_present=$(if [ ! -z "${dnsbinder_network}" ];then echo -n "${dnsbinder_network}";else echo '[dnsbinder-not-yet-configured]';fi)
	v_network_if_present=$(printf "%-*s" 53 "${v_network_if_present}")

cat << EOF
##################################################################
#-------------------------[ DNS-BINDER ]-------------------------#
# Domain  : ${v_domain_if_present}#
# Network : ${v_network_if_present}# 
#----------------------------------------------------------------#
# 1) Create a DNS host record                                    #
# 2) Delete a DNS host record                                    #
# 3) Rename an existing DNS host record                          #
# 4) Create multiple DNS host records provided in a file         #
# 5) Delete multiple DNS host records provided in a file         #
# 6) Create a DNS host record with specific IPv4 Address         #
# 7) Create a CNAME/Alias record for existing host record        #
# 8) Delete a CNAME/Alias record for existing host record        #
#----------------------------------------------------------------#
# 0) Configure local dns server and domain if not yet done       #
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
	6)
		fn_check_existence_of_domain
		specific_ipv4_requested="yes"
		fn_create_host_record 
		exit
		;;
	q)
		exit
		;;
	*)
		echo -e "\nInvalid Option! Try Again! \n"
		fn_main_menu
		exit 1
		;;
esac
}


fn_usage_message() {
cat << EOF
Usage: dnsbinder [ option ] [ DNS host record ]
Use one of the following Options :
	-c      To create a DNS host record
	-d      To delete a DNS host record
	-r      To rename an existing DNS host record
	-cf     To create multiple DNS host records provided in a file 
	-df     To delete multiple DNS host records provided in a file
	-ci     To create a DNS host record with specific IPv4 Address
	--setup	To configure local dns server and domain if not done already
[ Or ]
Run dnsbinder utility without any arguements to get menu driven actions.
EOF
}

if [ ! -z "${1}" ]
then

	case "${1}" in
		-c)
			fn_check_existence_of_domain
			if [[ ! -z "${3}" ]];then
				echo "Invalid Option! '-c' option takes only 1 arguement as hostname !"
				fn_usage_message
				exit 1
			fi
			fn_create_host_record "${2}"
			exit
			;;
		-d)
			fn_check_existence_of_domain
			if [[ ! -z "${3}" ]];then
				echo "Invalid Option! '-d' option takes only 1 arguement as hostname !"
				fn_usage_message
				exit 1
			fi
			fn_delete_host_record "${2}"
			exit
			;;
		-r)
			fn_check_existence_of_domain
			if [[ ! -z "${3}" ]];then
				echo "Invalid Option! '-r' option takes only 1 arguement as hostname !"
				fn_usage_message
				exit 1
			fi
			fn_rename_host_record "${2}"
			exit
			;;
		-cf)
			fn_check_existence_of_domain
			if [[ ! -z "${3}" ]];then
				echo "Invalid Option! '-cf' option takes only 1 arguement as file containing list of hostnames !"
				fn_usage_message
				exit 1
			fi
			fn_handle_multiple_host_record "${2}" "create"
			exit
			;;
		-df)
			fn_check_existence_of_domain
			if [[ ! -z "${3}" ]];then
				echo "Invalid Option! '-df' option takes only 1 arguement as file containing list of hostnames !"
				fn_usage_message
				exit 1
			fi
			fn_handle_multiple_host_record "${2}" "delete"
			exit
			;;
		-ci)	
			fn_check_existence_of_domain 
			if [[ ! -z "${4}" ]];then
				echo "Invalid Option! '-ci' option takes only 2 arguements [ hostname and required ipv4 address ] !"
				fn_usage_message
				exit 1
			fi
			specific_ipv4_requested="yes"
			fn_create_host_record "${2}" "${3}"
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
			fn_usage_message
			exit 1
			;;
	esac
else
	fn_main_menu
fi
