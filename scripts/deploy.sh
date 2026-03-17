#!/bin/bash

##############################################
# AWS ACK ECS Controller Deployment Script
##############################################

set -e

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

# Configuration
CLUSTER_NAME="${CLUSTER_NAME:-my-eks-cluster}"
REGION="${AWS_REGION:-us-east-1}"
ACCOUNT_ID=$(aws sts get-caller-identity --query Account --output text)
IAM_ROLE_NAME="ack-ecs-controller-role"
NAMESPACE="ack-system"
ARGOCD_NAMESPACE="argocd"

# Functions
print_header() {
  echo -e "${BLUE}================================${NC}"
  echo -e "${BLUE}$1${NC}"
  echo -e "${BLUE}================================${NC}"
}

print_success() {
  echo -e "${GREEN}✓ $1${NC}"
}

print_error() {
  echo -e "${RED}✗ $1${NC}"
}

print_warning() {
  echo -e "${YELLOW}⚠ $1${NC}"
}

print_info() {
  echo -e "${BLUE}ℹ $1${NC}"
}

# Check prerequisites
check_prerequisites() {
  print_header "Checking Prerequisites"
  
  local missing_tools=()
  
  # Check kubectl
  if ! command -v kubectl &> /dev/null; then
    missing_tools+=("kubectl")
  else
    print_success "kubectl is installed"
  fi
  
  # Check aws cli
  if ! command -v aws &> /dev/null; then
    missing_tools+=("aws")
  else
    print_success "AWS CLI is installed"
  fi
  
  # Check helm
  if ! command -v helm &> /dev/null; then
    missing_tools+=("helm")
  else
    print_success "Helm is installed"
  fi
  
  # Check argocd cli (optional)
  if ! command -v argocd &> /dev/null; then
    print_warning "argocd CLI is not installed (optional)"
  else
    print_success "ArgoCD CLI is installed"
  fi
  
  if [ ${#missing_tools[@]} -gt 0 ]; then
    print_error "Missing tools: ${missing_tools[*]}"
    exit 1
  fi
  
  # Check kubectl connectivity
  if ! kubectl cluster-info &> /dev/null; then
    print_error "Cannot connect to Kubernetes cluster"
    exit 1
  fi
  print_success "Connected to Kubernetes cluster"
  
  # Check ArgoCD installation
  if ! kubectl get namespace $ARGOCD_NAMESPACE &> /dev/null; then
    print_error "ArgoCD namespace not found"
    exit 1
  fi
  print_success "ArgoCD is installed"
}

# Create IAM Role
create_iam_role() {
  print_header "Creating IAM Role"
  
  # Get OIDC ID
  OIDC_ID=$(aws eks describe-cluster \
    --name $CLUSTER_NAME \
    --region $REGION \
    --query 'cluster.identity.oidc.issuer' \
    --output text | cut -d '/' -f 5)
  
  if [ -z "$OIDC_ID" ]; then
    print_warning "OIDC provider not found. Creating OIDC provider..."
    eksctl utils associate-iam-oidc-provider \
      --cluster=$CLUSTER_NAME \
      --region=$REGION \
      --approve
    
    OIDC_ID=$(aws eks describe-cluster \
      --name $CLUSTER_NAME \
      --region $REGION \
      --query 'cluster.identity.oidc.issuer' \
      --output text | cut -d '/' -f 5)
  fi
  
  print_info "OIDC ID: $OIDC_ID"
  
  # Check if role already exists
  if aws iam get-role --role-name $IAM_ROLE_NAME &> /dev/null; then
    print_warning "IAM Role $IAM_ROLE_NAME already exists"
  else
    # Create Trust Policy
    cat > /tmp/trust-policy.json << EOF
{
  "Version": "2012-10-17",
  "Statement": [
    {
      "Effect": "Allow",
      "Principal": {
        "Federated": "arn:aws:iam::${ACCOUNT_ID}:oidc-provider/oidc.eks.${REGION}.amazonaws.com/id/${OIDC_ID}"
      },
      "Action": "sts:AssumeRoleWithWebIdentity",
      "Condition": {
        "StringEquals": {
          "oidc.eks.${REGION}.amazonaws.com/id/${OIDC_ID}:sub": "system:serviceaccount:${NAMESPACE}:ack-ecs-controller"
        }
      }
    }
  ]
}
EOF
    
    # Create IAM Role
    aws iam create-role \
      --role-name $IAM_ROLE_NAME \
      --assume-role-policy-document file:///tmp/trust-policy.json \
      --region $REGION
    
    print_success "IAM Role $IAM_ROLE_NAME created"
  fi
  
  # Attach policies
  print_info "Attaching IAM policies..."
  
  aws iam attach-role-policy \
    --role-name $IAM_ROLE_NAME \
    --policy-arn arn:aws:iam::aws:policy/AmazonECS_FullAccess
  
  aws iam attach-role-policy \
    --role-name $IAM_ROLE_NAME \
    --policy-arn arn:aws:iam::aws:policy/CloudWatchLogsFullAccess
  
  print_success "IAM policies attached"
}

# Create Kubernetes resources
create_k8s_resources() {
  print_header "Creating Kubernetes Resources"
  
  # Create namespace
  print_info "Creating namespace $NAMESPACE..."
  kubectl create namespace $NAMESPACE --dry-run=client -o yaml | kubectl apply -f -
  print_success "Namespace created"
  
  # Apply RBAC
  print_info "Applying RBAC..."
  kubectl apply -f bootstrap/rbac.yaml
  print_success "RBAC applied"
}

# Deploy ArgoCD Application
deploy_argocd_app() {
  print_header "Deploying ArgoCD Application"
  
  # Update application.yaml with actual account ID
  print_info "Updating application.yaml with Account ID: $ACCOUNT_ID"
  
  if [ "$(uname)" == "Darwin" ]; then
    # macOS
    sed -i '' "s/ACCOUNT_ID/${ACCOUNT_ID}/g" application.yaml
  else
    # Linux
    sed -i "s/ACCOUNT_ID/${ACCOUNT_ID}/g" application.yaml
  fi
  
  # Apply ArgoCD Application
  print_info "Applying ArgoCD Application..."
  kubectl apply -f application.yaml
  
  print_success "ArgoCD Application deployed"
  
  # Wait for ArgoCD to sync
  print_info "Waiting for ArgoCD to sync (this may take a few minutes)..."
  sleep 10
}

# Verify deployment
verify_deployment() {
  print_header "Verifying Deployment"
  
  # Check Application status
  print_info "Checking ArgoCD Application status..."
  APP_STATUS=$(kubectl get application -n $ARGOCD_NAMESPACE aws-ack-ecs-controller -o jsonpath='{.status.operationState.phase}' 2>/dev/null || echo "Unknown")
  
  if [ "$APP_STATUS" == "Succeeded" ]; then
    print_success "ArgoCD Application is synced"
  else
    print_warning "ArgoCD Application status: $APP_STATUS"
  fi
  
  # Check Pod status
  print_info "Checking Pod status in namespace $NAMESPACE..."
  RUNNING_PODS=$(kubectl get pods -n $NAMESPACE --field-selector=status.phase=Running -o jsonpath='{.items[*].metadata.name}' 2>/dev/null | wc -w)
  
  if [ $RUNNING_PODS -gt 0 ]; then
    print_success "$RUNNING_PODS pod(s) running in namespace $NAMESPACE"
    kubectl get pods -n $NAMESPACE
  else
    print_warning "No running pods found in namespace $NAMESPACE"
  fi
  
  # Check ServiceAccount
  print_info "Checking ServiceAccount..."
  if kubectl get serviceaccount ack-ecs-controller -n $NAMESPACE &> /dev/null; then
    print_success "ServiceAccount ack-ecs-controller found"
    ROLE_ARN=$(kubectl get serviceaccount ack-ecs-controller -n $NAMESPACE -o jsonpath='{.metadata.annotations.eks\.amazonaws\.com/role-arn}')
    print_info "IAM Role ARN: $ROLE_ARN"
  fi
}

# Print summary
print_summary() {
  print_header "Deployment Summary"
  
  echo -e "${BLUE}AWS Account ID:${NC} $ACCOUNT_ID"
  echo -e "${BLUE}Cluster Name:${NC} $CLUSTER_NAME"
  echo -e "${BLUE}Region:${NC} $REGION"
  echo -e "${BLUE}IAM Role:${NC} $IAM_ROLE_NAME"
  echo -e "${BLUE}Namespace:${NC} $NAMESPACE"
  
  print_info "Useful commands:"
  echo "  # Check ArgoCD app status"
  echo "  argocd app get aws-ack-ecs-controller"
  echo ""
  echo "  # Check controller logs"
  echo "  kubectl logs -n $NAMESPACE -l app.kubernetes.io/name=aws-controllers-k8s-ecs-chart -f"
  echo ""
  echo "  # Check pod status"
  echo "  kubectl get pods -n $NAMESPACE -w"
  echo ""
  echo "  # Create ECS cluster resource"
  echo "  kubectl apply -f examples/ecs-cluster.yaml"
}

# Main execution
main() {
  print_header "AWS ACK ECS Controller Deployment"
  
  check_prerequisites
  create_iam_role
  create_k8s_resources
  deploy_argocd_app
  verify_deployment
  print_summary
  
  print_success "Deployment completed successfully!"
}

# Run main function
main
