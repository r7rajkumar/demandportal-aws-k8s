#!/bin/bash
# ============================================================
# Bootstrap script for Kubernetes MASTER node
# Run this ONCE after Terraform provisions the master EC2
# Usage: sudo bash /opt/k8s/bootstrap-master.sh
# ============================================================
set -e

MASTER_PRIVATE_IP=$(curl -s http://169.254.169.254/latest/meta-data/local-ipv4)
MASTER_PUBLIC_IP=$(curl -s http://169.254.169.254/latest/meta-data/public-ipv4)
PROJECT_NAME=$(cat /opt/k8s/project-name.txt)

echo "============================================"
echo " CloudRequest K8s Master Bootstrap"
echo " Master Private IP: $MASTER_PRIVATE_IP"
echo " Master Public IP:  $MASTER_PUBLIC_IP"
echo "============================================"

# ─── Init cluster ───
echo "[1/6] Initialising Kubernetes cluster..."
kubeadm init \
  --pod-network-cidr=192.168.0.0/16 \
  --apiserver-advertise-address=$MASTER_PRIVATE_IP \
  --apiserver-cert-extra-sans=$MASTER_PUBLIC_IP \
  --node-name=k8s-master \
  --kubernetes-version=1.29.0 \
  | tee /opt/k8s/kubeadm-init.log

# ─── Configure kubectl for ubuntu user ───
echo "[2/6] Configuring kubectl..."
mkdir -p /home/ubuntu/.kube
cp /etc/kubernetes/admin.conf /home/ubuntu/.kube/config
chown ubuntu:ubuntu /home/ubuntu/.kube/config

# Also configure for root
mkdir -p /root/.kube
cp /etc/kubernetes/admin.conf /root/.kube/config

# ─── Install Calico CNI ───
echo "[3/6] Installing Calico CNI..."
sudo -u ubuntu kubectl apply -f https://raw.githubusercontent.com/projectcalico/calico/v3.26.0/manifests/calico.yaml

# ─── Install NGINX Ingress Controller ───
echo "[4/6] Installing NGINX Ingress Controller..."
sudo -u ubuntu kubectl apply -f https://raw.githubusercontent.com/kubernetes/ingress-nginx/controller-v1.8.2/deploy/static/provider/baremetal/deploy.yaml

# Patch NGINX to use NodePort 80/443
sudo -u ubuntu kubectl patch svc ingress-nginx-controller \
  -n ingress-nginx \
  --type='json' \
  -p='[{"op":"replace","path":"/spec/type","value":"NodePort"},
       {"op":"add","path":"/spec/ports/0/nodePort","value":30080},
       {"op":"add","path":"/spec/ports/1/nodePort","value":30443}]' || true

# ─── Install cert-manager ───
echo "[5/6] Installing cert-manager..."
sudo -u ubuntu kubectl apply -f https://github.com/cert-manager/cert-manager/releases/download/v1.13.0/cert-manager.yaml

echo "Waiting for cert-manager to be ready..."
sudo -u ubuntu kubectl wait --namespace cert-manager \
  --for=condition=ready pod \
  --selector=app.kubernetes.io/instance=cert-manager \
  --timeout=120s || echo "cert-manager still starting - check manually"

# ─── Install Metrics Server ───
echo "[6/6] Installing Metrics Server..."
sudo -u ubuntu kubectl apply -f https://github.com/kubernetes-sigs/metrics-server/releases/latest/download/components.yaml

# Patch metrics-server for self-signed certs (common in bare-metal)
sudo -u ubuntu kubectl patch deployment metrics-server \
  -n kube-system \
  --type='json' \
  -p='[{"op":"add","path":"/spec/template/spec/containers/0/args/-","value":"--kubelet-insecure-tls"}]'

# ─── Extract join command ───
echo ""
echo "Generating worker join command..."
JOIN_CMD=$(kubeadm token create --print-join-command)
echo "#!/bin/bash" > /opt/k8s/join-command.sh
echo "sudo $JOIN_CMD --node-name=\$(hostname)" >> /opt/k8s/join-command.sh
chmod +x /opt/k8s/join-command.sh

# ─── Extract kubeconfig for GitHub Actions ───
cat /home/ubuntu/.kube/config | base64 -w 0 > /opt/k8s/kubeconfig-base64.txt
echo ""
echo "============================================"
echo " Bootstrap Complete!"
echo "============================================"
echo ""
echo "Cluster status:"
sudo -u ubuntu kubectl get nodes
echo ""
echo "Join command saved to: /opt/k8s/join-command.sh"
echo "Run this on EACH worker node:"
echo ""
cat /opt/k8s/join-command.sh
echo ""
echo "KUBE_CONFIG for GitHub Actions (base64):"
echo "(copy the content of /opt/k8s/kubeconfig-base64.txt)"
echo ""
echo "NOTE: Replace server IP in kubeconfig with PUBLIC IP for GitHub Actions:"
echo "  sed -i 's|https://.*:6443|https://$MASTER_PUBLIC_IP:6443|' /home/ubuntu/.kube/config"
