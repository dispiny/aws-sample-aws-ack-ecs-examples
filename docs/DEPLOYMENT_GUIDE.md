# AWS ACK ECS Controller Deployment Guide

이 가이드는 Kubernetes 클러스터에 AWS Controllers for Kubernetes (ACK) ECS Controller를 ArgoCD를 통해 배포하는 상세한 절차를 설명합니다.

## Table of Contents

1. [Prerequisites](#prerequisites)
2. [AWS Setup](#aws-setup)
3. [Kubernetes Setup](#kubernetes-setup)
4. [Deployment](#deployment)
5. [Verification](#verification)
6. [Post-Deployment Configuration](#post-deployment-configuration)

## Prerequisites

배포를 시작하기 전에 다음 항목들이 준비되어 있는지 확인하세요:

### 필수 사항

- AWS Account with appropriate permissions
- EKS Cluster (v1.21 이상)
- kubectl configured to access your EKS cluster
- ArgoCD installed in the cluster
- AWS CLI v2 이상

### 선택 사항

- eksctl: EKS 관리 도구
- argocd CLI: ArgoCD 명령줄 도구

### 권한 확인

다음 AWS 권한이 필요합니다:

- IAM role/policy 생성 및 관리 권한
- EKS cluster access 권한
- EC2 및 ECS 관련 권한 (controller가 사용)

### 준비 작업

```bash
# 1. Prerequisites 확인
bash scripts/check-prerequisites.sh

# 2. AWS 계정 정보 확인
aws sts get-caller-identity

# 3. EKS 클러스터 확인
kubectl cluster-info
kubectl get nodes

# 4. ArgoCD 설치 확인
kubectl get namespace argocd
kubectl get pods -n argocd
```

## AWS Setup

### OIDC Provider 설정

AWS IAM Roles for Service Accounts (IRSA)를 사용하려면 먼저 OIDC Provider를 설정해야 합니다.

#### 방법 1: eksctl 사용 (권장)

```bash
export CLUSTER_NAME=my-eks-cluster
export AWS_REGION=us-east-1

eksctl utils associate-iam-oidc-provider \
  --cluster=$CLUSTER_NAME \
  --region=$AWS_REGION \
  --approve
```

#### 방법 2: AWS CLI 사용

```bash
export CLUSTER_NAME=my-eks-cluster
export AWS_REGION=us-east-1

# OIDC Issuer URL 가져오기
OIDC_URL=$(aws eks describe-cluster \
  --name $CLUSTER_NAME \
  --region $AWS_REGION \
  --query 'cluster.identity.oidc.issuer' \
  --output text)

OIDC_ARN="arn:aws:iam::$(aws sts get-caller-identity --query Account --output text):oidc-provider/$(echo $OIDC_URL | cut -d '/' -f 5-)"

# OIDC Provider 생성
aws iam create-open-id-connect-provider \
  --url $OIDC_URL \
  --client-id-list sts.amazonaws.com
```

### IAM Role 생성

#### Trust Policy 준비

```bash
export CLUSTER_NAME=my-eks-cluster
export AWS_REGION=us-east-1
export ACCOUNT_ID=$(aws sts get-caller-identity --query Account --output text)

# OIDC ID 가져오기
OIDC_ID=$(aws eks describe-cluster \
  --name $CLUSTER_NAME \
  --region $AWS_REGION \
  --query 'cluster.identity.oidc.issuer' \
  --output text | cut -d '/' -f 5)

# Trust Policy 생성
cat > trust-policy.json << EOF
{
  "Version": "2012-10-17",
  "Statement": [
    {
      "Effect": "Allow",
      "Principal": {
        "Federated": "arn:aws:iam::${ACCOUNT_ID}:oidc-provider/oidc.eks.${AWS_REGION}.amazonaws.com/id/${OIDC_ID}"
      },
      "Action": "sts:AssumeRoleWithWebIdentity",
      "Condition": {
        "StringEquals": {
          "oidc.eks.${AWS_REGION}.amazonaws.com/id/${OIDC_ID}:sub": "system:serviceaccount:ack-system:ack-ecs-controller"
        }
      }
    }
  ]
}
EOF
```

#### Role 생성

```bash
export ROLE_NAME=ack-ecs-controller-role

aws iam create-role \
  --role-name $ROLE_NAME \
  --assume-role-policy-document file://trust-policy.json \
  --description "IAM role for ACK ECS Controller"

# 역할 생성 확인
aws iam get-role --role-name $ROLE_NAME
```

### IAM Policy 연결

```bash
export ROLE_NAME=ack-ecs-controller-role

# ECS Full Access Policy 연결
aws iam attach-role-policy \
  --role-name $ROLE_NAME \
  --policy-arn arn:aws:iam::aws:policy/AmazonECS_FullAccess

# CloudWatch Logs Full Access Policy 연결
aws iam attach-role-policy \
  --role-name $ROLE_NAME \
  --policy-arn arn:aws:iam::aws:policy/CloudWatchLogsFullAccess

# (선택) EC2 Full Access Policy 연결 (EC2 기반 ECS 클러스터 사용 시)
# aws iam attach-role-policy \
#   --role-name $ROLE_NAME \
#   --policy-arn arn:aws:iam::aws:policy/AmazonEC2FullAccess

# 정책 확인
aws iam list-attached-role-policies --role-name $ROLE_NAME
```

## Kubernetes Setup

### Namespace 생성

```bash
kubectl create namespace ack-system
kubectl label namespace ack-system app.kubernetes.io/name=aws-ack
```

### RBAC 설정 적용

```bash
kubectl apply -f bootstrap/rbac.yaml

# RBAC 확인
kubectl get clusterrole | grep ack-ecs-controller
kubectl get clusterrolebinding | grep ack-ecs-controller
kubectl get serviceaccount -n ack-system ack-ecs-controller
```

## Deployment

### ArgoCD Application 배포

#### Step 1: application.yaml 수정

```bash
# AWS Account ID 업데이트
export ACCOUNT_ID=$(aws sts get-caller-identity --query Account --output text)

sed -i "s/ACCOUNT_ID/${ACCOUNT_ID}/g" application.yaml

# 또는 macOS의 경우:
# sed -i '' "s/ACCOUNT_ID/${ACCOUNT_ID}/g" application.yaml
```

#### Step 2: Application 배포

```bash
# ArgoCD Application 생성
kubectl apply -f application.yaml

# Application 상태 확인
kubectl get application -n argocd aws-ack-ecs-controller
```

#### Step 3: 배포 진행 모니터링

```bash
# 실시간 상태 확인
argocd app watch aws-ack-ecs-controller

# 또는 kubectl로 확인
watch kubectl get pods -n ack-system
```

### 자동화 스크립트 사용

전체 배포 프로세스를 한 번에 수행하려면:

```bash
chmod +x scripts/deploy.sh
bash scripts/deploy.sh
```

스크립트가 자동으로 다음을 수행합니다:

- Prerequisites 확인
- IAM Role 생성
- Kubernetes 리소스 생성
- ArgoCD Application 배포
- 배포 상태 확인

## Verification

### Application 상태 확인

```bash
# ArgoCD Application 상태
argocd app get aws-ack-ecs-controller

# 또는
kubectl get application -n argocd aws-ack-ecs-controller -o jsonpath='{.status}'
```

### Pod 확인

```bash
# Pod 실행 여부 확인
kubectl get pods -n ack-system

# Pod의 상세 정보 확인
kubectl describe pod -n ack-system <pod-name>

# Pod 로그 확인
kubectl logs -n ack-system -l app.kubernetes.io/name=aws-controllers-k8s-ecs-chart
```

### ServiceAccount 및 IRSA 확인

```bash
# ServiceAccount 확인
kubectl get serviceaccount -n ack-system ack-ecs-controller

# IAM Role ARN 확인
kubectl get serviceaccount -n ack-system ack-ecs-controller -o jsonpath='{.metadata.annotations.eks\.amazonaws\.com/role-arn}'

# ServiceAccount의 JWT 토큰 확인 (선택)
kubectl get secret -n ack-system $(kubectl get secret -n ack-system | grep ack-ecs-controller-token | awk '{print $1}') -o jsonpath='{.data.token}' | base64 -d | jq .
```

### CRD 확인

```bash
# ECS 관련 CRD 확인
kubectl get crd | grep ecs

# CRD 상세 정보
kubectl describe crd clusters.ecs.services.k8s.aws
```

## Post-Deployment Configuration

### Helm Values 커스터마이징

배포 후 필요에 따라 설정을 조정할 수 있습니다:

```yaml
# aws-ack-controller/values.yaml 수정 예시

# 리플리카 수 증가 (고가용성)
replicaCount: 2

# 리소스 제한 조정
resources:
  limits:
    cpu: 500m
    memory: 512Mi
  requests:
    cpu: 250m
    memory: 256Mi

# 노드 셀렉터 추가
nodeSelector:
  workload-type: management

# Pod Disruption Budget 설정
podDisruptionBudget:
  enabled: true
  minAvailable: 1
```

### Monitoring 설정

Prometheus와 Grafana를 사용하여 controller 모니터링:

```yaml
serviceMonitor:
  enabled: true
  interval: 30s
  labels:
    prometheus: kube-prometheus
```

### Log Level 조정

로그 레벨을 변경하려면:

```bash
kubectl set env deployment/aws-ack-ecs-controller \
  -n ack-system \
  LOG_LEVEL=debug
```

## 다음 단계

1. ECS 리소스 생성 테스트
2. ArgoCD와의 GitOps 워크플로우 설정
3. Monitoring 및 Alerting 구성
4. Backup 및 Disaster Recovery 계획

## 문제 해결

배포 중 문제가 발생했을 경우 [Troubleshooting Guide](TROUBLESHOOTING.md)를 참고하세요.
