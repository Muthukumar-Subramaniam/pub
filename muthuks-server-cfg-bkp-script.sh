#!/bin/bash
v_date=$(date +%d-%m-%Y_%I-%M-%p)
v_cfg_dir=/root/cfg-bkp

rm -rf /root/log.muthuks-server-cfg-bkp-script.sh-*

>/root/log.muthuks-server-cfg-bkp-script.sh-$v_date

{
echo -e "\n Script started at $(date)"
crontab -l >$v_cfg_dir/crontab-root
cat /etc/fstab >$v_cfg_dir/fstab

echo -e "\nRsyncing Necessary Config files to $v_cfg_dir . . . \n"
rsync -avPh /root/mount-iso.sh $v_cfg_dir/.
rsync -avPh /etc/systemd/system/mount-iso.service $v_cfg_dir/.
rsync -avPh /etc/named.conf /var/named/*muthuks* $v_cfg_dir/bind-dns-server-configs/.
rsync -avPh /etc/NetworkManager/system-connections/* $v_cfg_dir/network-interface-configs/.
rsync -avPh /etc/dhcp/dhcpd.conf $v_cfg_dir/pxe-boot-configs/etc-dhcp-dhcpd.conf
rsync -avPh /var/lib/tftpboot/grub.cfg $v_cfg_dir/pxe-boot-configs/var-lib-tftpboot-grub.cfg
rsync -avPh /var/lib/tftpboot/grubx64.efi $v_cfg_dir/pxe-boot-configs/var-lib-tftpboot-grubx64.efi
rsync -avPh /var/lib/tftpboot/pxelinux.cfg $v_cfg_dir/pxe-boot-configs/
rsync -avPh --exclude={{rhel,rocky,almalinux,oraclelinux}-9-4,rhel-{7-9,8-10},ubuntu-24-04,opensuse-15-6} /var/www/muthuks-web-server.muthuks.local.lab/ $v_cfg_dir/pxe-boot-configs/var-www-muthuks-web-server.muthuks.local.lab/.
rsync -avPh /root/.ssh/* $v_cfg_dir/ssh/root-ssh/.
rsync -avPh /home/muthuks/.ssh/* $v_cfg_dir/ssh/muthuks-ssh/.
rsync -avPh /home/sshfsuser/.ssh/* $v_cfg_dir/ssh/sshfsuser-ssh/.
rsync -avPh /etc/ssh/ssh_host_* $v_cfg_dir/ssh/host-key-ssh/.
rsync -avPh /etc/httpd/conf.d/muthuks-web-server.muthuks.local.lab.conf $v_cfg_dir/httpd/.
rsync -avPh /etc/pki/tls/certs/apache-selfsigned.crt $v_cfg_dir/httpd/.
rsync -avPh /etc/pki/tls/private/apache-selfsigned.key $v_cfg_dir/httpd/.  
rsync -avPh /etc/nfs.conf $v_cfg_dir/nfs/.
rsync -avPh /etc/exports $v_cfg_dir/nfs/.
rsync -avPh /etc/samba/smb.conf $v_cfg_dir/samba/. 
rsync -avPh /etc/chrony.conf $v_cfg_dir/. 

echo -e "\nBacking up $v_cfg_dir as /scripts_by_muthu/muthuks-server/muthuks-server-cfg-bkp/cfg-bkp_$v_date.tar.gz\n"
tar -C	/root -czvf  /scripts_by_muthu/muthuks-server/muthuks-server-cfg-bkp/cfg-bkp_$v_date.tar.gz  cfg-bkp

echo -e "\nRemoving backups under /scripts_by_muthu/muthuks-server/muthuks-server-cfg-bkp/ which are older than last 10 backups\n"
ls -t /scripts_by_muthu/muthuks-server/muthuks-server-cfg-bkp/* | tail -n +11 | xargs -I {} rm -v {} 
echo -e "\nCurrent backups available under /scripts_by_muthu/muthuks-server/muthuks-server-cfg-bkp/\n"
ls -t /scripts_by_muthu/muthuks-server/muthuks-server-cfg-bkp/*

echo -e "\nPushing /scripts_by_muthu to GitHub and GitLab"
#Note by default the local repository /scripts_by_muthu is set to keep track of GitHub only.
#GitLab is added as remote origin-gitlab, hence implicitly pushed.
cd /scripts_by_muthu && git pull
cd /scripts_by_muthu && git add .
cd /scripts_by_muthu && git commit -m "Committ /scripts_by_muthu to GitHub and GitLab repository Scripts_by_muthu on $v_date"
cd /scripts_by_muthu && git push
cd /scripts_by_muthu && git push origin-gitlab main

echo -e "\n Script ended at $(date)"

#echo "Configuration Backup of muthuks-server" | mail -s "muthuks-server-cfg-bkp" -a /scripts_by_muthu/muthuks-server/muthuks-server-cfg-bkp/cfg-bkp_$v_date.tar.gz muthuks.local.lab@gmail.com

} | tee -a /root/log.muthuks-server-cfg-bkp-script.sh-$v_date
