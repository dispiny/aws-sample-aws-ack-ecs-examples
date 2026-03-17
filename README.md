# aws-sample-aws-ack-ecs-examples

AWS ACK(AWS Controllers for Kubernetes) ECS 예제를 위한 Kubernetes manifest 파일 저장소입니다.

## 디렉토리 구조

```
manifests/
├── namespaces/          # 네임스페이스 정의
│   └── ack-system.yaml
├── clusters/            # ECS 클러스터 리소스
│   └── sample-cluster.yaml
├── task-definitions/    # ECS 태스크 정의 리소스
│   └── sample-task-definition.yaml
└── services/            # ECS 서비스 리소스
    └── sample-service.yaml
```

## 사전 요구 사항

- Kubernetes 클러스터 (예: EKS)
- [AWS ACK ECS 컨트롤러](https://github.com/aws-controllers-k8s/ecs-controller) 설치
- 적절한 AWS IAM 권한

## 사용 방법

### 1. 네임스페이스 생성

```bash
kubectl apply -f manifests/namespaces/ack-system.yaml
```

### 2. ECS 클러스터 생성

```bash
kubectl apply -f manifests/clusters/sample-cluster.yaml
```

### 3. 태스크 정의 생성

```bash
kubectl apply -f manifests/task-definitions/sample-task-definition.yaml
```

### 4. ECS 서비스 생성

`manifests/services/sample-service.yaml` 파일에서 subnet ID와 security group ID를 실제 값으로 변경한 후 적용합니다.

```bash
kubectl apply -f manifests/services/sample-service.yaml
```

### 전체 적용

```bash
kubectl apply -f manifests/namespaces/
kubectl apply -f manifests/clusters/
kubectl apply -f manifests/task-definitions/
kubectl apply -f manifests/services/
```

## 리소스 확인

```bash
kubectl get clusters.ecs.services.k8s.aws -n ack-system
kubectl get taskdefinitions.ecs.services.k8s.aws -n ack-system
kubectl get services.ecs.services.k8s.aws -n ack-system
```