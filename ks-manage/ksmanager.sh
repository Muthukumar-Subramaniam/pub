#!/bin/bash
v_dns_record_creator='/scripts_by_muthu/server/named-manage/create-dns-records.sh'
v_ks_manage_dir='/scripts_by_muthu/server/ks-manage'
v_ks_manager_kickstarts_dir='/var/www/server.ms.local/ks-manager-kickstarts'
v_get_ipv4_domain='ms.local'
v_get_ipv4_netmask='255.255.252.0'
v_get_ipv4_prefix='22'
v_get_ipv4_gateway="192.168.168.1"
v_get_ipv4_nameserver="192.168.168.3"
v_get_tftp_server_name="server"
v_get_ntp_pool_name="server"
v_get_web_server_name="server"
v_get_win_hostname="windows"
v_get_rhel_activation_key=$(cat /scripts_by_muthu/server/rhel-activation-key.base64 | base64 -d)
v_get_time_of_last_update=$(date | sed  "s/ /-/g")

if ! sudo -l | grep NOPASSWD &> /dev/null
then
	echo -e "\nYou need sudo access without password to run this script ! \n"
	exit
fi

while :
do
	# shellcheck disable=SC2162
	if [ -z "${1}" ]
	then
		echo -e "Create Kickstart Host Profiles for PXE-boot in \"${v_get_ipv4_domain}\" domain,\n"
		echo "Points to Keep in Mind While Entering the Hostname:"
		echo " * Please use only letters, numbers, and hyphens."
		echo " * Please do not start with a number."
		echo -e " * Please do not append the domain name \"${v_get_ipv4_domain}\" \n"
		read -r -p "Please Enter the Hostname for which Kickstarts are required : " v_get_hostname
	else
		v_get_hostname="${1}"
	fi

	if [[ ${v_get_hostname} =~ ^[[:alpha:]]([-[:alnum:]]*)$ ]]
	then
    		break
  	else
    		echo  "Invalid Hostname! "
		echo "FYI:"
		echo "	1. Please use only letters, numbers, and hyphens."
		echo "	2. Please do not start with a number."
		echo -e "	3. Please do not append the domain name ${v_get_ipv4_domain} \n"
  	fi
done

if ! host "${v_get_hostname}" &>/dev/null
then
	echo -e "\nNo DNS record found for \"${v_get_hostname}\"\n"	
	while :
	do
		read -r -p "Enter (y) to create DNS record for ${v_get_hostname} or (n) to exit the script : " v_confirmation

		if [[ "${v_confirmation}" == "y" ]]
		then
			echo -e "\nExecuting the script ${v_dns_record_creator} . . .\n"
			"${v_dns_record_creator}" "${v_get_hostname}"

			if host "${v_get_hostname}" &>/dev/null
			then
				echo -e "\nDNS Record for ${v_get_hostname} created successfully! "
				echo "FYI: $(host ${v_get_hostname})"
				echo -e "\nProceeding further . . .\n"
				break
			else
				echo -e "\nSomething went wrong while creating ${v_get_hostname} !\n"
				exit
			fi

		elif [[ "${v_confirmation}" == "n" ]]
		then
			echo -e "\nCancelled without any changes !\n"
			exit

		else
			echo -e "\nSelect only either (y/n) !\n"
			continue

		fi
	done
else
	echo -e "\nDNS Record found for ${v_get_hostname}!\n"
	echo "FYI: $(host ${v_get_hostname})"

fi

# Function to validate MAC address
fn_validate_mac() {
    local var_get_mac_address="${1}"
    
    # Regex for MAC address (allowing both colon and hyphen-separated)
    if [[ "${var_get_mac_address}" =~ ^([a-fA-F0-9]{2}([-:]?)){5}[a-fA-F0-9]{2}$ ]]
    then
        return 0  # Valid MAC address
    else
        return 1  # Invalid MAC address
    fi
}


# Loop until a valid MAC address is provided

