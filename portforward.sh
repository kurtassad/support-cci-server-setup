#!/bin/bash

# Script to port-forward ArgoCD, Prometheus, Jaeger, and Nomad

set -e

# Colors for output
GREEN='\033[0;32m'
BLUE='\033[0;34m'
YELLOW='\033[1;33m'
NC='\033[0m' # No Color

echo -e "${BLUE}Starting port-forwards for ArgoCD, Prometheus, Jaeger, and Nomad...${NC}"

# Find ArgoCD server pod
ARGOCD_POD=$(kubectl get pods -n argocd -l app.kubernetes.io/name=argocd-server -o jsonpath='{.items[0].metadata.name}' 2>/dev/null)
if [ -z "$ARGOCD_POD" ]; then
    echo -e "${YELLOW}Warning: ArgoCD server pod not found${NC}"
else
    echo -e "${GREEN}Found ArgoCD pod: ${ARGOCD_POD}${NC}"
    kubectl port-forward -n argocd "$ARGOCD_POD" 8080:8080 > /dev/null 2>&1 &
    ARGOCD_PID=$!
    echo -e "${GREEN}ArgoCD port-forward started (PID: $ARGOCD_PID)${NC}"
    echo -e "${GREEN}  → http://localhost:8080${NC}"
fi

# Find Prometheus server pod
PROMETHEUS_POD=$(kubectl get pods -n monitoring -l app.kubernetes.io/name=prometheus,app.kubernetes.io/component=server -o jsonpath='{.items[0].metadata.name}' 2>/dev/null)
if [ -z "$PROMETHEUS_POD" ]; then
    echo -e "${YELLOW}Warning: Prometheus server pod not found${NC}"
else
    echo -e "${GREEN}Found Prometheus pod: ${PROMETHEUS_POD}${NC}"
    kubectl port-forward -n monitoring "$PROMETHEUS_POD" 9090:9090 > /dev/null 2>&1 &
    PROMETHEUS_PID=$!
    echo -e "${GREEN}Prometheus port-forward started (PID: $PROMETHEUS_PID)${NC}"
    echo -e "${GREEN}  → http://localhost:9090${NC}"
fi

# Port-forward Jaeger UI to 7070
JAEGER_POD=$(kubectl get pods -n monitoring -l app.kubernetes.io/name=jaeger -o jsonpath='{.items[0].metadata.name}' 2>/dev/null)
if [ -z "$JAEGER_POD" ]; then
    echo -e "${YELLOW}Warning: Jaeger pod not found${NC}"
else
    echo -e "${GREEN}Found Jaeger pod: ${JAEGER_POD}${NC}"
    kubectl port-forward -n monitoring "$JAEGER_POD" 7070:16686 > /dev/null 2>&1 &
    JAEGER_PID=$!
    echo -e "${GREEN}Jaeger port-forward started (PID: $JAEGER_PID)${NC}"
    echo -e "${GREEN}  → http://localhost:7070${NC}"
fi

# Port-forward Nomad UI via socat helper
echo -e "${BLUE}Setting up Nomad UI port-forward...${NC}"
# Check if socat helper service exists
if kubectl get svc nomad-ui-proxy -n circleci-server > /dev/null 2>&1; then
    kubectl port-forward -n circleci-server svc/nomad-ui-proxy 4646:4646 > /dev/null 2>&1 &
    NOMAD_PID=$!
    echo -e "${GREEN}Nomad UI port-forward started (PID: $NOMAD_PID)${NC}"
    echo -e "${GREEN}  → http://localhost:4646/ui/jobs${NC}"
else
    echo -e "${YELLOW}Warning: nomad-ui-proxy service not found in circleci-server namespace${NC}"
    echo -e "${YELLOW}Please deploy the socat helper first or check if CircleCI is installed${NC}"
fi

echo ""
echo -e "${BLUE}Port-forwards are running in the background.${NC}"
echo -e "${YELLOW}Press Ctrl+C to stop all port-forwards.${NC}"
echo ""

# Function to cleanup on exit
cleanup() {
    echo ""
    echo -e "${YELLOW}Stopping port-forwards...${NC}"
    if [ ! -z "$ARGOCD_PID" ]; then
        kill $ARGOCD_PID 2>/dev/null || true
        echo -e "${GREEN}Stopped ArgoCD port-forward${NC}"
    fi
    if [ ! -z "$PROMETHEUS_PID" ]; then
        kill $PROMETHEUS_PID 2>/dev/null || true
        echo -e "${GREEN}Stopped Prometheus port-forward${NC}"
    fi
    if [ ! -z "$JAEGER_PID" ]; then
        kill $JAEGER_PID 2>/dev/null || true
        echo -e "${GREEN}Stopped Jaeger port-forward${NC}"
    fi
    if [ ! -z "$NOMAD_PID" ]; then
        kill $NOMAD_PID 2>/dev/null || true
        echo -e "${GREEN}Stopped Nomad port-forward${NC}"
    fi
    exit 0
}

# Trap Ctrl+C
trap cleanup SIGINT SIGTERM

# Wait for user to press Ctrl+C
wait