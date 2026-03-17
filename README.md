# AWS ACK ECS Controller with ArgoCD

AWS Controllers for Kubernetes (ACK) ECS Controller를 ArgoCD를 통해 Kubernetes 클러스터에 배포하는 프로젝트입니다.

## Project Structure

```
.
├── README.md
├── application.yaml          # ArgoCD Application 리소스
├── argocd/
│   └── README.md             # ArgoCD 배포 상세 가이드
├── aws-ack-controller/
│   ├── namespace.yaml        # ack-system 네임스페이스
│   ├── values.yaml           # Helm values 설정
│   └── kustomization.yaml    # Kustomization 파일
├── bootstrap/
│   ├── namespace.yaml        # 필수 네임스페이스
│   └── rbac.yaml             # RBAC 설정 및 IAM Role
├── scripts/
│   ├── deploy.sh             # 전체 배포 스크립트
│   └── cleanup.sh            # 클리너업 스크립트
└── docs/
    ├── DEPLOYMENT_GUIDE.md   # 상세 배포 가이드
    └── TROUBLESHOOTING.md    # 트러블슈팅 가이드
```

## Getting Started

## Getting Started

### Prerequisites

- EKS Cluster: AWS EKS 클러스터가 필요합니다
- kubectl: v1.21 이상
- ArgoCD: 클러스터에 설치되어 있어야 합니다
- AWS CLI: 최신 버전
- eksctl (Optional): EKS 관리 도구

### Deployment Steps

#### Step 1: Create IAM Role (Required)

```bash
# IAM Role 생성 (AWS 콘솔 또는 CLI)
ACCOUNT_ID=$(aws sts get-caller-identity --query Account --output text)
CLUSTER_NAME=my-eks-cluster
REGION=us-east-1

# Trust Policy 생성
cat > trust-policy.json << EOF
{
  "Version": "2012-10-17",
  "Statement": [
    {
      "Effect": "Allow",
      "Principal": {
        "Federated": "arn:aws:iam::${ACCOUNT_ID}:oidc-provider/oidc.eks.${REGION}.amazonaws.com/id/EXAMPLEID"
      },
      "Action": "sts:AssumeRoleWithWebIdentity",
      "Condition": {
        "StringEquals": {
          "oidc.eks.${REGION}.amazonaws.com/id/EXAMPLEID:sub": "system:serviceaccount:ack-system:ack-ecs-controller"
        }
      }
    }
  ]
}
EOF

# IAM Role 생성
aws iam create-role \
  --role-name ack-ecs-controller-role \
  --assume-role-policy-document file://trust-policy.json
```

#### Step 2: Attach IAM Policies

```bash
# ECS 관련 정책 연결
aws iam attach-role-policy \
  --role-name ack-ecs-controller-role \
  --policy-arn arn:aws:iam::aws:policy/AmazonECS_FullAccess

aws iam attach-role-policy \
  --role-name ack-ecs-controller-role \
  --policy-arn arn:aws:iam::aws:policy/CloudWatchLogsFullAccess
```

#### Step 3: Deploy ArgoCD Application

```bash
# application.yaml에서 ACCOUNT_ID를 자신의 AWS 계정 ID로 변경
sed -i "s/ACCOUNT_ID/$(aws sts get-caller-identity --query Account --output text)/g" application.yaml

# ArgoCD를 통해 배포
kubectl apply -f application.yaml
```

#### Step 4: Verify Deployment

```bash
# ArgoCD 앱 상태 확인
argocd app get aws-ack-ecs-controller

# Pod 상태 확인
kubectl get pods -n ack-system -w

# 로그 확인
kubectl logs -n ack-system -l app.kubernetes.io/name=aws-controllers-k8s-ecs-chart -f
```

## Configuration Guide

### Helm Values Customization

`aws-ack-controller/values.yaml` 파일을 수정하여 다음을 커스터마이징할 수 있습니다:

- Resource Limits: CPU, 메모리 설정
- Replica Count: 고가용성을 위해 2개 이상으로 설정
- Node Selector: 특정 노드에 배포 지정
- Log Level: debug, info, warn, error
- AWS Region: ECS 작업이 실행될 AWS 리전

### Example: High Availability Configuration

```yaml
replicaCount: 2

nodeSelector:
  workload-type: management

affinity:
  podAntiAffinity:
    preferredDuringSchedulingIgnoredDuringExecution:
    - weight: 100
      podAffinityTerm:
        topologyKey: kubernetes.io/hostname
```

## ArgoCD Integration

### Sync Policies

- Automated: 자동으로 변경사항 동기화
- Prune: 삭제된 리소스 자동 정리
- Self-Heal: 클러스터의 변경사항 자동 복구

### Manual Synchronization

```bash
argocd app sync aws-ack-ecs-controller
```

### Rollback

```bash
argocd app rollback aws-ack-ecs-controller
```

## Usage Examples

### Create ECS Cluster

```yaml
apiVersion: ecs.services.k8s.aws/v1alpha1
kind: Cluster
metadata:
  name: my-ecs-cluster
spec:
  clusterName: my-ecs-cluster
```

### Create ECS Task Definition

```yaml
apiVersion: ecs.services.k8s.aws/v1alpha1
kind: TaskDefinition
metadata:
  name: my-task-def
spec:
  family: my-task
  networkMode: awsvpc
  requiresCompatibilities:
  - FARGATE
  cpu: "256"
  memory: "512"
  containerDefinitions:
  - name: my-container
    image: my-app:latest
    portMappings:
    - containerPort: 8080
```

## Automated Deployment Scripts

### Full Deployment

```bash
bash scripts/deploy.sh
```

### Cleanup

```bash
bash scripts/cleanup.sh
```

## Documentation

더 자세한 내용은 아래 문서를 참고하세요:

- [Deployment Guide](docs/DEPLOYMENT_GUIDE.md)
- [Troubleshooting](docs/TROUBLESHOOTING.md)

## References

- [AWS ACK Documentation](https://aws-controllers-k8s.github.io/community/)
- [ACK ECS Controller](https://github.com/aws-controllers-k8s/ecs-controller)
- [ArgoCD Documentation](https://argo-cd.readthedocs.io/)
- [AWS EKS Guide](https://docs.aws.amazon.com/eks/)

## Support

문제가 발생한 경우:

1. [Troubleshooting Guide](docs/TROUBLESHOOTING.md) 확인
2. ACK 컨트롤러 로그 확인
3. GitHub Issues 확인

## License

MIT License