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

echo -e "\nStarted service configure-k8s-worker-suse . . .\n"

echo -e "\nUpgrading all installed packages in the system if required . . .\n"
fn_check_internet_connectivity
zypper clean -a 
zypper refresh
fn_check_internet_connectivity
zypper update -y 

echo -e "\nInstalling some basic required packages . . .\n"
fn_check_internet_connectivity
zypper install -y curl wget rsync

var_k8s_host=$(hostname -f)
var_k8s_cfg_dir='/root/configure-k8s-worker-suse'
var_logs_wget="${var_k8s_cfg_dir}/logs-configure-k8s-worker-suse.log"
var_k8s_release_version='v0.17.2'  ## Refer https://github.com/kubernetes/release
var_containerd_version='v1.7.20'   ## Refer https://github.com/containerd/containerd
var_runc_version='v1.1.13'         ## Refer https://github.com/opencontainers/runc

mkdir -p "${var_k8s_cfg_dir}"

clear

fn_check_internet_connectivity

echo -e "\nLooking for latest version detail of k8s . . .\n"	

if ! wget -P "${var_k8s_cfg_dir}"/ https://dl.k8s.io/release/stable.txt -a "${var_logs_wget}" 
then
	echo -e "\nError fetching lattest version details of k8s from https://dl.k8s.io/release/stable.txt !! \n"
	var_k8s_version='v1.31.0'
	echo -e "\nk8s version is set to last known version ${var_k8s_version}"
else
	var_k8s_version=$(cat "${var_k8s_cfg_dir}"/stable.txt)
	echo -e "\nThe latest version of k8s is ${var_k8s_version}"
fi


if [ ! -f "${var_k8s_cfg_dir}"/completed-stage1 ]
then
	clear

	echo -e "\nStarting stage-1 of k8s worker node configuration on ${var_k8s_host} . . .\n"

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

	echo -e "\nCompleted stage-1 of k8s worker node configuration on ${var_k8s_host} ! \n"

	touch "${var_k8s_cfg_dir}"/completed-stage1

	sleep 2

fi


if [ ! -f "${var_k8s_cfg_dir}"/completed-stage2 ]
then
	clear

	echo -e "\nStarting stage-2 of k8s worker node configuration on ${var_k8s_host} . . .\n"

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

	echo -e "\nCompleted stage-2 of k8s worker node configuration on ${var_k8s_host} ! \n"

	touch "${var_k8s_cfg_dir}"/completed-stage2
fi


echo -e "Starting kubelet.service . . .\n"

systemctl enable --now kubelet.service

systemctl status kubelet.service

echo -e "\nIgnore if kubelet.service service is not running! \n"

echo -e "\nThe kubelet.service will start automatically when this worker node is joined with ctrl-plane node! \n"

echo -e "\nSuccessfully completed installation and configuration of k8s "${var_k8s_version}" worker node! \n"

echo -e "\nFrom ctrl-plane node,\nRun \"kubeadm token create --print-join-command\" to create join command.\n"

echo -e "\nJoin the worker node ${var_k8s_host} with k8s cluster using above provided kubeadm join command.\n"

systemctl disable configure-k8s-worker-suse.service

} | tee -a /dev/tty0 /root/configure-k8s-worker-suse/logs-configure-k8s-worker-suse.log
