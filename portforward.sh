#!/bin/bash

# Script to port-forward ArgoCD, Prometheus, Jaeger, Nomad, PostgreSQL, MongoDB, Redis, and Argo Rollouts

# Don't exit on errors - let all port-forwards attempt to start
set +e

pkill -f "kubectl port-forward" 2>/dev/null
sleep 1

# Colors for output
GREEN='\033[0;32m'
BLUE='\033[0;34m'
YELLOW='\033[1;33m'
NC='\033[0m' # No Color

echo -e "${BLUE}Starting port-forwards for ArgoCD, Prometheus, Jaeger, Nomad, PostgreSQL, MongoDB, and Redis...${NC}"

# Find ArgoCD server pod
ARGOCD_POD=$(kubectl get pods -n argocd -l app.kubernetes.io/name=argocd-server -o jsonpath='{.items[0].metadata.name}' 2>/dev/null)
if [ -z "$ARGOCD_POD" ]; then
    echo -e "${YELLOW}Warning: ArgoCD server pod not found${NC}"
else
    echo -e "${GREEN}Found ArgoCD pod: ${ARGOCD_POD}${NC}"
    echo -e "${GREEN}Starting ArgoCD port-forward on http://localhost:8080${NC}"
    kubectl port-forward -n argocd "$ARGOCD_POD" 8080:8080 > /dev/null 2>&1 &
    ARGOCD_PID=$!
    sleep 0.5
fi

# Find Prometheus server pod
PROMETHEUS_POD=$(kubectl get pods -n monitoring -l app.kubernetes.io/name=prometheus,app.kubernetes.io/component=server -o jsonpath='{.items[0].metadata.name}' 2>/dev/null)
if [ -z "$PROMETHEUS_POD" ]; then
    echo -e "${YELLOW}Warning: Prometheus server pod not found${NC}"
else
    echo -e "${GREEN}Found Prometheus pod: ${PROMETHEUS_POD}${NC}"
    echo -e "${GREEN}Starting Prometheus port-forward on http://localhost:9090${NC}"
    kubectl port-forward -n monitoring "$PROMETHEUS_POD" 9090:9090 > /dev/null 2>&1 &
    PROMETHEUS_PID=$!
    sleep 0.5
fi

# Port-forward Jaeger UI to 7070
JAEGER_POD=$(kubectl get pods -n monitoring -l app.kubernetes.io/name=jaeger -o jsonpath='{.items[0].metadata.name}' 2>/dev/null)
if [ -z "$JAEGER_POD" ]; then
    echo -e "${YELLOW}Warning: Jaeger pod not found${NC}"
else
    echo -e "${GREEN}Found Jaeger pod: ${JAEGER_POD}${NC}"
    echo -e "${GREEN}Starting Jaeger port-forward on http://localhost:7070${NC}"
    kubectl port-forward -n monitoring "$JAEGER_POD" 7070:16686 > /dev/null 2>&1 &
    JAEGER_PID=$!
    sleep 0.5
fi

# Port-forward Nomad UI via socat helper
echo -e "${BLUE}Setting up Nomad UI port-forward...${NC}"
# Check if socat helper service exists
if kubectl get svc nomad-ui-proxy -n circleci-server > /dev/null 2>&1; then
    echo -e "${GREEN}Starting Nomad UI port-forward on http://localhost:4646/ui/jobs${NC}"
    kubectl port-forward -n circleci-server svc/nomad-ui-proxy 4646:4646 > /dev/null 2>&1 &
    NOMAD_PID=$!
    sleep 0.5
else
    echo -e "${YELLOW}Warning: nomad-ui-proxy service not found in circleci-server namespace${NC}"
    echo -e "${YELLOW}Please deploy the socat helper first or check if CircleCI is installed${NC}"
fi

# Find PostgreSQL pod
POSTGRES_POD=$(kubectl get pods -n circleci-server -l app.kubernetes.io/name=postgresql -o jsonpath='{.items[0].metadata.name}' 2>/dev/null)
if [ -z "$POSTGRES_POD" ]; then
    echo -e "${YELLOW}Warning: PostgreSQL pod not found${NC}"
else
    echo -e "${GREEN}Found PostgreSQL pod: ${POSTGRES_POD}${NC}"
    echo -e "${GREEN}Starting PostgreSQL port-forward on localhost:5432${NC}"
    kubectl port-forward -n circleci-server "$POSTGRES_POD" 5432:5432 > /dev/null 2>&1 &
    POSTGRES_PID=$!
    sleep 0.5
fi

# Find MongoDB pod
MONGODB_POD=$(kubectl get pods -n circleci-server -l app.kubernetes.io/name=mongodb -o jsonpath='{.items[0].metadata.name}' 2>/dev/null)
if [ -z "$MONGODB_POD" ]; then
    echo -e "${YELLOW}Warning: MongoDB pod not found${NC}"
else
    echo -e "${GREEN}Found MongoDB pod: ${MONGODB_POD}${NC}"
    echo -e "${GREEN}Starting MongoDB port-forward on localhost:27018${NC}"
    kubectl port-forward -n circleci-server "$MONGODB_POD" 27018:27017 > /dev/null 2>&1 &
    MONGODB_PID=$!
    sleep 0.5
fi

# Find Redis master pod
REDIS_POD="redis-master-0"
if [ -z "$REDIS_POD" ]; then
    echo -e "${YELLOW}Warning: Redis pod not found${NC}"
else
    echo -e "${GREEN}Found Redis pod: ${REDIS_POD}${NC}"
    echo -e "${GREEN}Starting Redis port-forward on localhost:6379${NC}"
    kubectl port-forward -n circleci-server "$REDIS_POD" 6379:6379 > /dev/null 2>&1 &
    REDIS_PID=$!
    sleep 0.5
fi

# Port-forward Argo Rollouts dashboard
if kubectl get svc argo-rollouts-dashboard -n argo-rollouts > /dev/null 2>&1; then
    echo -e "${GREEN}Starting Argo Rollouts dashboard port-forward on http://localhost:3100${NC}"
    kubectl port-forward -n argo-rollouts svc/argo-rollouts-dashboard 3100:3100 > /dev/null 2>&1 &
    ROLLOUTS_PID=$!
    sleep 0.5
else
    echo -e "${YELLOW}Warning: Argo Rollouts dashboard service not found${NC}"
fi

echo ""
echo -e "${BLUE}All port-forwards started.${NC}"
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
    if [ ! -z "$POSTGRES_PID" ]; then
        kill $POSTGRES_PID 2>/dev/null || true
        echo -e "${GREEN}Stopped PostgreSQL port-forward${NC}"
    fi
    if [ ! -z "$MONGODB_PID" ]; then
        kill $MONGODB_PID 2>/dev/null || true
        echo -e "${GREEN}Stopped MongoDB port-forward${NC}"
    fi
    if [ ! -z "$REDIS_PID" ]; then
        kill $REDIS_PID 2>/dev/null || true
        echo -e "${GREEN}Stopped Redis port-forward${NC}"
    fi
    if [ ! -z "$ROLLOUTS_PID" ]; then
        kill $ROLLOUTS_PID 2>/dev/null || true
        echo -e "${GREEN}Stopped Argo Rollouts dashboard port-forward${NC}"
    fi
    exit 0
}

# Trap Ctrl+C
trap cleanup SIGINT SIGTERM

# Wait for user to press Ctrl+C
wait