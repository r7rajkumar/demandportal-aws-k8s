# CloudRequest — Production Kubernetes on AWS EC2

Self-Service Infrastructure Demand Portal deployed on a self-managed Kubernetes cluster.

## Architecture

```
GitHub Push → GitHub Actions CI/CD
    → Test → Security Scan (Trivy)
    → Build Docker Images → Push to ECR
    → Deploy to Kubernetes (kubeadm on EC2)
        ├── Master Node (t3.medium) — Control Plane
        ├── Worker Node 1 (t3.medium)
        └── Worker Node 2 (t3.medium)
            ├── React Frontend (2 replicas)
            ├── FastAPI Backend (2 replicas, HPA 2-10)
            ├── PostgreSQL (1 replica + PVC)
            ├── NGINX Ingress + TLS (cert-manager)
            ├── Network Policies
            └── RBAC
```

## Kubernetes Concepts Covered

| Concept | Where |
|---|---|
| Namespace | k8s/00-namespace.yaml |
| ResourceQuota + LimitRange | k8s/00-namespace.yaml |
| ConfigMap | k8s/01-configmap.yaml |
| Secrets | scripts/create-secrets.sh |
| Deployment + RollingUpdate | k8s/backend/, k8s/frontend/ |
| PersistentVolume + PVC | k8s/postgres/postgres.yaml |
| Services (ClusterIP, NodePort) | All deployments |
| Ingress + TLS | k8s/ingress/ingress.yaml |
| cert-manager (Let's Encrypt) | k8s/ingress/ingress.yaml |
| HPA (CPU + Memory) | k8s/hpa/hpa.yaml |
| Network Policies | k8s/network-policy/ |
| RBAC + ServiceAccounts | k8s/rbac/rbac.yaml |
| Liveness + Readiness Probes | All deployments |
| Pod Anti-Affinity | Backend + Frontend |
| Rolling Deployments | CI/CD pipeline |
| Rollback | CI/CD pipeline |
| Resource Limits + Requests | All deployments |

---

## Step-by-Step Deployment

### Prerequisites
- AWS account with existing VPC
- Terraform >= 1.5.0 installed
- AWS CLI configured (`aws configure`)
- SSH key pair (`~/.ssh/id_rsa`)
- GitHub repository with secrets configured

---

### Step 1 — Terraform: Provision Infrastructure

```bash
cd terraform
cp terraform.tfvars.example terraform.tfvars

# Edit terraform.tfvars — fill in:
# - vpc_id (your existing VPC)
# - your_ip_cidr (run: curl checkip.amazonaws.com)
nano terraform.tfvars

terraform init
terraform plan
terraform apply
```

Note the outputs:
```
master_public_ip  = "x.x.x.x"
worker_public_ips = ["x.x.x.x", "x.x.x.x"]
ecr_backend_url   = "xxxx.dkr.ecr.us-east-1.amazonaws.com/cloudrequest/backend"
ecr_frontend_url  = "xxxx.dkr.ecr.us-east-1.amazonaws.com/cloudrequest/frontend"
```

---

### Step 2 — Bootstrap Master Node

```bash
# SSH to master
ssh -i ~/.ssh/id_rsa ubuntu@<MASTER_PUBLIC_IP>

# Wait ~3 mins for userdata to finish, then run:
sudo bash /opt/k8s/bootstrap-master.sh

# Verify cluster
kubectl get nodes
```

Expected output:
```
NAME         STATUS     ROLES           AGE   VERSION
k8s-master   Ready      control-plane   2m    v1.29.x
```

---

### Step 3 — Join Worker Nodes

```bash
# On master - get join command
cat /opt/k8s/join-command.sh

# SSH to Worker 1
ssh -i ~/.ssh/id_rsa ubuntu@<WORKER_1_PUBLIC_IP>
sudo hostnamectl set-hostname k8s-worker-1
sudo <PASTE JOIN COMMAND HERE> --node-name=k8s-worker-1

# SSH to Worker 2
ssh -i ~/.ssh/id_rsa ubuntu@<WORKER_2_PUBLIC_IP>
sudo hostnamectl set-hostname k8s-worker-2
sudo <PASTE JOIN COMMAND HERE> --node-name=k8s-worker-2

# Verify on master
kubectl get nodes
```

Expected:
```
NAME           STATUS   ROLES           AGE   VERSION
k8s-master     Ready    control-plane   5m    v1.29.x
k8s-worker-1   Ready    <none>          2m    v1.29.x
k8s-worker-2   Ready    <none>          2m    v1.29.x
```

---

### Step 4 — Create Secrets

```bash
# On master node
chmod +x /opt/k8s/create-secrets.sh
# Copy scripts/create-secrets.sh to master, then run:
bash create-secrets.sh
```

---

### Step 5 — Configure kubeconfig for GitHub Actions

```bash
# On master - update kubeconfig to use public IP
MASTER_PUBLIC_IP=13.218.106.190
sed -i "s|https://.*:6443|https://$MASTER_PUBLIC_IP:6443|" ~/.kube/config

# Export base64 encoded kubeconfig
cat ~/.kube/config | base64 -w 0
# Copy this output - add as KUBE_CONFIG GitHub secret
```

---

### Step 6 — Configure GitHub Secrets

In your GitHub repo → Settings → Secrets → Actions, add:

| Secret | Value |
|---|---|
| `AWS_ACCESS_KEY_ID` | Your AWS access key |
| `AWS_SECRET_ACCESS_KEY` | Your AWS secret key |
| `KUBE_CONFIG` | Base64 kubeconfig from Step 5 |
| `APP_URL` | http://\<worker-public-ip\> |
| `WORKER_PUBLIC_IP` | Worker node public IP |

---

### Step 7 — Deploy Application

```bash
# Push to main branch to trigger CI/CD
git add .
git commit -m "Initial deployment"
git push origin main
```

Watch the pipeline in GitHub Actions → should complete in ~5-8 minutes.

---

### Step 8 — Access the Application

**Without domain (NodePort):**
```
http://<WORKER_PUBLIC_IP>:30080
```

**With domain (Ingress + TLS):**
1. Point your domain DNS A record to worker node public IP
2. Update k8s/ingress/ingress.yaml — replace YOUR_DOMAIN.com and YOUR_EMAIL
3. Apply: `kubectl apply -f k8s/ingress/ingress.yaml`
4. Access: `https://yourdomain.com`

---

## Local Development

```bash
docker-compose up --build

# Frontend: http://localhost:3000
# Backend:  http://localhost:8000
# API Docs: http://localhost:8000/docs
```

---

## Useful kubectl Commands

```bash
# Cluster health
kubectl get nodes
kubectl get pods -n cloudrequest
kubectl get svc -n cloudrequest
kubectl get ingress -n cloudrequest

# Scaling
kubectl get hpa -n cloudrequest
kubectl scale deployment cloudrequest-backend --replicas=5 -n cloudrequest

# Logs
kubectl logs -f deployment/cloudrequest-backend -n cloudrequest
kubectl logs -f deployment/cloudrequest-frontend -n cloudrequest

# Resource usage
kubectl top nodes
kubectl top pods -n cloudrequest

# Rollback
kubectl rollout history deployment/cloudrequest-backend -n cloudrequest
kubectl rollout undo deployment/cloudrequest-backend -n cloudrequest

# Describe for debugging
kubectl describe pod <pod-name> -n cloudrequest
kubectl describe deployment cloudrequest-backend -n cloudrequest

# Exec into pod
kubectl exec -it <pod-name> -n cloudrequest -- /bin/sh

# Network policies
kubectl get networkpolicy -n cloudrequest

# RBAC
kubectl get serviceaccounts -n cloudrequest
kubectl get rolebindings -n cloudrequest
```

---

## GitHub Secrets Required

| Secret | Description |
|---|---|
| `AWS_ACCESS_KEY_ID` | AWS IAM access key |
| `AWS_SECRET_ACCESS_KEY` | AWS IAM secret key |
| `KUBE_CONFIG` | Base64 kubeconfig from master |
| `APP_URL` | Application URL for frontend API config |
| `WORKER_PUBLIC_IP` | Worker node IP for smoke test |

---

## Project Structure

```
cloudrequest-k8s/
├── terraform/                  Infrastructure as Code
│   ├── main.tf                 EC2, Security Groups, ECR, IAM
│   ├── variables.tf
│   ├── outputs.tf
│   ├── terraform.tfvars.example
│   └── userdata/common.sh      EC2 bootstrap (K8s prereqs)
├── scripts/
│   ├── bootstrap-master.sh     kubeadm init + Calico + NGINX + cert-manager
│   ├── bootstrap-worker.sh     kubeadm join
│   └── create-secrets.sh       K8s secrets creation
├── backend/                    FastAPI application
│   ├── main.py
│   ├── requirements.txt
│   ├── Dockerfile
│   └── tests/
├── frontend/                   React application
│   ├── src/
│   ├── Dockerfile
│   └── nginx.conf
├── k8s/                        Kubernetes manifests
│   ├── 00-namespace.yaml       Namespace + ResourceQuota + LimitRange
│   ├── 01-configmap.yaml       ConfigMap
│   ├── postgres/               PostgreSQL + PVC
│   ├── backend/                Backend Deployment + Service
│   ├── frontend/               Frontend Deployment + Service
│   ├── ingress/                NGINX Ingress + cert-manager + TLS
│   ├── hpa/                    HPA for backend and frontend
│   ├── network-policy/         Pod-to-pod network security
│   └── rbac/                   ServiceAccounts + Roles + Bindings
├── .github/workflows/
│   └── deploy.yml              Full CI/CD pipeline
└── docker-compose.yml          Local development
```


