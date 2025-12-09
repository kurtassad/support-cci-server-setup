#!/bin/bash

set -e

# Get secrets
POLICY_SECRET=$(kubectl get secrets -n circleci-server policy-service -o jsonpath={.data.postgres-app-password} | base64 -d)
MP_SECRET=$(kubectl get secrets -n circleci-server machine-provisioner-db-app -o jsonpath={.data.postgres-app-password} | base64 -d)
POSTGRES_PASSWORD=$(kubectl get secret -n circleci-server postgresql -o jsonpath={.data.postgres-password} | base64 -d)

# Update passwords using postgres password for authentication
kubectl exec -it -n circleci-server postgresql-0 -- env PGPASSWORD="$POSTGRES_PASSWORD" psql -U postgres -c "ALTER USER machineprovisioner_app_rw WITH PASSWORD '$MP_SECRET';"
kubectl exec -it -n circleci-server postgresql-0 -- env PGPASSWORD="$POSTGRES_PASSWORD" psql -U postgres -c "ALTER USER policyservice_app_rw WITH PASSWORD '$POLICY_SECRET';"

kubectl delete pods -n circleci-server -l app=policy-service
kubectl delete pods -n circleci-server -l app=policy-service-internal

echo "Passwords updated successfully"