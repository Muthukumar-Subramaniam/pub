#!/bin/bash
v_date=$(date +%d-%m-%Y_%I-%M-%p)
v_script_log_file="/scripts_by_muthu/server/logs-server-cfg-bkp-script.log"
v_cfg_dir="/root/cfg-bkp"
v_temp_cfg_dir="/root/temp-cfg-bkp"
v_bkp_dir="/scripts_by_muthu/server/server-cfg-bkp"
v_bkp_dir_pub="/scripts_by_muthu/pub/server/server-cfg-bkp"
v_bkp_dir_build_server="/scripts_by_muthu/server/build-server-with-ansible"

if [[ "$(id -u)" -ne 0 ]]
then
	echo -e "\nPlease run this script as root or using sudo ! \n"
	exit
fi

mkdir -p ${v_temp_cfg_dir}

{
echo -e "\nExecution of : /scripts_by_muthu/server/server-cfg-bkp-script.sh"
echo -e "\nFrom Host : $(hostname)"
} > ${v_script_log_file}

{
echo -e "\nScript started at : $(date)"

echo -e "\nTaking temperory rsync of ${v_cfg_dir} to ${v_temp_cfg_dir} . . .\n"

rsync -avPh ${v_cfg_dir}/ ${v_temp_cfg_dir}/

echo -e "\nRsyncing Necessary Config files to ${v_cfg_dir} . . . \n"
rsync -avPh /root/mount-iso.sh ${v_cfg_dir}/
rsync -avPh /etc/systemd/system/mount-iso.service ${v_cfg_dir}/
rsync -avPh /etc/named.conf ${v_cfg_dir}/bind-dns-server-configs/
rsync -avPh /var/named/zone-files/ ${v_cfg_dir}/bind-dns-server-configs/zone-files/
rsync -avPh /etc/NetworkManager/system-connections/ ${v_cfg_dir}/network-interface-configs/
rsync -avPh /etc/dhcp/dhcpd.conf ${v_cfg_dir}/pxe-boot-configs/etc-dhcp-dhcpd.conf
rsync -avPh /root/.ssh/ ${v_cfg_dir}/ssh/root-ssh/
rsync -avPh /home/muthuks/.ssh/ ${v_cfg_dir}/ssh/muthuks-ssh/
rsync -avPh /etc/ssh/ssh_host_* ${v_cfg_dir}/ssh/host-key-ssh/
rsync -avPh /etc/httpd/conf.d/server.ms.local.conf ${v_cfg_dir}/httpd/
rsync -avPh /etc/pki/tls/certs/server.ms.local-apache-selfsigned.crt ${v_cfg_dir}/httpd/
rsync -avPh /etc/pki/tls/private/server.ms.local-apache-selfsigned.key ${v_cfg_dir}/httpd/  
rsync -avPh /etc/nfs.conf ${v_cfg_dir}/nfs/
rsync -avPh /etc/exports ${v_cfg_dir}/nfs/
rsync -avPh /etc/samba/smb.conf ${v_cfg_dir}/samba/
rsync -avPh /etc/chrony.conf ${v_cfg_dir}/

echo -e "\nChecking whether there are any changes in config backups . . ."

diff -r ${v_cfg_dir} ${v_temp_cfg_dir}

if [ $? -ne 0 ];then

f_backup_process() {
	v_backup_dir="$1"
	v_date="$2"

	echo -e "\nRemoving backups under ${v_backup_dir}/ which are older than last 5 backups\n"
	ls -t ${v_backup_dir}/* | tail -n +6 | xargs -I {} rm -v {} 

	for v_current_latest in ${v_backup_dir}/*_latest*
	do 
		mv "$v_current_latest" $(echo "$v_current_latest" | sed "s/_latest//g")
	done 

	mv ${v_backup_dir}/cfg-bkp_${v_date}.tar.gz ${v_backup_dir}/cfg-bkp_${v_date}_latest.tar.gz

	echo -e "\nCurrent backups available under ${v_backup_dir}/\n"
	ls -t ${v_backup_dir}/*
}

echo -e "\nBacking up ${v_cfg_dir} as ${v_bkp_dir}/cfg-bkp_${v_date}.tar.gz\n"
tar -C	/root -czvf  ${v_bkp_dir}/cfg-bkp_${v_date}.tar.gz  cfg-bkp

echo -e "\nBacking up ${v_cfg_dir} as ${v_bkp_dir_pub}/cfg-bkp_${v_date}.tar.gz\n"
tar --exclude="smbcredentials" -C /root -czvf  ${v_bkp_dir_pub}/cfg-bkp_${v_date}.tar.gz  cfg-bkp

f_backup_process "${v_bkp_dir}" "${v_date}"
f_backup_process "${v_bkp_dir_pub}" "${v_date}"

echo -e "\nDelete any existing backup under build-server-with-ansible . .\n"

rm -rf "${v_bkp_dir_build_server}"/cfg-bkp*latest.tar.gz

echo -e "\nCopy latest private backup to build-server-with-ansible . . .\n"

rsync -avPh ${v_bkp_dir}/cfg-bkp_${v_date}_latest.tar.gz "${v_bkp_dir_build_server}"/

echo -e "\nRecreate tarball of build-server-with-ansible . . ."

tar -C /scripts_by_muthu/server/ -czvf "${v_bkp_dir_build_server}".tar.gz build-server-with-ansible 

echo -e "\nName of the Latest Backups : cfg-bkp_${v_date}_latest.tar.gz\n"
echo -e "\nFile Locations :\n	${v_bkp_dir}/cfg-bkp_${v_date}_latest.tar.gz\n	${v_bkp_dir_pub}/cfg-bkp_${v_date}_latest.tar.gz\n"

echo -e "Script ended at : $(date)\n"

else
	echo -e "\nSkipping new backup as there are no changes since last backup!\n"
	echo -e "Script ended at : $(date)\n"
fi


rm -rf ${v_temp_cfg_dir}


} &>> ${v_script_log_file}