fn_get_mac_address() {
	while :
	do
    		printf "\nEnter MAC address of the VM ${v_get_hostname} : "
		read var_get_mac_address
    		# Call the function to validate the MAC address
    		if fn_validate_mac "${var_get_mac_address}"
    		then
			# Convert MAC address to required format to append with grub.cfg file
			var_grub_cfg_mac_address=$(echo "${var_get_mac_address}" | tr ':' '-' | tr 'A-F' 'a-f')
			echo -e "\nUpdating MAC address to mac-address-cache for future use . . .\n"
			sed -i "/${v_get_hostname}/d" "${v_ks_manage_dir}"/mac-address-cache
			echo "${v_get_hostname} ${var_get_mac_address}" >> "${v_ks_manage_dir}"/mac-address-cache
        		break
    		else
        		echo -e "\nInvalid MAC address provided. Please try again.\n"
    		fi
	done
}

echo -e "\nLooking up MAC Address for the host ${v_get_hostname} from mac-address-cache . . ."

if grep "${v_get_hostname}" "${v_ks_manage_dir}"/mac-address-cache &>>/dev/null
then
	var_get_mac_address=$(grep "${v_get_hostname}" "${v_ks_manage_dir}"/mac-address-cache | cut -d " " -f 2 )
	echo -e "\nMAC Address ${var_get_mac_address} found for ${v_get_hostname} in mac-address-cache! \n" 
	while :
	do
		read -p "Has the MAC Address ${var_get_mac_address} been changed for ${v_get_hostname} (y/N) ? : " v_get_confirmation 
		if [[ "${v_get_confirmation}" =~ ^[Nn]$ ]] 
		then
			var_grub_cfg_mac_address=$(echo "${var_get_mac_address}" | tr ':' '-' | tr 'A-F' 'a-f')
			break

		elif [[ -z "${v_get_confirmation}" ]]
		then
			var_grub_cfg_mac_address=$(echo "${var_get_mac_address}" | tr ':' '-' | tr 'A-F' 'a-f')
			break

		elif [[ "${v_get_confirmation}" =~ ^[Yy]$ ]]
		then
			fn_get_mac_address
			break
		else
			echo -e "\nInvalid Input! \n"
		fi
	done
else
	echo -e "\nMAC Address for ${v_get_hostname} not found in mac-address-cache! " 
	fn_get_mac_address
fi

# shellcheck disable=SC2021
v_get_ipv4_address=$(host "${v_get_hostname}.${v_get_ipv4_domain}" | cut -d " " -f 4 | tr -d '[[:space:]]')

mkdir -p "${v_ks_manager_kickstarts_dir}"

rsync -avPh --delete "${v_ks_manage_dir}"/addons-for-kickstarts/ "${v_ks_manager_kickstarts_dir}"/addons-for-kickstarts/

rsync -avPh --delete "${v_ks_manage_dir}"/local-repo/ "${v_ks_manager_kickstarts_dir}"/local-repo/

rsync -avPh "${v_ks_manage_dir}"/grub-template-auto.cfg "${v_ks_manager_kickstarts_dir}"/

rsync -avPh "${v_ks_manage_dir}"/grub-template-manual.cfg "${v_ks_manager_kickstarts_dir}"/

var_host_ks_profiles_dir="${v_ks_manager_kickstarts_dir}/host-profiles/${v_get_hostname}.${v_get_ipv4_domain}"

mkdir -p "${var_host_ks_profiles_dir}"

echo -e "\nGenerating kickstart profiles for ${v_get_hostname}.${v_get_ipv4_domain} under ${var_host_ks_profiles_dir} . . .\n"

rsync -avPh --delete "${v_ks_manage_dir}"/ks-templates/ "${var_host_ks_profiles_dir}"/ 

