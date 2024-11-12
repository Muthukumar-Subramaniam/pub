#!/bin/bash
var_named_manage_dir='/scripts_by_muthu/server/named-manage'
var_create_record="${var_named_manage_dir}/create-dns-records.sh"
var_create_multiple_records="${var_named_manage_dir}/create-dns-records-stored-in-file.sh"
var_delete_record="${var_named_manage_dir}/delete-dns-records.sh"
var_delelte_multiple_records="${var_named_manage_dir}/delete-dns-records-stored-in-file.sh"
var_modify_record="${var_named_manage_dir}/modify-dns-record.sh"

if ! sudo -l | grep NOPASSWD &> /dev/null
then
	echo -e "\nYou need sudo access without password to run this script! \n"
	exit
fi

fn_main_menu() {
cat << EOF
Manage DNS Records with named,
1) Create a DNS Record
2) Create Multiple DNS Records
3) Delete a DNS Record
4) Delete Multiple DNS Records
5) Modify an existing DNS Record
q) Quit without any changes

EOF

read -p "Please Select an Option from Above : " var_script

case ${var_script} in
	1)
		"${var_create_record}"
		;;
	2)
		"${var_create_multiple_records}"
		;;
	3)
		"${var_delete_record}"
		;;
	4)
		"${var_delelte_multiple_records}"
		;;
	5)
		"${var_modify_record}"
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

fn_main_menu
