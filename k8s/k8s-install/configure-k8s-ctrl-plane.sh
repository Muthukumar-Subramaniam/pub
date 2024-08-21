#!/bin/bash

if [[ "$1" == "-y" ]]
then
	:
else
	while :
	do
		echo
		read -r -p "Do you really want to run this script $(basename "$0") ? (yes/no) : " var_get_confirmation
		if [[ "$var_get_confirmation" == "yes" ]]
		then
			break
		elif [[ "$var_get_confirmation" == "no" ]]
		then
			echo -e "\nExiting without any changes!\n"
			exit
		else
			echo -e "\nInvalid Input!\n"
			continue
		fi
	done
fi


{

fn_check_internet_connectivity() {
	while :
	do
		echo -e "\nChecking Internet connectivity as the next step requires it . . ."
		if ! ping -c 1 google.com &>/dev/null
		then 
			echo -e "\nInternet connection is down! "
			echo -e "Waiting for 15 seconds to check again . . .\n"
			sleep 15
			continue
		else
			echo -e "\nInternet connection is active.\n"
			break
		fi
	done
}


fn_set_variables() {

	var_k8s_host=$(hostname -f)
	var_k8s_cfg_dir='/root/configure-k8s-ctrl-plane'
	var_logs_wget="${var_k8s_cfg_dir}/logs-configure-k8s-ctrl-plane.log"
	var_k8s_release_version='v0.17.2'  ## Refer https://github.com/kubernetes/release
	var_containerd_version='v1.7.20'   ## Refer https://github.com/containerd/containerd
	var_runc_version='v1.1.13'         ## Refer https://github.com/opencontainers/runc
	var_calico_version='v3.28.1'       ## Refer https://github.com/projectcalico/calico
	var_csi_smb_version='v1.15.0'      ## Refer https://github.com/kubernetes-csi/csi-driver-smb

	mkdir -p "${var_k8s_cfg_dir}"

	clear

	fn_check_internet_connectivity

	echo -e "\nLooking for latest version detail of k8s . . .\n"	

	if ! wget -P "${var_k8s_cfg_dir}"/ https://dl.k8s.io/release/stable.txt -a "${var_logs_wget}" 
	then
		echo -e "\nError fetching lattest version details of k8s from https://dl.k8s.io/release/stable.txt !! \n"
		var_k8s_version='v1.31.0'
		echo -e "\nk8s version is set to last known version ${var_k8s_version}"
		exit
	else
		var_k8s_version=$(cat "${var_k8s_cfg_dir}"/stable.txt)
		echo -e "\nThe latest version of k8s is ${var_k8s_version}"
	fi
}


fn_stage1_configuration() {

	var_k8s_host="${1}"
	var_k8s_cfg_dir="${2}"
	var_logs_wget="${3}"
	var_containerd_version="${4}"
	var_runc_version="${5}"
	
	if [ ! -f "${var_k8s_cfg_dir}"/completed-stage1 ]
	then
		clear

		echo -e "\nStarting stage-1 of k8s ctrl-plane node configuration on ${var_k8s_host} . . .\n"

		echo -e "\nLoading required kernel modules . . .\n"

		modprobe -vv overlay
		modprobe -vv br_netfilter

cat << EOF | tee /etc/modules-load.d/k8s.conf
overlay
br_netfilter
EOF

		echo -e "\nLoading required kernel parameters . . .\n"

cat << EOF | tee /etc/sysctl.d/k8s.conf
net.ipv4.ip_forward = 1
net.bridge.bridge-nf-call-ip6tables = 1
net.bridge.bridge-nf-call-iptables = 1
EOF

		sysctl --system

		fn_check_internet_connectivity

		echo -e "\nDownloading container runtime containerd . . ."
		echo "(This might take some time depending on the internet speed)"

		mkdir "${var_k8s_cfg_dir}"/containerd

		wget -P "${var_k8s_cfg_dir}"/containerd/ https://github.com/containerd/containerd/releases/download/"${var_containerd_version}"/containerd-"${var_containerd_version:1}"-linux-amd64.tar.gz -a "${var_logs_wget}" 

		echo -e "\nConfiguring containerd . . .\n"

		tar Cxzvf "${var_k8s_cfg_dir}"/containerd/ "${var_k8s_cfg_dir}"/containerd/containerd-"${var_containerd_version:1}"-linux-amd64.tar.gz

		chmod +x "${var_k8s_cfg_dir}"/containerd/bin/*

		rsync -avPh "${var_k8s_cfg_dir}"/containerd/bin/ /usr/bin/

		mkdir -p /etc/containerd

		echo -e "\nChecking containerd version . . ."

		containerd --version

		containerd config default > /etc/containerd/config.toml

		sed -i "/SystemdCgroup/s/false/true/g" /etc/containerd/config.toml

		containerd config dump | grep SystemdCgroup

		fn_check_internet_connectivity

		echo -e "Downloading containerd.service file from github . . .\n"

		wget -P /etc/systemd/system/ https://raw.githubusercontent.com/containerd/containerd/main/containerd.service -a "${var_logs_wget}"

		sed -i  "/ExecStart=/s/\/usr\/local/\/usr/g" /etc/systemd/system/containerd.service

		echo -e "\nStarting the containerd.service . . .\n"

		systemctl daemon-reload

		systemctl enable --now containerd.service

		systemctl status containerd.service

		fn_check_internet_connectivity

		echo -e "\nDownloading low-level container runtime runc ( dependency of containerd ) . . ."
		echo "(This might take some time depending on the internet speed)"

		wget -P /usr/bin/ https://github.com/opencontainers/runc/releases/download/"${var_runc_version}"/runc.amd64 -a "${var_logs_wget}" 

		echo -e "\nConfiguring runc . . .\n"
		mv /usr/bin/runc.amd64 /usr/bin/runc
		chmod +x /usr/bin/runc

		runc --version

		echo -e "\nCompleted stage-1 of k8s ctrl-plane node configuration on ${var_k8s_host} ! \n"

		touch "${var_k8s_cfg_dir}"/completed-stage1

		sleep 2

	fi
}


fn_stage2_for_redhat_based() {

	var_k8s_host="${1}"
	var_k8s_cfg_dir="${2}"
	var_k8s_version="${3}"

	if [ ! -f "${var_k8s_cfg_dir}"/completed-stage2 ]
	then

		clear

		echo -e "\nStarting stage-2 of k8s ctrl-plane node configuration on ${var_k8s_host} . . .\n"

		fn_check_internet_connectivity

		echo -e "\nConfiguring k8s rpm repository and installing required packages . . .\n"

		var_k8s_version_major=$(echo "${var_k8s_version}" | cut -d "." -f 1)
		var_k8s_version_minor=$(echo "${var_k8s_version}" | cut -d "." -f 2)
		var_k8s_version_major_minor="${var_k8s_version_major}.${var_k8s_version_minor}"

cat << EOF | tee /etc/yum.repos.d/k8s.repo
[k8s-${var_k8s_version_major_minor}]
name=k8s-${var_k8s_version_major_minor}
baseurl=https://pkgs.k8s.io/core:/stable:/${var_k8s_version_major_minor}/rpm/
enabled=1
gpgcheck=1
gpgkey=https://pkgs.k8s.io/core:/stable:/${var_k8s_version_major_minor}/rpm/repodata/repomd.xml.key
exclude=kubelet kubeadm kubectl cri-tools kubernetes-cni
EOF

		dnf makecache
		dnf install -y kubelet kubeadm kubectl --disableexcludes=k8s-"${var_k8s_version_major_minor}"

		echo -e "\nCompleted stage-2 of k8s ctrl-plane node configuration on ${var_k8s_host} ! \n"

		touch "${var_k8s_cfg_dir}"/completed-stage2
	fi
}


fn_stage2_for_debian_based() {

	var_k8s_host="${1}"
	var_k8s_cfg_dir="${2}"
	var_k8s_version="${3}"

	if [ ! -f "${var_k8s_cfg_dir}"/completed-stage2 ]
	then
		clear

		echo -e "\nStarting stage-2 of k8s ctrl-plane node configuration on ${var_k8s_host} . . .\n"

		fn_check_internet_connectivity

		echo -e "\nConfiguring k8s deb repository and installing required packages . . .\n"

		var_k8s_version_major=$(echo "${var_k8s_version}" | cut -d "." -f 1)
		var_k8s_version_minor=$(echo "${var_k8s_version}" | cut -d "." -f 2)
		var_k8s_version_major_minor="${var_k8s_version_major}.${var_k8s_version_minor}"

		echo "deb [signed-by=/etc/apt/keyrings/k8s-apt-keyring-${var_k8s_version_major_minor}.gpg] https://pkgs.k8s.io/core:/stable:/${var_k8s_version_major_minor}/deb/ /" | sudo tee /etc/apt/sources.list.d/k8s.list

		curl -fsSL https://pkgs.k8s.io/core:/stable:/"${var_k8s_version_major_minor}"/deb/Release.key | sudo gpg --dearmor -o /etc/apt/keyrings/k8s-apt-keyring-"${var_k8s_version_major_minor}".gpg

		apt-get update

		apt-get install -y kubelet kubeadm kubectl

		apt-mark hold kubelet kubeadm kubectl

		echo -e "\nCompleted stage-2 of k8s ctrl-plane node configuration on ${var_k8s_host} ! \n"

		touch "${var_k8s_cfg_dir}"/completed-stage2
	fi
}


fn_stage2_for_suse_based() {

	var_k8s_host="${1}"
	var_k8s_cfg_dir="${2}"
	var_logs_wget="${3}"
	var_k8s_version="${4}"
	var_k8s_release_version="${5}"

	if [ ! -f "${var_k8s_cfg_dir}"/completed-stage2 ]
	then
		clear

		echo -e "\nStarting stage-2 of k8s ctrl-plane node configuration on ${var_k8s_host} . . .\n"

		fn_check_internet_connectivity

		echo -e "\nConfiguring k8s rpm repository and installing required packages . . .\n"

		var_k8s_version_major=$(echo "${var_k8s_version}" | cut -d "." -f 1)
		var_k8s_version_minor=$(echo "${var_k8s_version}" | cut -d "." -f 2)
		var_k8s_version_major_minor="${var_k8s_version_major}.${var_k8s_version_minor}"

cat <<EOF | tee /etc/zypp/repos.d/k8s.repo
[k8s-${var_k8s_version_major_minor}]
name=k8s-${var_k8s_version_major_minor}
baseurl=https://pkgs.k8s.io/core:/stable:/${var_k8s_version_major_minor}/rpm/
enabled=1
gpgcheck=1
gpgkey=https://pkgs.k8s.io/core:/stable:/${var_k8s_version_major_minor}/rpm/repodata/repomd.xml.key
EOF

		fn_check_internet_connectivity

		zypper --gpg-auto-import-keys refresh

		fn_check_internet_connectivity
		
		zypper install -y kubeadm kubectl		

		zypper addlock kubeadm kubectl

		zypper ll

		fn_check_internet_connectivity

		echo -e "Installing required pacakges for kubelet as kubelet package has dependency issue. . ."
		echo -e "(This issue is to be fixed in the next upcoming patch release v1.31.1)"
		echo -e "(https://github.com/kubernetes/release/issues/3714)"

		zypper refresh
		zypper install -y conntrack-tools socat

		fn_check_internet_connectivity

		echo -e "\nDownloading and installing kubelet seperately. . ."
		echo -e "(This issue is to be fixed in the next upcoming patch release v1.31.1)"
		echo -e "(https://github.com/kubernetes/release/issues/3714)"
		echo "(This might take some time depending on the internet speed)"

		wget -P /usr/bin/ https://dl.k8s.io/release/"${var_k8s_version}"/bin/linux/amd64/kubelet -a "${var_logs_wget}"

                chmod +x /usr/bin/kubelet

                echo -e "\nChecking kubelet version . . ."

                kubelet --version

		fn_check_internet_connectivity

		echo -e "\nDownloading kubelet.service from github . . .\n"
		echo "(This might take some time depending on the internet speed)"

		wget -P /usr/lib/systemd/system/ https://raw.githubusercontent.com/kubernetes/release/"${var_k8s_release_version}"/cmd/krel/templates/latest/kubelet/kubelet.service  -a "${var_logs_wget}"

		sudo mkdir -p /usr/lib/systemd/system/kubelet.service.d

		fn_check_internet_connectivity

		echo -e "\nDownloading 10-kubeadm.conf from github . . .\n"
		echo "(This might take some time depending on the internet speed)"

		wget -P /usr/lib/systemd/system/kubelet.service.d/ https://raw.githubusercontent.com/kubernetes/release/"${var_k8s_release_version}"/cmd/krel/templates/latest/kubeadm/10-kubeadm.conf -a "${var_logs_wget}"

		echo -e "\nCompleted stage-2 of k8s ctrl-plane node configuration on ${var_k8s_host} ! \n"

		touch "${var_k8s_cfg_dir}"/completed-stage2
	fi
}


fn_stage3_configuration() {

	var_k8s_host="${1}"
	var_k8s_cfg_dir="${2}"
	var_logs_wget="${3}"
	var_calico_version="${4}"
	var_csi_smb_version="${5}"
	
	if [ ! -f "${var_k8s_cfg_dir}"/completed-stage3 ]
	then
		echo -e "Starting kubelet.service . . .\n"

		systemctl enable --now kubelet.service

		systemctl status kubelet.service

		#Below are k8s  ctrl-plane node specific configurations

		fn_check_internet_connectivity

		echo -e "\nPulling required images of k8s core pods . . ."
		echo -e "(This might take considerable amount of time depending on the internet speed)\n"

		nice -n -20 kubeadm config images pull

		echo -e "\nStarting cluster creation . . .\n"

		#kubeadm init --pod-network-cidr=10.8.0.0/16
		kubeadm init

		echo -e "\nStarting cluster configuration . . .\n"

		echo 'export KUBECONFIG=/etc/kubernetes/admin.conf' >>/root/.bashrc
		echo "source <(kubectl completion bash)" >>/root/.bashrc
		# shellcheck disable=SC1091
		source /root/.bashrc

		mkdir -p /root/.kube
		cp -i /etc/kubernetes/admin.conf /root/.kube/config
		chown root:root /root/.kube/config

		while true :
		do
			echo -e "\nWaiting for API Server pod to come online . . .\n"
        		if ! kubectl get pods -n kube-system | grep kube-apiserver | grep Running
        		then
				kubectl get pods -n kube-system | grep kube-apiserver
                		sleep 2
                		continue
        		else
                		kubectl get pods -n kube-system | grep kube-apiserver | grep Running
                		break
        		fi
		done

		fn_check_internet_connectivity

		echo -e "\nDownloading the manifest for Calico CNI ( Container Network Interface ) . . .\n"

		#Calico CNI ( Container Network Interface )
		wget -P "${var_k8s_cfg_dir}"/ https://raw.githubusercontent.com/projectcalico/calico/"${var_calico_version}"/manifests/calico.yaml -a "${var_logs_wget}"

		echo -e "\nConfiguring calico by setting pod network as 10.8.0.0/16 . . .\n"

		sed -i -e "/CALICO_IPV4POOL_CIDR/s/ #//g" -e "/192.168.0.0/s/ #//g" "${var_k8s_cfg_dir}"/calico.yaml
		sed -i "s/192.168.0.0/10.8.0.0/g" "${var_k8s_cfg_dir}"/calico.yaml
		grep 10.8.0.0 -B 4 "${var_k8s_cfg_dir}"/calico.yaml
		kubectl apply -f "${var_k8s_cfg_dir}"/calico.yaml

		#In Case if you want to use tigera operator instead of basic calcio CNI setup
		#kubectl create -f https://raw.githubusercontent.com/projectcalico/calico/${var_calico_version}/manifests/tigera-operator.yaml
		#wget -P ${var_k8s_cfg_dir}/  https://raw.githubusercontent.com/projectcalico/calico/${var_calico_version}/manifests/custom-resources.yaml
		#sed -i 's/cidr: 192\.168\.0\.0\/16/cidr: 10.8.0.0\/16/g' ${var_k8s_cfg_dir}/custom-resources.yaml
		#kubectl create -f ${var_k8s_cfg_dir}/custom-resources.yaml
		
		kubectl get nodes

		echo -e "\nCommand to join worker nodes is located in ${var_k8s_cfg_dir}/worker-node-join-command !! \n"

		sleep 2

		clear

		echo -e "\nProceeding with post-installation configurations . . .\n"

		# Waiting for control plane to become ready
		while :
		do
			echo -e "\nWaiting for ctrl-plane to get Ready . . .\n"
			if kubectl get nodes | grep -w " Ready " &>/dev/null
			then
				kubectl get nodes
				kubectl get pods -A
				break
			else
				kubectl get nodes
				kubectl get pods -A
				sleep 2
				continue
			fi
		done

		fn_check_internet_connectivity

		echo -e "\nInstalling CSI SMB drivers by remote internet connection . . .\n" 

		curl -skSL https://raw.githubusercontent.com/kubernetes-csi/csi-driver-smb/"${var_csi_smb_version}"/deploy/install-driver.sh | bash -s "${var_csi_smb_version}" --

		# Wait until all pods are running

		while :
		do
			echo -e "\nWaiting for CSI SMB pods creation to start . . .\n"
			if kubectl get pods --all-namespaces | grep csi-smb;then break;fi
			sleep 2
		done

		while :
		do
			echo -e "\nWaiting for all the required ctrl-plane pods to come online . . .\n"
			if kubectl get pods --all-namespaces -o jsonpath='{.items[*].status.containerStatuses[*].ready}' | grep false &>/dev/nul
			then 
				kubectl get pods --all-namespaces
				sleep 5
				continue
			else 
				echo -e "\nAll the required pods for ctrl-plane are now Running! \n"
				kubectl get pods --all-namespaces
				break
			fi
		done

		if [ -f /scripts_by_muthu/muthuks-server/k8s/k8s-setup-apply.sh ]
		then
			ln -s /scripts_by_muthu/muthuks-server/k8s/k8s-setup-apply.sh /usr/bin/k8s-apply
		fi

		if [ -f /scripts_by_muthu/muthuks-server/k8s/k8s-setup-delete.sh ]
		then
			ln -s /scripts_by_muthu/muthuks-server/k8s/k8s-setup-delete.sh /usr/bin/k8s-delete
		fi

		if [ -f /etc/systemd/system/configure-k8s-ctrl-plane.service ]
		then
			systemctl disable configure-k8s-ctrl-plane.service
		fi

		echo -e "\nCompleted stage-3 of k8s ctrl-plane node configuration on ${var_k8s_host} ! \n"

		touch "${var_k8s_cfg_dir}"/completed-stage3

		echo -e "\nSuccessfully completed installation and configuration of k8s ctrl-plane node! \n"

		kubectl get nodes
	fi
}


fn_recursive_stage1_configuration() {
	fn_stage1_configuration "${var_k8s_host}" "${var_k8s_cfg_dir}" "${var_logs_wget}" "${var_containerd_version}" "${var_runc_version}"
}

echo -e "\nStarted service configure-k8s-ctrl-plane . . .\n"

if grep -i -E "rhel|fedora" /etc/os-release &>/dev/null
then
	echo -e "\nUpgrading all installed packages in the system if required . . .\n"
	fn_check_internet_connectivity
	dnf clean all
	dnf update --refresh -y
	echo -e "\nInstalling some required basic packages . . .\n"
	fn_check_internet_connectivity
	dnf install -y curl wget rsync
	fn_set_variables
	fn_recursive_stage1_configuration
	fn_stage2_for_redhat_based "${var_k8s_host}" "${var_k8s_cfg_dir}" "${var_k8s_version}"
fi

if grep -i -E "ubuntu|debian" /etc/os-release &>/dev/null
then
	echo -e "\nUpgrading all installed packages in the system if required . . .\n"
	fn_check_internet_connectivity
	apt-get clean 
	apt-get update
	fn_check_internet_connectivity
	apt-get upgrade -y
	echo -e "\nInstalling some required basic packages . . .\n"
	fn_check_internet_connectivity
	apt-get install -y curl wget rsync gpg
	fn_set_variables
	fn_recursive_stage1_configuration
	fn_stage2_for_debian_based "${var_k8s_host}" "${var_k8s_cfg_dir}" "${var_k8s_version}"
fi

if grep -i "suse" /etc/os-release &>/dev/null
then
	echo -e "\nUpgrading all installed packages in the system if required . . .\n"
	fn_check_internet_connectivity
	zypper clean -a 
	zypper refresh
	fn_check_internet_connectivity
	zypper update -y 
	echo -e "\nInstalling some basic required packages . . .\n"
	fn_check_internet_connectivity
	zypper install -y curl wget rsync
	fn_set_variables
	fn_recursive_stage1_configuration
	fn_stage2_for_suse_based "${var_k8s_host}" "${var_k8s_cfg_dir}" "${var_logs_wget}" "${var_k8s_version}" "${var_k8s_release_version}" 
fi


fn_stage3_configuration "${var_k8s_host}" "${var_k8s_cfg_dir}" "${var_logs_wget}" "${var_calico_version}" "${var_csi_smb_version}"

} | tee -a /dev/tty0 /root/configure-k8s-ctrl-plane/logs-configure-k8s-ctrl-plane.log
