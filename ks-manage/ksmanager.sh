#!/bin/bash

if [[ "${UID}" -ne 0 ]]
then
    echo -e "${v_RED}\nRun with sudo or run from root account ! ${v_RESET}\n"
    exit 1
fi

dnsmanager_script='/scripts_by_muthu/server/named-manage/dnsmanager.sh'
ksmanager_main_dir='/scripts_by_muthu/server/ks-manage'
ksmanager_hub_dir='/var/www/server.ms.local/ksmanager-hub'
ipv4_domain='ms.local'
ipv4_netmask='255.255.252.0'
ipv4_prefix='22'
ipv4_gateway="192.168.168.1"
ipv4_nameserver="192.168.168.3"
ipv4_nfsserver="192.168.168.3"
tftp_server_name="server"
ntp_pool_name="server"
web_server_name="server"
win_kickstart_hostname="windows"
rhel_activation_key=$(cat /scripts_by_muthu/server/rhel-activation-key.base64 | base64 -d)
time_of_last_update=$(date | sed  "s/ /-/g")


while :
do
	# shellcheck disable=SC2162
	if [ -z "${1}" ]
	then
		echo -e "Create Kickstart Host Profiles for PXE-boot in \"${ipv4_domain}\" domain,\n"
		echo "Points to Keep in Mind While Entering the Hostname:"
		echo " * Please use only letters, numbers, and hyphens."
		echo " * Please do not start with a number."
		echo -e " * Please do not append the domain name \"${ipv4_domain}\" \n"
		read -r -p "Please Enter the Hostname for which Kickstarts are required : " kickstart_hostname
	else
		kickstart_hostname="${1}"
	fi

	if [[ ${kickstart_hostname} =~ ^[[:alpha:]]([-[:alnum:]]*)$ ]]
	then
    		break
  	else
    		echo  "Invalid Hostname! "
		echo "FYI:"
		echo "	1. Please use only letters, numbers, and hyphens."
		echo "	2. Please do not start with a number."
		echo -e "	3. Please do not append the domain name ${ipv4_domain} \n"
  	fi
done

if ! host "${kickstart_hostname}" &>/dev/null
then
	echo -e "\nNo DNS record found for \"${kickstart_hostname}\"\n"	
	while :
	do
		read -r -p "Enter (y) to create DNS record for ${kickstart_hostname} or (n) to exit the script : " v_confirmation

		if [[ "${v_confirmation}" == "y" ]]
		then
			echo -e "\nExecuting the script ${dnsmanager_script} . . .\n"
			"${dnsmanager_script}" -c "${kickstart_hostname}"

			if host "${kickstart_hostname}" &>/dev/null
			then
				echo -e "\nDNS Record for ${kickstart_hostname} created successfully! "
				echo "FYI: $(host ${kickstart_hostname})"
				echo -e "\nProceeding further . . .\n"
				break
			else
				echo -e "\nSomething went wrong while creating ${kickstart_hostname} !\n"
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
	echo -e "\nDNS Record found for ${kickstart_hostname}!\n"
	echo "FYI: $(host ${kickstart_hostname})"

fi

# Function to validate MAC address
fn_validate_mac() {
    local mac_address_of_host="${1}"
    
    # Regex for MAC address (allowing both colon and hyphen-separated)
    if [[ "${mac_address_of_host}" =~ ^([a-fA-F0-9]{2}([-:]?)){5}[a-fA-F0-9]{2}$ ]]
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
    		printf "\nEnter MAC address of the VM ${kickstart_hostname} : "
		read mac_address_of_host
    		# Call the function to validate the MAC address
    		if fn_validate_mac "${mac_address_of_host}"
    		then
			# Convert MAC address to required format to append with grub.cfg file
			grub_cfg_mac_address=$(echo "${mac_address_of_host}" | tr ':' '-' | tr 'A-F' 'a-f')
			echo -e "\nUpdating MAC address to mac-address-cache for future use . . .\n"
			sed -i "/${kickstart_hostname}/d" "${ksmanager_main_dir}"/mac-address-cache
			echo "${kickstart_hostname} ${mac_address_of_host}" >> "${ksmanager_main_dir}"/mac-address-cache
        		break
    		else
        		echo -e "\nInvalid MAC address provided. Please try again.\n"
    		fi
	done
}