# shellcheck disable=SC2044
fn_set_environment() {
	local var_input_dir_or_file="${1}"

	fn_run_sed_command() {
		local var_working_file="${1}"
		sed -i "s/get_ipv4_address/${v_get_ipv4_address}/g" "${var_working_file}"
		sed -i "s/get_ipv4_netmask/${v_get_ipv4_netmask}/g" "${var_working_file}"
		sed -i "s/get_ipv4_prefix/${v_get_ipv4_prefix}/g" "${var_working_file}"
    		sed -i "s/get_ipv4_gateway/${v_get_ipv4_gateway}/g" "${var_working_file}"
		sed -i "s/get_ipv4_nameserver/${v_get_ipv4_nameserver}/g" "${var_working_file}"
		sed -i "s/get_ipv4_domain/${v_get_ipv4_domain}/g" "${var_working_file}"
    		sed -i "s/get_hostname/${v_get_hostname}/g" "${var_working_file}"
		sed -i "s/get_ntp_pool_name/${v_get_ntp_pool_name}/g" "${var_working_file}"
		sed -i "s/get_web_server_name/${v_get_web_server_name}/g" "${var_working_file}" 
		sed -i "s/get_win_hostname/${v_get_win_hostname}/g" "${var_working_file}"
		sed -i "s/get_tftp_server_name/${v_get_tftp_server_name}.ms.local/g" "${var_working_file}"
		sed -i "s/get_rhel_activation_key/${v_get_rhel_activation_key}/g" "${var_working_file}"
		sed -i "s/get_time_of_last_update/${v_get_time_of_last_update}/g" "${var_working_file}"
	}

	if [ -d "${var_input_dir_or_file}" ]
	then
		for var_working_file in $(find "${var_input_dir_or_file}" -type f )
		do
			fn_run_sed_command "${var_working_file}"
		done

	elif [ -f "${var_input_dir_or_file}" ]
	then
		var_working_file="${var_input_dir_or_file}"
		fn_run_sed_command "${var_working_file}"
	fi
}

fn_set_environment "${var_host_ks_profiles_dir}"
fn_set_environment "${v_ks_manager_kickstarts_dir}/local-repo"
fn_set_environment "${v_ks_manager_kickstarts_dir}/grub-template-auto.cfg" 
fn_set_environment "${v_ks_manager_kickstarts_dir}/grub-template-manual.cfg" 

echo -e "\nUpdating /var/lib/tftpboot/grub.cfg . . .\n"

sudo rsync -avPh "${v_ks_manager_kickstarts_dir}"/grub-template-manual.cfg /var/lib/tftpboot/grub.cfg

echo -e "\nCreating or Updating /var/lib/tftpboot/grub.cfg-01-${var_grub_cfg_mac_address} . . .\n"

sudo rsync -avPh "${v_ks_manager_kickstarts_dir}"/grub-template-auto.cfg /var/lib/tftpboot/grub.cfg-01-"${var_grub_cfg_mac_address}"

echo -e "\nFYI:"
echo "	Hostname     : ${v_get_hostname}.${v_get_ipv4_domain}"
echo "	MAC Address  : ${var_get_mac_address}" 
echo "	IPv4 Address : ${v_get_ipv4_address}"
echo "	IPv4 Netmask : ${v_get_ipv4_netmask}"
echo "	IPv4 Gateway : ${v_get_ipv4_gateway}"
echo "	IPv4 DNS     : ${v_get_ipv4_nameserver}"
echo "	Domain Name  : ${v_get_ipv4_domain}"
echo "	TFTP Server  : ${v_get_tftp_server_name}.${v_get_ipv4_domain}"
echo "	NTP Pool     : ${v_get_ntp_pool_name}.${v_get_ipv4_domain}"
echo "	Web Server   : ${v_get_web_server_name}.${v_get_ipv4_domain}"
echo "	Windows Host : ${v_get_win_hostname}.${v_get_ipv4_domain}"	
echo "	Kickstarts   : ${var_host_ks_profiles_dir}"

echo -e "\nAll done, You can proceed to pxeboot the host ${v_get_hostname}\n"

exit
