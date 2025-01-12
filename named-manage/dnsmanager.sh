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
Manage DNS host records with ms.local domain,
1) Create a DNS host record
2) Delete a DNS host record
3) Modify an existing DNS host record
4) Create multiple DNS host records provided in a file named hosts-create-list
5) Delete multiple DNS host records provided in a file named hosts-delete-list
q) Quit without any changes

EOF

read -p "Please Select an Option from Above : " var_script

case ${var_script} in
	1)
		"${var_create_record}"
		;;
	2)
		"${var_delete_record}"
		;;
	3)
		"${var_modify_record}"
		;;
	4)
		"${var_create_multiple_records}"
		;;
	5)
		"${var_delelte_multiple_records}"
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
			"${var_create_record}" "${2}"
			;;
		-d)
			"${var_delete_record}" "${2}"
			;;
		-m)
			"${var_modify_record}" "${2}"
			;;
		-mc)
			"${var_create_multiple_records}"
			;;
		-md)
			"${var_delelte_multiple_records}"
			;;
		*)
			if [[ ! "${1}" =~ ^-h|--help$ ]]
			then
				echo "Invalid Option \"${1}\"!"
			fi
			cat << EOF
Usage: dnsmanager [ option ] [ DNS host record ]
Use one of the following Options :
	-c 	To create a DNS host record
	-d 	To delete a DNS host record
	-m 	To modify an existing DNS host record
	-mc 	To create multiple DNS host records provided in a file named hosts-create-list  
	-md	To delete multiple DNS host records provided in a file named hosts-delete-list
[ Or ]
Run dnsmanager utility without any arguements to get menu driven actions.

EOF
			;;
	esac
else
	fn_main_menu
fi
