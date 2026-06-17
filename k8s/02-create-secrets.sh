#!/bin/bash
# ============================================================
# Create Kubernetes secrets - run this ONCE on master node
# DO NOT commit actual secrets to git
# ============================================================

NAMESPACE="demandportal"

# Generate a strong secret key
SECRET_KEY=$(openssl rand -hex 32)

# Set your PostgreSQL credentials
POSTGRES_USER="cloudrequest_user"
POSTGRES_PASSWORD=$(openssl rand -base64 24)

echo "Creating secrets in namespace: $NAMESPACE"

kubectl create secret generic cloudrequest-secrets \
  --namespace=$NAMESPACE \
  --from-literal=postgres-user=$POSTGRES_USER \
  --from-literal=postgres-password=$POSTGRES_PASSWORD \
  --from-literal=database-url="postgresql://$POSTGRES_USER:$POSTGRES_PASSWORD@postgres-svc:5432/cloudrequest" \
  --from-literal=secret-key=$SECRET_KEY \
  --dry-run=client -o yaml | kubectl apply -f -

echo ""
echo "Secrets created. Save these values securely:"
echo "POSTGRES_USER:     $POSTGRES_USER"
echo "POSTGRES_PASSWORD: $POSTGRES_PASSWORD"
echo "SECRET_KEY:        $SECRET_KEY"
echo ""
echo "Also set DATABASE_URL in GitHub Secrets:"
echo "postgresql://$POSTGRES_USER:$POSTGRES_PASSWORD@postgres-svc:5432/cloudrequest"