echo -e "\nLooking up MAC Address for the host ${kickstart_hostname} from mac-address-cache . . ."

if grep ^"${kickstart_hostname} " "${ksmanager_main_dir}"/mac-address-cache &>>/dev/null
then
	mac_address_of_host=$(grep ^"${kickstart_hostname} " "${ksmanager_main_dir}"/mac-address-cache | cut -d " " -f 2 )
	echo -e "\nMAC Address ${mac_address_of_host} found for ${kickstart_hostname} in mac-address-cache! \n" 
	while :
	do
		read -p "Has the MAC Address ${mac_address_of_host} been changed for ${kickstart_hostname} (y/N) ? : " confirmation 
		if [[ "${confirmation}" =~ ^[Nn]$ ]] 
		then
			grub_cfg_mac_address=$(echo "${mac_address_of_host}" | tr ':' '-' | tr 'A-F' 'a-f')
			break

		elif [[ -z "${confirmation}" ]]
		then
			grub_cfg_mac_address=$(echo "${mac_address_of_host}" | tr ':' '-' | tr 'A-F' 'a-f')
			break

		elif [[ "${confirmation}" =~ ^[Yy]$ ]]
		then
			fn_get_mac_address
			break
		else
			echo -e "\nInvalid Input! \n"
		fi
	done
else
	echo -e "\nMAC Address for ${kickstart_hostname} not found in mac-address-cache! " 
	fn_get_mac_address
fi

fn_select_os_distro() {
cat << EOF

Please select OS distribution to install :
	1 ) AlmaLinux Latest ( Uses Local Mirror for Installation )
	2 ) Ubuntu Server Latest ( Requires Internet Connection )
	3 ) OpenSuse Leap Latest ( Requires Internet Connection )

EOF
	read -p "Enter Option Number : " os_distribution

	case ${os_distribution} in
		1) os_distribution="almalinux"
	   	   ;;
		2) os_distribution="ubuntu"
	   	   ;;
		3) os_distribution="opensuse"
	   	   ;;
		*) echo "Invalid Option!"
	   	   fn_select_os_distro
	   	   ;;
	esac
}


fn_select_os_distro

# shellcheck disable=SC2021
ipv4_address=$(host "${kickstart_hostname}.${ipv4_domain}" | cut -d " " -f 4 | tr -d '[[:space:]]')

mkdir -p "${ksmanager_hub_dir}"

rsync -avPh --delete "${ksmanager_main_dir}"/addons-for-kickstarts/ "${ksmanager_hub_dir}"/addons-for-kickstarts/

host_kickstart_dir="${ksmanager_hub_dir}/kickstarts/${kickstart_hostname}.${ipv4_domain}"

mkdir -p "${host_kickstart_dir}"

echo -e "\nGenerating kickstart for ${kickstart_hostname}.${ipv4_domain} under ${host_kickstart_dir} . . .\n"

