#!/bin/bash

f_set_next_server() {
	echo "Setting next-server as $1 . . ."
	sed -i "/next-server/s/\(prod\|test\|dev\)-tftp/$1/g" /etc/dhcp/dhcpd.conf  
	echo "Restarting dhcpd service . . ."
	systemctl restart dhcpd
	if systemctl is-active dhcpd &>/dev/null ;then echo -e "done\n" ;else -e "failed restarting dhcpd\n";fi
	echo -e "FYI : $(host $1)\n"
}

f_main_menu() {
	v_input_provided=$1
	if [[ $v_input_provided =~ ^[123]$ ]] 
	then
		v_pxe_network=$v_input_provided
	else
        	clear
		echo -e "\nScript to change next-server option in /etc/dhcp/dhcpd.conf file\n"
		echo -e "Select the Network in which PXE booting is required :\n"
		echo -e "1) Prod Network ( 192.168.168.0/24)"
		echo -e "2) Test Network ( 10.10.10.0/24)"
		echo -e "3) Dev  Network ( 172.16.16.0/24)"
		echo -e "q) Exit without any changes\n"
		read -p "Choose Option Number : " v_pxe_network 
	fi

	case $v_pxe_network in 
		1 ) f_set_next_server "prod-tftp"
		;;

		2 ) f_set_next_server "test-tftp"
		;;

		3 ) f_set_next_server "dev-tftp"  
		;;

		q ) echo -e "\nExiting without any changes to /etc/dhcp/dhcpd.conf\n"
		    exit	
		;;

		* ) echo -e "\nEntered Option is Wrong !!!\n" 
	    	    read -p"Press Enter to go back to main menu <ENTER>"
            	    f_main_menu
        	;;
	esac
}

f_main_menu $1

exit
