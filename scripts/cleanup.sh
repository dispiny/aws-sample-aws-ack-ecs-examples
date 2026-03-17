#!/bin/bash

##############################################
# AWS ACK ECS Controller Cleanup Script
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

# Confirmation prompt
confirm_cleanup() {
  print_warning "This will delete the AWS ACK ECS Controller and associated resources"
  read -p "Are you sure? (yes/no): " -r
  REPLY=$(echo $REPLY | tr '[:upper:]' '[:lower:]')
  
  if [ "$REPLY" != "yes" ]; then
    print_info "Cleanup cancelled"
    exit 0
  fi
}

# Delete ArgoCD Application
delete_argocd_app() {
  print_header "Deleting ArgoCD Application"
  
  if kubectl get application -n $ARGOCD_NAMESPACE aws-ack-ecs-controller &> /dev/null; then
    print_info "Deleting ArgoCD Application..."
    kubectl delete application -n $ARGOCD_NAMESPACE aws-ack-ecs-controller
    print_success "ArgoCD Application deleted"
  else
    print_warning "ArgoCD Application not found"
  fi
  
  # Wait for deletion
  print_info "Waiting for resources to be deleted..."
  sleep 10
}

# Delete Kubernetes resources
delete_k8s_resources() {
  print_header "Deleting Kubernetes Resources"
  
  # Delete namespace
  if kubectl get namespace $NAMESPACE &> /dev/null; then
    print_info "Deleting namespace $NAMESPACE..."
    kubectl delete namespace $NAMESPACE
    print_success "Namespace deleted"
  else
    print_warning "Namespace $NAMESPACE not found"
  fi
}

# Delete IAM Role and policies
delete_iam_role() {
  print_header "Deleting IAM Role"
  
  if aws iam get-role --role-name $IAM_ROLE_NAME &> /dev/null; then
    print_info "Detaching policies from role $IAM_ROLE_NAME..."
    
    # Detach managed policies
    aws iam detach-role-policy \
      --role-name $IAM_ROLE_NAME \
      --policy-arn arn:aws:iam::aws:policy/AmazonECS_FullAccess|| true
    
    aws iam detach-role-policy \
      --role-name $IAM_ROLE_NAME \
      --policy-arn arn:aws:iam::aws:policy/CloudWatchLogsFullAccess || true
    
    # Delete inline policies
    INLINE_POLICIES=$(aws iam list-role-policies --role-name $IAM_ROLE_NAME --query 'PolicyNames[*]' --output text)
    for policy in $INLINE_POLICIES; do
      print_info "Deleting inline policy: $policy"
      aws iam delete-role-policy --role-name $IAM_ROLE_NAME --policy-name $policy
    done
    
    # Delete role
    print_info "Deleting IAM role $IAM_ROLE_NAME..."
    aws iam delete-role --role-name $IAM_ROLE_NAME
    print_success "IAM Role deleted"
  else
    print_warning "IAM Role $IAM_ROLE_NAME not found"
  fi
}

# Delete temporary files
cleanup_temp_files() {
  print_header "Cleaning Up Temporary Files"
  
  if [ -f "/tmp/trust-policy.json" ]; then
    rm /tmp/trust-policy.json
    print_success "Temporary files cleaned up"
  fi
}

# Print summary
print_summary() {
  print_header "Cleanup Summary"
  
  echo -e "${BLUE}Cluster Name:${NC} $CLUSTER_NAME"
  echo -e "${BLUE}Region:${NC} $REGION"
  echo -e "${BLUE}Namespace Deleted:${NC} $NAMESPACE"
  echo -e "${BLUE}IAM Role Deleted:${NC} $IAM_ROLE_NAME"
  
  print_warning "Note: Some AWS resources created by the controller (ECS clusters, task definitions, etc.) may still exist"
  print_info "Please manually delete these resources in the AWS Console if needed"
}

# Main execution
main() {
  print_header "AWS ACK ECS Controller Cleanup"
  
  confirm_cleanup
  delete_argocd_app
  delete_k8s_resources
  delete_iam_role
  cleanup_temp_files
  print_summary
  
  print_success "Cleanup completed successfully!"
}

# Run main function
main
