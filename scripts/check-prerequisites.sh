#!/bin/bash

##############################################
# Prerequisites Check Script
##############################################

set -e

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m'

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

# Check individual tools
check_tool() {
  if command -v $1 &> /dev/null; then
    local version=$($1 --version 2>&1 || echo "Unknown")
    print_success "$1 is installed: $version"
    return 0
  else
    print_error "$1 is not installed"
    return 1
  fi
}

# Main execution
main() {
  print_header "Prerequisites Check"
  
  local all_ok=true
  
  print_info "Checking required tools..."
  echo ""
  
  # Check kubectl
  if ! check_tool kubectl; then
    all_ok=false
  fi
  
  # Check aws cli
  if ! check_tool aws; then
    all_ok=false
  fi
  
  # Check helm
  if ! check_tool helm; then
    all_ok=false
  fi
  
  # Check kubectl cluster connectivity
  echo ""
  print_info "Checking cluster connectivity..."
  if kubectl cluster-info &> /dev/null; then
    print_success "Connected to Kubernetes cluster"
  else
    print_error "Cannot connect to Kubernetes cluster"
    all_ok=false
  fi
  
  # Check ArgoCD namespace
  echo ""
  print_info "Checking ArgoCD installation..."
  if kubectl get namespace argocd &> /dev/null; then
    print_success "ArgoCD namespace found"
  else
    print_error "ArgoCD namespace not found"
    all_ok=false
  fi
  
  # Additional optional tools
  echo ""
  print_info "Checking optional tools..."
  
  if ! command -v argocd &> /dev/null; then
    print_warning "argocd CLI is not installed (optional)"
  else
    check_tool argocd
  fi
  
  if ! command -v eksctl &> /dev/null; then
    print_warning "eksctl is not installed (optional)"
  else
    check_tool eksctl
  fi
  
  echo ""
  if [ "$all_ok" = true ]; then
    print_success "All prerequisites are met!"
    exit 0
  else
    print_error "Some prerequisites are missing"
    exit 1
  fi
}

main
