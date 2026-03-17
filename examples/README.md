# Examples

This directory contains example YAML manifests for deploying ECS resources using the AWS ACK ECS Controller.

## Files

### 01-ecs-cluster.yaml

기본 ECS 클러스터와 Capacity Providers를 생성하는 예제입니다.

포함 사항:
- ECS Cluster 생성
- Container Insights 활성화
- Capacity Providers 설정 (FARGATE, FARGATE_SPOT)

배포 방법:

```bash
kubectl apply -f examples/01-ecs-cluster.yaml

# 상태 확인
kubectl get cluster
kubectl describe cluster example-cluster
```

### 02-task-definition-and-service.yaml

ECS Task Definition과 Service를 생성하는 예제입니다.

포함 사항:
- FARGATE 호환성이 있는 Task Definition
- CloudWatch Logs 통합
- ALB 연동 Service
- 자동 스케일링 설정

배포 방법:

```bash
# 주의: 파일의 ACCOUNT_ID, subnet ID, security group ID를 자신의 환경에 맞게 수정 필요
sed -i 's/ACCOUNT_ID/YOUR_ACCOUNT_ID/g' examples/02-task-definition-and-service.yaml
sed -i 's/subnet-12345678/YOUR_SUBNET_ID/g' examples/02-task-definition-and-service.yaml

kubectl apply -f examples/02-task-definition-and-service.yaml

# 상태 확인
kubectl get taskdefinition
kubectl get service
kubectl describe service example-service
```

## 사용 전 필수 수정 사항

### 1. AWS Account ID

파일의 `ACCOUNT_ID`를 자신의 AWS 계정 ID로 변경:

```bash
export ACCOUNT_ID=$(aws sts get-caller-identity --query Account --output text)
```

### 2. VPC 설정

ECS 서비스가 실행될 VPC의 설정을 지정:

```bash
# Subnet IDs 확인
aws ec2 describe-subnets --filters Name=vpc-id,Values=vpc-xxxxx \
  --query 'Subnets[].SubnetId' --output text

# Security Group ID 확인
aws ec2 describe-security-groups --filters Name=vpc-id,Values=vpc-xxxxx \
  --query 'SecurityGroups[].GroupId' --output text
```

### 3. IAM Role ARN

Task Definition의 IAM Role ARN을 확인 및 설정:

```bash
# Execution Role ARN
aws iam get-role --role-name ecsTaskExecutionRole \
  --query 'Role.Arn' --output text

# Task Role ARN
aws iam get-role --role-name ecsTaskRole \
  --query 'Role.Arn' --output text
```

### 4. Load Balancer (선택사항)

ALB를 사용하는 경우 Target Group ARN 설정:

```bash
# Target Group 확인
aws elbv2 describe-target-groups \
  --query 'TargetGroups[0].TargetGroupArn' --output text
```

## 일반적인 사용 사례

### 단순한 웹 애플리케이션 배포

```bash
# 1. 클러스터 생성
kubectl apply -f examples/01-ecs-cluster.yaml

# 2. Task Definition 및 Service 생성
kubectl apply -f examples/02-task-definition-and-service.yaml

# 3. 서비스 상태 확인
kubectl get service example-service
```

### 마이크로서비스 애플리케이션

여러 개의 서비스를 배포:

```bash
# 서비스별 파일 생성 후 배포
kubectl apply -f examples/

# 모든 리소스 확인
kubectl get clusters,taskdefinitions,services
```

### GitOps 워크플로우

ArgoCD와 함께 사용:

```bash
# examples 디렉토리를 Git 저장소에 커밋
git add examples/
git commit -m "Add ECS resource examples"
git push

# ArgoCD Application에서 examples 경로를 모니터링하도록 설정
```

## 트러블슈팅

### 리소스 생성 실패

```bash
# 상태 확인
kubectl describe cluster example-cluster

# 이벤트 확인
kubectl get events --field-selector involvedObject.name=example-cluster

# 로그 확인
kubectl logs -n ack-system -l app.kubernetes.io/name=aws-controllers-k8s-ecs-chart
```

### Service가 실행되지 않음

```bash
# Task Definition 확인
kubectl get taskdefinition
kubectl describe taskdefinition example-task:1

# IAM Role 권한 확인
aws ias get-role-policy --role-name ecsTaskExecutionRole
```

## 추가 예제 작성

사용자는 이 파일들을 기반으로 자신의 요구에 맞게 수정하여 추가 예제를 작성할 수 있습니다.

참고 자료:
- [AWS ACK ECS Controller API Reference](https://github.com/aws-controllers-k8s/ecs-controller)
- [ECS Task Definition Parameters](https://docs.aws.amazon.com/AmazonECS/latest/developerguide/task_definition_parameters.html)
- [ECS Service Parameters](https://docs.aws.amazon.com/AmazonECS/latest/developerguide/service_definition_parameters.html)
