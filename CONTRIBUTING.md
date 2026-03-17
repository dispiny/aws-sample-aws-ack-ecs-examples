# Contributing

AWS ACK ECS Controller with ArgoCD 프로젝트에 기여하는 방법을 설명합니다.

## Getting Started

### Prerequisites

- Git
- Kubernetes cluster access
- Docker (for building)
- AWS CLI

### Development Setup

1. Repository를 fork하고 clone합니다:

```bash
git clone https://github.com/your-username/aws-sample-aws-ack-ecs-examples.git
cd aws-sample-aws-ack-ecs-examples
```

2. Feature branch를 생성합니다:

```bash
git checkout -b feature/your-feature-name
```

3. 변경사항을 작업합니다.

## Making Changes

### Code Style

- YAML 파일은 올바른 들여쓰기를 유지합니다 (2 spaces)
- 모든 파일에는 적절한 주석을 포함합니다
- 변수명은 명확하고 명시적입니다

### Documentation

- 새로운 기능이나 변경사항은 문서를 함께 제출합니다
- README, DEPLOYMENT_GUIDE, TROUBLESHOOTING 등을 업데이트합니다
- 코드에 주석을 추가하여 복잡한 로직을 설명합니다

### Testing

배포 전에:

1. Lint 확인:

```bash
# YAML syntax 확인
yamllint *.yaml aws-ack-controller/ bootstrap/ argocd/
```

2. Kubernetes validation:

```bash
kubectl apply --dry-run=client -f application.yaml
kubectl apply --dry-run=client -f bootstrap/
```

3. 스크립트 테스트:

```bash
# Syntax 확인
bash -n scripts/deploy.sh
bash -n scripts/cleanup.sh
```

## Submitting Changes

### Commit Message

명확한 commit message를 작성합니다:

```
type: brief description (50 chars or less)

Detailed explanation of the change (if needed)
- Point 1
- Point 2
```

Type guidelines:
- `feat`: 새로운 기능
- `fix`: 버그 수정
- `docs`: 문서 변경
- `style`: 형식 변경 (기능 영향 없음)
- `refactor`: 코드 리팩토링
- `test`: 테스트 추가

### Pull Request

1. Push your branch:

```bash
git push origin feature/your-feature-name
```

2. GitHub에서 Pull Request를 생성합니다
3. PR 설명에 다음을 포함합니다:
   - 변경사항 요약
   - 관련 Issue 번호
   - 테스트 방법
   - 스크린샷 (해당하는 경우)

## Review Process

모든 PR은 최소 1명의 maintainer에게 review를 받아야 합니다.

Reviewers는:
- 코드 품질 확인
- 문서 정확성 확인
- 보안 검토
- 테스트 결과 확인

## Issue Report

버그나 개선 사항을 발견한 경우:

1. GitHub Issues에서 확인 (중복 방지)
2. 새로운 Issue를 생성합니다
3. 다음을 포함합니다:
   - 명확한 제목
   - 상세한 설명
   - 재현 단계 (버그의 경우)
   - 예상 동작 vs 실제 동작
   - 환경 정보 (OS, Kubernetes version, etc.)

### Issue Labels

- `bug`: 버그 리포트
- `enhancement`: 개선 사항
- `documentation`: 문서 관련
- `question`: 질문
- `help wanted`: 도움이 필요한 경우
- `good first issue`: 신규 기여자에게 좋은 이슈

## Release Process

1. Maintainer가 release를 준비합니다
2. CHANGELOG를 업데이트합니다
3. Version tag를 생성합니다
4. Release notes를 작성합니다

## Questions?

문의 사항이 있으면:
- GitHub Discussions 사용
- Issue에 질문 라벨 추가
- Email로 maintainer에게 연락

## Code of Conduct

이 프로젝트는 친절하고 포용적인 커뮤니티를 지향합니다.

모든 참여자는 다음을 준수해야 합니다:
- 존중하는 언어와 태도 유지
- 건설적인 피드백 제공
- 다양성과 포용성 존중
- 하라스먼트 및 차별 금지

## License

이 프로젝트의 기여는 MIT License 하에 제공되는 것으로 간주됩니다.

감사합니다!
