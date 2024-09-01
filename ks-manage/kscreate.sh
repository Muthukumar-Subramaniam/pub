#!/bin/bash
v_dns_record_creator='/scripts_by_muthu/muthuks-server/named-manage/create-dns-records.sh'
v_pxe_server_updater='/scripts_by_muthu/muthuks-server/net-boot-pxe-set.sh'
v_ks_manage_dir='/scripts_by_muthu/muthuks-server/ks-manage'
v_kickstart_dir='/var/www/muthuks-web-server.ms.local/ks-manager-kickstarts'
v_get_ipv4_domain='ms.local'
v_get_ipv4_netmask='255.255.255.0'
v_get_rhel_activation_key=$(cat /scripts_by_muthu/muthuks-server/rhel-activation-key.base64 | base64 -d)
v_get_time_of_last_update=$(date | sed  "s/ /-/g")

if [[ "$(id -u)" -ne 0 ]]
then
	echo -e "\nPlease run this script as root or using sudo ! \n"
	exit
fi

while :
do
	# shellcheck disable=SC2162
	if [ -z "${1}" ]
	then
		echo "FYI:"
		echo "	1. Please use only letters, numbers, and hyphens."
		echo "	2. Please do not start with a number."
		echo -e "	3. Please do not append the domain name ${v_get_ipv4_domain} \n"
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

# shellcheck disable=SC2021
v_get_ipv4_address=$(host "${v_get_hostname}.${v_get_ipv4_domain}" | cut -d " " -f 4 | tr -d '[[:space:]]')

echo -e "\nSetting up network parameters . . .\n"

fn_set_ips_and_resources() {

	v_network_part="${1}"
	v_network_tier_name="${2}"
	v_network_tier_number="${3}"

	v_get_ipv4_gateway="${v_network_part}.1"
	v_get_ipv4_nameserver="${v_network_part}.4"
	v_get_tftp_server_name="${v_network_tier_name}-tftp"
	v_get_ntp_pool_name="${v_network_tier_name}-ntp-pool"
	v_get_web_server_name="${v_network_tier_name}-web"
	v_get_win_hostname="${v_network_tier_name}-win"
	"${v_pxe_server_updater}" "${v_network_tier_number}"
}

if echo "${v_get_ipv4_address}" | grep 192.168.168 &>/dev/null
then
	fn_set_ips_and_resources "192.168.168" "prod" "1"

elif echo "${v_get_ipv4_address}" | grep 10.10.10 &>/dev/null
then
	fn_set_ips_and_resources "10.10.10" "test" "2"
	
elif echo "${v_get_ipv4_address}" | grep 172.16.16 &>/dev/null
then
	fn_set_ips_and_resources "172.16.16" "dev" "3"
fi


v_kickstart_dir="${v_kickstart_dir}/${v_get_hostname}.${v_get_ipv4_domain}"

echo -e "\nGenerating kickstart files for ${v_get_hostname}.${v_get_ipv4_domain} under ${v_kickstart_dir} . . .\n"

if [[ ! -d "${v_kickstart_dir}" ]]
then	
	mkdir -p "${v_kickstart_dir}"
else
	rm -rf "${v_kickstart_dir:?}"/*
fi

cd "${v_ks_manage_dir}" && rsync -avPh grub-template.cfg local-repo ks-templates/ "${v_kickstart_dir}"/ 

# shellcheck disable=SC2044
for v_file in $(find "${v_kickstart_dir}"/ -type f )
do
	sed -i "s/get_ipv4_address/${v_get_ipv4_address}/g" "$v_file"
	sed -i "s/get_ipv4_netmask/${v_get_ipv4_netmask}/g" "$v_file"
    	sed -i "s/get_ipv4_gateway/${v_get_ipv4_gateway}/g" "$v_file"
	sed -i "s/get_ipv4_nameserver/${v_get_ipv4_nameserver}/g" "$v_file"
	sed -i "s/get_ipv4_domain/${v_get_ipv4_domain}/g" "$v_file"
    	sed -i "s/get_hostname/${v_get_hostname}/g" "$v_file"
	sed -i "s/get_ntp_pool_name/${v_get_ntp_pool_name}/g" "$v_file"
	sed -i "s/get_web_server_name/${v_get_web_server_name}/g" "$v_file" 
	sed -i "s/get_win_hostname/${v_get_win_hostname}/g" "$v_file"
	sed -i "s/get_tftp_server_name/${v_get_tftp_server_name}.ms.local/g" "$v_file"
	sed -i "s/get_rhel_activation_key/${v_get_rhel_activation_key}/g" "$v_file"
	sed -i "s/get_time_of_last_update/${v_get_time_of_last_update}/g" "$v_file"
done

echo -e "\nUpdating /var/lib/tftpboot/grub.cfg . . .\n"

rsync -avPh "${v_kickstart_dir}"/grub-template.cfg /var/lib/tftpboot/grub.cfg

echo -e "\nFYI:"
echo "	Hostname     : ${v_get_hostname}.${v_get_ipv4_domain}"
echo "	IPv4 Address : ${v_get_ipv4_address}"
echo "	IPv4 Netmask : ${v_get_ipv4_netmask}"
echo "	IPv4 Gateway : ${v_get_ipv4_gateway}"
echo "	IPv4 DNS     : ${v_get_ipv4_nameserver}"
echo "	Domain Name  : ${v_get_ipv4_domain}"
echo "	TFTP Server  : ${v_get_tftp_server_name}.${v_get_ipv4_domain}"
echo "	NTP Pool     : ${v_get_ntp_pool_name}.${v_get_ipv4_domain}"
echo "	Web Server   : ${v_get_web_server_name}.${v_get_ipv4_domain}"
echo "	Windows Host : ${v_get_win_hostname}.${v_get_ipv4_domain}"	
echo "	Kickstarts   : ${v_kickstart_dir}"

echo -e "\nAll done, You can proceed to pxeboot the host ${v_get_hostname}\n"
