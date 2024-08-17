#!/bin/bash
v_dns_record_creator='/scripts_by_muthu/muthuks-server/named-manage/create-dns-records.sh'
v_pxe_server_updater='/scripts_by_muthu/muthuks-server/net-boot-pxe-set.sh'
v_ks_manage_dir='/scripts_by_muthu/muthuks-server/ks-manage'
v_kickstart_dir='/var/www/muthuks-web-server.ms.local/ks-manager-kickstarts'
v_get_ipv4_domain='ms.local'
v_get_ipv4_netmask='255.255.255.0'
v_get_rhel_activation_key=$(cat /scripts_by_muthu/muthuks-server/rhel-activation-key.base64 | base64 -d)
v_get_time_of_last_update=$(date | sed  "s/ /-/g")

while :
do
	echo -e "\nPlease use only letters, numbers, and hyphens.\n (Please do not start with a number)."
	echo -e "No need to append the domain name ms.local\n"

	# shellcheck disable=SC2162
	if [ -z $1 ]
	then
		read -r -p "Please Enter the Hostname for which Kickstarts are required : " v_get_hostname
	else
		v_get_hostname=$1
	fi

	if [[ $v_get_hostname =~ ^[[:alpha:]]([-[:alnum:]]*)$ ]]
	then
    		break
  	else
    		echo -e "Invalid name!\nPlease use only letters, numbers, and hyphens.\n (cannot start with a number).\n"
  	fi
done

if ! nslookup "$v_get_hostname" &>/dev/null
then
	echo -e "\nNo DNS record found for \"$v_get_hostname\"\n"	
	while :
	do
		read -r -p "Enter (y) to create DNS record for $v_get_hostname or (n) to exit the script : " v_confirmation

		if [[ $v_confirmation == "y" ]]
		then
			echo -e "\nExecuting the script $v_dns_record_creator . . .\n"
			$v_dns_record_creator "$v_get_hostname"

			if nslookup "$v_get_hostname" &>/dev/null
			then
				echo -e "\nDNS Record for $v_get_hostname created successfully, proceeding further . . .\n"
				break
			else
				echo -e "\nSomething went wrong while creating $v_get_hostname !\n"
				exit
			fi

		elif [[ $v_confirmation == "n" ]]
		then
			echo -e "\nCancelled without any changes !\n"
			exit

		else
			echo -e "\nSelect only either (y/n) !\n"
			continue

		fi
	done
else
	echo -e "\nDNS Record found for $v_get_hostname, proceeding further . . .\n"

fi

# shellcheck disable=SC2021
v_get_ipv4_address=$(nslookup "$v_get_hostname" | grep ^Name -A 1 | grep Address | cut -d ":" -f 2 | tr -d '[[:space:]]')

echo -e "\nSetting up network parameters . . .\n"

if echo "$v_get_ipv4_address" | grep 192.168.168 &>/dev/null
then
	v_get_ipv4_gateway='192.168.168.1'
	v_get_ipv4_nameserver='192.168.168.4'
	v_get_tftp_server_name='prod-tftp'
	v_get_ntp_pool_name='prod-ntp-pool'
	v_get_web_server_name='prod-web'
	v_get_win_hostname='prod-win'
	$v_pxe_server_updater 1

elif echo "$v_get_ipv4_address" | grep 10.10.10 &>/dev/null
then
	v_get_ipv4_gateway='10.10.10.1'
	v_get_ipv4_nameserver='10.10.10.4'
	v_get_tftp_server_name='test-tftp'
	v_get_ntp_pool_name='test-ntp-pool'
	v_get_web_server_name='test-web'
	v_get_win_hostname='test-win'
	$v_pxe_server_updater 2


elif echo "$v_get_ipv4_address" | grep 172.16.16 &>/dev/null
then
	v_get_ipv4_gateway='172.16.16.1'
	v_get_ipv4_nameserver='172.16.16.4'
	v_get_tftp_server_name='dev-tftp'
	v_get_ntp_pool_name='dev-ntp-pool'
	v_get_web_server_name='dev-web'
	v_get_win_hostname='dev-win'
	$v_pxe_server_updater 3
fi

v_kickstart_dir="${v_kickstart_dir}/${v_get_hostname}.${v_get_ipv4_domain}"

echo -e "\nGenerating kickstart files for ${v_get_hostname}.${v_get_ipv4_domain} under $v_kickstart_dir . . .\n"

if [[ ! -d $v_kickstart_dir ]]
then	
	mkdir -p "$v_kickstart_dir"
else
	rm -rf "${v_kickstart_dir:?}"/*
fi

cd $v_ks_manage_dir && rsync -avPh grub-template.cfg local-repo ks-templates/ "$v_kickstart_dir"/ 

# shellcheck disable=SC2044
for v_file in $(find "$v_kickstart_dir"/ -type f )
do
	sed -i "s/get_ipv4_address/$v_get_ipv4_address/g" "$v_file"
	sed -i "s/get_ipv4_netmask/$v_get_ipv4_netmask/g" "$v_file"
    	sed -i "s/get_ipv4_gateway/$v_get_ipv4_gateway/g" "$v_file"
	sed -i "s/get_ipv4_nameserver/$v_get_ipv4_nameserver/g" "$v_file"
	sed -i "s/get_ipv4_domain/$v_get_ipv4_domain/g" "$v_file"
    	sed -i "s/get_hostname/$v_get_hostname/g" "$v_file"
	sed -i "s/get_ntp_pool_name/$v_get_ntp_pool_name/g" "$v_file"
	sed -i "s/get_web_server_name/$v_get_web_server_name/g" "$v_file" 
	sed -i "s/get_win_hostname/$v_get_win_hostname/g" "$v_file"
	sed -i "s/get_tftp_server_name/${v_get_tftp_server_name}.ms.local/g" "$v_file"
	sed -i "s/get_rhel_activation_key/${v_get_rhel_activation_key}/g" "$v_file"
	sed -i "s/get_time_of_last_update/${v_get_time_of_last_update}/g" "$v_file"
done

echo -e "\nUpdating /var/lib/tftpboot/grub.cfg . . .\n"

rsync -avPh "$v_kickstart_dir"/grub-template.cfg /var/lib/tftpboot/grub.cfg

echo -e "\nkickstart files are stored under $v_kickstart_dir"

echo -e "\nAll done, You can proceed to pxeboot the host $v_get_hostname\n"
