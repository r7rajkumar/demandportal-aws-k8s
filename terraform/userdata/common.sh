#!/bin/bash
set -e
exec > /var/log/k8s-userdata.log 2>&1

echo "=== Starting K8s node setup: ${node_role} ==="

# ─── System updates ───
apt-get update -y
apt-get install -y apt-transport-https ca-certificates curl gpg awscli jq

# ─── Disable swap ───
swapoff -a
sed -i '/ swap / s/^\(.*\)$/#\1/g' /etc/fstab

# ─── Kernel modules ───
cat <<EOF > /etc/modules-load.d/k8s.conf
overlay
br_netfilter
EOF
modprobe overlay
modprobe br_netfilter

# ─── Kernel parameters ───
cat <<EOF > /etc/sysctl.d/k8s.conf
net.bridge.bridge-nf-call-iptables  = 1
net.bridge.bridge-nf-call-ip6tables = 1
net.ipv4.ip_forward                 = 1
EOF
sysctl --system

# ─── Install containerd ───
apt-get install -y containerd
mkdir -p /etc/containerd
containerd config default > /etc/containerd/config.toml
sed -i 's/SystemdCgroup = false/SystemdCgroup = true/' /etc/containerd/config.toml
systemctl restart containerd
systemctl enable containerd

# ─── Install kubeadm, kubelet, kubectl ───
curl -fsSL https://pkgs.k8s.io/core:/stable:/v1.29/deb/Release.key | gpg --dearmor -o /etc/apt/keyrings/kubernetes-apt-keyring.gpg
echo 'deb [signed-by=/etc/apt/keyrings/kubernetes-apt-keyring.gpg] https://pkgs.k8s.io/core:/stable:/v1.29/deb/ /' > /etc/apt/sources.list.d/kubernetes.list
apt-get update -y
apt-get install -y kubelet=1.29.* kubeadm=1.29.* kubectl=1.29.*
apt-mark hold kubelet kubeadm kubectl
systemctl enable kubelet

# ─── Install AWS CLI v2 ───
curl "https://awscli.amazonaws.com/awscli-exe-linux-x86_64.zip" -o /tmp/awscliv2.zip
apt-get install -y unzip
unzip /tmp/awscliv2.zip -d /tmp
/tmp/aws/install --update

# ─── Create bootstrap scripts directory ───
mkdir -p /opt/k8s

echo "=== Node prerequisites installed: ${node_role} ==="
echo "${node_role}" > /opt/k8s/node-role.txt
echo "${project_name}" > /opt/k8s/project-name.txt
echo "${aws_region}" > /opt/k8s/aws-region.txt
