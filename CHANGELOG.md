# Changelog

AWS ACK ECS Controller with ArgoCD 프로젝트의 모든 주요 변경사항을 기록합니다.

Format: [Keep a Changelog](https://keepachangelog.com/)
Version: [Semantic Versioning](https://semver.org/)

## [Unreleased]

### Added
- Initial project structure
- ArgoCD Application configuration
- RBAC and IAM role setup
- Deployment and cleanup automation scripts
- Comprehensive documentation
- Example manifests for ECS resources

### Changed
- N/A

### Deprecated
- N/A

### Removed
- N/A

### Fixed
- N/A

### Security
- N/A

## [1.0.0] - 2024-01-14

### Added
- Complete AWS ACK ECS Controller deployment setup
- ArgoCD integration for GitOps workflow
- Automated deployment script with prerequisites check
- IRSA (IAM Roles for Service Accounts) support
- Comprehensive documentation and guides
- Troubleshooting guide
- ECS resource examples (Cluster, Task Definition, Service)
- Bootstrap RBAC configuration
- Helm values customization support
- Cleanup automation script

### Documentation
- README with quick start guide
- Deployment guide with step-by-step instructions
- Troubleshooting guide with common issues and solutions
- Contributing guidelines
- MIT License

### Infrastructure
- CI/CD ready structure
- Git-friendly configuration
- .gitignore for common temporary files
- Examples directory for reference implementations

## Future Plans

### Planned for v1.1.0
- [ ] Helm chart repository setup
- [ ] GitHub Actions for CI/CD
- [ ] Additional ECS resource examples
- [ ] Prometheus monitoring setup
- [ ] Grafana dashboard examples

### Planned for v1.2.0
- [ ] Terraform module for setup automation
- [ ] Multi-region deployment examples
- [ ] Security hardening guidelines
- [ ] Performance tuning guide

### Planned for v2.0.0
- [ ] Kubernetes Operator for simplified management
- [ ] Advanced networking examples
- [ ] Service mesh integration (Istio)
- [ ] Cost optimization guide

## Contributing

변경 사항을 제출하려면 [CONTRIBUTING.md](CONTRIBUTING.md)를 참고하세요.

## Version History

| Version | Date | Release Notes |
|---------|------|---------------|
| 1.0.0 | 2024-01-14 | Initial release |

## Support

문제가 발생하거나 질문이 있으면:
- GitHub Issues에 보고해주세요
- Discussions를 통해 질문해주세요
- 기여 가이드라인을 참고해주세요

## Acknowledgments

- AWS Controllers for Kubernetes(ACK) 프로젝트
- ArgoCD 프로젝트
- Kubernetes 커뮤니티
