# AWS ACK ECS Controller Troubleshooting Guide

이 가이드는 AWS ACK ECS Controller 배포 및 운영 중에 발생할 수 있는 일반적인 문제와 해결 방법을 제공합니다.

## Table of Contents

1. [Pre-Deployment Issues](#pre-deployment-issues)
2. [Deployment Issues](#deployment-issues)
3. [Runtime Issues](#runtime-issues)
4. [Permission Issues](#permission-issues)
5. [Resource Creation Issues](#resource-creation-issues)
6. [Logging and Debugging](#logging-and-debugging)

## Pre-Deployment Issues

### kubectl이 설치되지 않음

에러 메시지:
```
command not found: kubectl
```

해결 방법:

```bash
# macOS
brew install kubectl

# Ubuntu/Debian
sudo apt-get update && sudo apt-get install -y kubectl

# 또는 AWS에서 제공하는 바이너리 사용
curl -o kubectl https://amazon-eks.s3.us-west-2.amazonaws.com/1.24.11/2023-03-17/bin/linux/amd64/kubectl
chmod +x ./kubectl
sudo mv ./kubectl /usr/local/bin
```

### ArgoCD가 클러스터에 설치되지 않음

에러 메시지:
```
error: namespace "argocd" not found
```

해결 방법:

```bash
# ArgoCD 설치
kubectl create namespace argocd
kubectl apply -n argocd -f https://raw.githubusercontent.com/argoproj/argo-cd/stable/manifests/install.yaml

# ArgoCD 상태 확인
kubectl get pods -n argocd

# ArgoCD로그인 (선택)
argocd login <ARGOCD_SERVER> --username admin --password <PASSWORD>
```

### OIDC Provider가 설정되지 않음

에러 메시지:
```
Error: OIDC provider not found
```

해결 방법:

```bash
# OIDC Provider 자동 설정
export CLUSTER_NAME=my-eks-cluster
export AWS_REGION=us-east-1

eksctl utils associate-iam-oidc-provider \
  --cluster=$CLUSTER_NAME \
  --region=$AWS_REGION \
  --approve

# OIDC Provider 확인
aws iam list-open-id-connect-providers
```

## Deployment Issues

### ArgoCD Application이 Pending 상태

증상:
- Application status가 "OutOfSync" 또는 "Unknown"으로 유지
- Pod가 생성되지 않음

진단:

```bash
# Application 상태 확인
argocd app get aws-ack-ecs-controller

# Application의 Event 확인
kubectl describe application -n argocd aws-ack-ecs-controller

# Helm 차트 repo 확인
helm repo list
helm repo update

# 차트 설치 가능 여부 확인
helm search repo aws-controllers-k8s-ecs-chart
```

해결 방법:

```bash
# 1. ArgoCD 서버 로그 확인
kubectl logs -n argocd -l app.kubernetes.io/name=argocd-server

# 2. 차트 리포지토리 업데이트
helm repo add aws https://aws.github.io/eks-charts
helm repo update

# 3. Application 재동기화
argocd app sync aws-ack-ecs-controller --force

# 4. Application 삭제 후 재생성
kubectl delete application -n argocd aws-ack-ecs-controller
kubectl apply -f application.yaml
```

### Namespace에서 권한 오류

에러:
```
Error creating apply patch object: invalid type for complex field "status"
```

해결 방법:

```bash
# 1. Namespace 권한 확인
kubectl auth can-i create deployments --as=system:serviceaccount:ack-system:ack-ecs-controller -n ack-system

# 2. ServiceAccount 권한 확인
kubectl auth can-i create clusters --as=system:serviceaccount:ack-system:ack-ecs-controller

# 3. RBAC 재적용
kubectl delete clusterrole ack-ecs-controller
kubectl delete clusterrolebinding ack-ecs-controller
kubectl apply -f bootstrap/rbac.yaml
```

## Runtime Issues

### Pod가 CrashLoopBackOff 상태

증상:
```
aws-ack-ecs-controller   0/1     CrashLoopBackOff   5          2m
```

진단:

```bash
# Pod 로그 확인 (가장 중요)
kubectl logs -n ack-system -l app.kubernetes.io/name=aws-controllers-k8s-ecs-chart --tail=100

# Pod 이전 로그 확인
kubectl logs -n ack-system <pod-name> --previous

# Pod 상세 정보
kubectl describe pod -n ack-system <pod-name>

# Pod 이벤트 확인
kubectl get events -n ack-system --sort-by='.lastTimestamp'
```

일반적인 원인과 해결 방법:

### 원인 1: IAM 권한 부족

에러 로그:
```
[ERROR] AccessDenied: User is not authorized to perform ecs:DescribeServices
```

해결 방법:

```bash
export ROLE_NAME=ack-ecs-controller-role

# 현재 연결된 정책 확인
aws iam list-attached-role-policies --role-name $ROLE_NAME

# 필수 정책 연결
aws iam attach-role-policy \
  --role-name $ROLE_NAME \
  --policy-arn arn:aws:iam::aws:policy/AmazonECS_FullAccess
```

### 원인 2: IRSA 토큰 문제

에러 로그:
```
[ERROR] Failed to assume role
```

진단:

```bash
# 1. ServiceAccount 확인
kubectl get serviceaccount -n ack-system ack-ecs-controller

# 2. 토큰 확인
kubectl describe serviceaccount -n ack-system ack-ecs-controller

# 3. IAM Role ARN 확인
kubectl get serviceaccount -n ack-system ack-ecs-controller \
  -o jsonpath='{.metadata.annotations.eks\.amazonaws\.com/role-arn}'

# 4. 환경 변수 확인
kubectl exec -it -n ack-system <pod-name> -- env | grep AWS

# 5. Pod에서 AWS Credential 확인
kubectl exec -it -n ack-system <pod-name> -- \
  curl -s http://169.254.169.254/latest/meta-data/iam/security-credentials/
```

해결 방법:

```bash
# 1. ServiceAccount의 IAM Role ARN 확인 및 수정
kubectl patch serviceaccount ack-ecs-controller -n ack-system -p \
  '{"metadata":{"annotations":{"eks.amazonaws.com/role-arn":"arn:aws:iam::ACCOUNT_ID:role/ack-ecs-controller-role"}}}'

# 2. Pod 재시작
kubectl rollout restart deployment/aws-ack-ecs-controller -n ack-system

# 3. 로그 재확인
kubectl logs -n ack-system -f -l app.kubernetes.io/name=aws-controllers-k8s-ecs-chart
```

### 원인 3: 메모리 부족

에러 로그:
```
OOMKilled
```

해결 방법:

```bash
# 메모리 사용량 확인
kubectl top pod -n ack-system

# Helm values에서 메모리 제한 증가
# aws-ack-controller/values.yaml 수정:
resources:
  limits:
    memory: 512Mi  # 256Mi에서 증가
  requests:
    memory: 256Mi  # 128Mi에서 증가

# 변경사항 적용
argocd app sync aws-ack-ecs-controller
```

## Permission Issues

### IRSA 권한 확인

IRSA (IAM Roles for Service Accounts)가 제대로 작동하는지 확인:

```bash
# 1. ServiceAccount에 IAM Role ARN이 있는지 확인
kubectl get serviceaccount -n ack-system ack-ecs-controller -o yaml | grep role-arn

# 2. Pod의 환경 변수 확인
kubectl exec -it -n ack-system <pod-name> -- env | grep -E "AWS_ROLE|AWS_WEB_IDENTITY"

# 3. STS에서 역할 가정 가능 여부 확인
aws sts assume-role-with-web-identity \
  --role-arn arn:aws:iam::$(aws sts get-caller-identity --query Account --output text):role/ack-ecs-controller-role \
  --role-session-name test-session \
  --web-identity-token $(kubectl exec -it -n ack-system <pod-name> -- cat /var/run/secrets/eks.amazonaws.com/serviceaccount/token)
```

### Trust Policy 문제

에러:
```
Not authorized to perform: sts:AssumeRoleWithWebIdentity
```

해결 방법:

```bash
# Trust Policy 확인
aws iam get-role --role-name ack-ecs-controller-role

# Trust Policy 상세 확인
aws iam get-role --role-name ack-ecs-controller-role --query 'Role.AssumeRolePolicyDocument'

# Trust Policy 업데이트 (필요한 경우)
export ACCOUNT_ID=$(aws sts get-caller-identity --query Account --output text)
export AWS_REGION=us-east-1
export OIDC_ID=$(aws eks describe-cluster --name my-eks-cluster --region $AWS_REGION --query 'cluster.identity.oidc.issuer' --output text | cut -d '/' -f 5)

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

aws iam update-assume-role-policy-document \
  --role-name ack-ecs-controller-role \
  --policy-document file://trust-policy.json
```

## Resource Creation Issues

### Cluster 리소스 생성 실패

테스트 Cluster 리소스:

```yaml
apiVersion: ecs.services.k8s.aws/v1alpha1
kind: Cluster
metadata:
  name: test-cluster
spec:
  clusterName: test-cluster
```

생성:

```bash
kubectl apply -f - << EOF
apiVersion: ecs.services.k8s.aws/v1alpha1
kind: Cluster
metadata:
  name: test-cluster
spec:
  clusterName: test-cluster
EOF
```

상태 확인:

```bash
# 리소스 생성 여부 확인
kubectl get cluster

# 상세 정보 확인
kubectl describe cluster test-cluster

# 이벤트 확인
kubectl get events --field-selector involvedObject.name=test-cluster
```

문제 해결:

```bash
# 1. Controller 상태 확인
kubectl get deployment -n ack-system

# 2. Controller 로그 확인
kubectl logs -n ack-system -l app.kubernetes.io/name=aws-controllers-k8s-ecs-chart -f

# 3. CRD 확인
kubectl get crd | grep ecs

# 4. API 리소스 확인
kubectl api-resources | grep ecs
```

### CRD가 설치되지 않음

증상:
```
error: resource mapping not found for name: "test-cluster" namespace: "" from "cluster.yaml": no matches for kind "Cluster" in version "ecs.services.k8s.aws/v1alpha1"
```

해결 방법:

```bash
# 1. CRD 설치 상태 확인
kubectl get crd | grep ecs

# 2. 모든 CRD 확인
kubectl get crd

# 3. Helm 차트 재배포
argocd app delete aws-ack-ecs-controller
kubectl apply -f application.yaml

# 4. Pod 상태 확인
kubectl get pods -n ack-system -w
```

## Logging and Debugging

### 상세 로깅 활성화

Log level을 debug로 변경:

```bash
# 환경 변수 직접 수정
kubectl set env deployment/aws-ack-ecs-controller \
  -n ack-system \
  LOG_LEVEL=debug

# Pod 재시작 확인
kubectl get pods -n ack-system -w

# 로그 확인
kubectl logs -n ack-system -f -l app.kubernetes.io/name=aws-controllers-k8s-ecs-chart
```

### 네트워크 문제 진단

```bash
# Pod의 DNS 확인
kubectl exec -it -n ack-system <pod-name> -- nslookup kubernetes.default
kubectl exec -it -n ack-system <pod-name> -- nslookup sts.amazonaws.com

# AWS API 접근성 확인
kubectl exec -it -n ack-system <pod-name> -- curl -s https://sts.amazonaws.com

# Security Group 확인
aws ec2 describe-security-groups --filter Name=group-id,Values=<sg-id>
```

### 유용한 커맨드

```bash
# 전체 상태 확인
bash scripts/check-prerequisites.sh

# Pod 실시간 모니터링
watch kubectl get pods -n ack-system

# 모든 이벤트 확인 (시간순)
kubectl get events -n ack-system --sort-by='.lastTimestamp'

# Helm Release 상태 확인
helm list -n ack-system

# ArgoCD 상태 확인
argocd app get aws-ack-ecs-controller
argocd app logs aws-ack-ecs-controller

# Webhook 테스트
kubectl api-resources | grep ecs
```

## 추가 리소스

- [AWS ACK ECS Controller GitHub Issues](https://github.com/aws-controllers-k8s/ecs-controller/issues)
- [AWS ACK Documentation](https://aws-controllers-k8s.github.io/community/)
- [EKS Troubleshooting Guide](https://docs.aws.amazon.com/eks/latest/userguide/troubleshooting.html)
- [Kubernetes Troubleshooting](https://kubernetes.io/docs/tasks/debug-application-cluster/troubleshooting/)
