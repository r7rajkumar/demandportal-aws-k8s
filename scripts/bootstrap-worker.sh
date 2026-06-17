#!/bin/bash
# ============================================================
# Bootstrap script for Kubernetes WORKER nodes
# Run this on EACH worker after master is ready
# Usage: sudo bash bootstrap-worker.sh "<join-command>"
# ============================================================
set -e

WORKER_NUM=${1:-"1"}
HOSTNAME="k8s-worker-$WORKER_NUM"

echo "============================================"
echo " CloudRequest K8s Worker Bootstrap"
echo " Hostname: $HOSTNAME"
echo "============================================"

# Set hostname
hostnamectl set-hostname $HOSTNAME

# Run the join command (paste from master's /opt/k8s/join-command.sh)
echo "Joining cluster..."
echo "Paste the join command from master's /opt/k8s/join-command.sh and press Enter:"
echo "(Or run: sudo bash bootstrap-worker.sh after copying the join command)"

# If join command passed as argument
if [ ! -z "$2" ]; then
  eval "$2 --node-name=$HOSTNAME"
else
  echo ""
  echo "Manual step: copy and run this from master:"
  echo "  cat /opt/k8s/join-command.sh"
  echo ""
  echo "Then run the output on this worker node."
fi

echo ""
echo "Worker node setup complete. Verify on master with: kubectl get nodes"