rm -rf "${host_kickstart_dir}"/*

if [[ "${os_distribution}" == "almalinux" ]]; then
	rsync -avPh "${ksmanager_main_dir}"/ks-templates/el-9-ks.cfg "${host_kickstart_dir}"/ 
elif [[ "${os_distribution}" == "ubuntu" ]]; then
	rsync -avPh --delete "${ksmanager_main_dir}"/ks-templates/ubuntu-24-04-ks "${host_kickstart_dir}"/
elif [[ "${os_distribution}" == "opensuse" ]]; then
	rsync -avPh "${ksmanager_main_dir}"/ks-templates/opensuse-15-autoinst.xml "${host_kickstart_dir}"/ 
fi


# shellcheck disable=SC2044
fn_set_environment() {
	local input_dir_or_file="${1}"
	local working_file=

	fn_run_sed_command() {
		local working_file="${1}"
		sed -i "s/get_ipv4_address/${ipv4_address}/g" "${working_file}"
		sed -i "s/get_ipv4_netmask/${ipv4_netmask}/g" "${working_file}"
		sed -i "s/get_ipv4_prefix/${ipv4_prefix}/g" "${working_file}"
    		sed -i "s/get_ipv4_gateway/${ipv4_gateway}/g" "${working_file}"
		sed -i "s/get_ipv4_nameserver/${ipv4_nameserver}/g" "${working_file}"
		sed -i "s/get_ipv4_nfsserver/${ipv4_nfsserver}/g" "${working_file}"
		sed -i "s/get_ipv4_domain/${ipv4_domain}/g" "${working_file}"
    		sed -i "s/get_hostname/${kickstart_hostname}/g" "${working_file}"
		sed -i "s/get_ntp_pool_name/${ntp_pool_name}/g" "${working_file}"
		sed -i "s/get_web_server_name/${web_server_name}/g" "${working_file}" 
		sed -i "s/get_win_hostname/${win_hostname}/g" "${working_file}"
		sed -i "s/get_tftp_server_name/${tftp_server_name}.ms.local/g" "${working_file}"
		sed -i "s/get_rhel_activation_key/${rhel_activation_key}/g" "${working_file}"
		sed -i "s/get_time_of_last_update/${time_of_last_update}/g" "${working_file}"
	}

	if [ -d "${input_dir_or_file}" ]
	then
		for working_file in $(find "${input_dir_or_file}" -type f )
		do
			fn_run_sed_command "${working_file}"
		done

	elif [ -f "${input_dir_or_file}" ]
	then
		working_file="${input_dir_or_file}"
		fn_run_sed_command "${working_file}"
	fi
}


fn_set_environment "${host_kickstart_dir}"

echo -e "\nCreating or Updating /var/lib/tftpboot/grub.cfg-01-${grub_cfg_mac_address} . . .\n"

rsync -avPh "${ksmanager_main_dir}"/grub-template-"${os_distribution}".cfg  /var/lib/tftpboot/grub.cfg-01-"${grub_cfg_mac_address}"

fn_set_environment "/var/lib/tftpboot/grub.cfg-01-${grub_cfg_mac_address}"

echo -e "\nCreating or Updating /var/lib/tftpboot/grub.cfg . . .\n"

rsync -avPh "${ksmanager_main_dir}"/grub-template-manual.cfg /var/lib/tftpboot/grub.cfg

fn_set_environment "/var/lib/tftpboot/grub.cfg"

echo -e "\nFYI:"
echo "	Hostname     : ${kickstart_hostname}.${ipv4_domain}"
echo "	MAC Address  : ${mac_address_of_host}" 
echo "	IPv4 Address : ${ipv4_address}"
echo "	IPv4 Netmask : ${ipv4_netmask}"
echo "	IPv4 Gateway : ${ipv4_gateway}"
echo "	IPv4 DNS     : ${ipv4_nameserver}"
echo "	Domain Name  : ${ipv4_domain}"
echo "	TFTP Server  : ${tftp_server_name}.${ipv4_domain}"
echo "	NTP Pool     : ${ntp_pool_name}.${ipv4_domain}"
echo "	Web Server   : ${web_server_name}.${ipv4_domain}"
echo "	Windows Host : ${win_hostname}.${ipv4_domain}"	
echo "	Kickstarts   : ${host_kickstart_dir}"
echo "	Selected OS  : ${os_distribution} server edition"

echo -e "\nAll done, You can proceed to pxeboot the host ${kickstart_hostname}\n"

exit
