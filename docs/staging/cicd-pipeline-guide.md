# 🚀 CPTM8 CI/CD Pipeline Implementation Guide

## Overview

This guide implements a complete CI/CD pipeline for your CPTM8 platform, focusing on automated testing, security scanning, and progressive deployment to staging environment.

## GitHub Repository Structure

```
.github/
├── workflows/
│   ├── ci-microservices.yml
│   ├── ci-frontend.yml
│   ├── cd-staging.yml
│   ├── cd-production.yml
│   ├── security-scan.yml
│   └── rollback.yml
├── actions/
│   ├── build-push-ecr/
│   │   └── action.yml
│   ├── smoke-test/
│   │   └── action.yml
│   └── performance-test/
│       └── action.yml
└── dependabot.yml
```

## CI Pipeline - Microservices

```yaml
# .github/workflows/ci-microservices.yml
name: CI - Microservices

on:
  push:
    branches: [main, staging, develop]
    paths:
      - 'services/**'
      - 'go.mod'
      - 'go.sum'
  pull_request:
    branches: [main, staging]
    paths:
      - 'services/**'

env:
  GO_VERSION: '1.21'
  GOLANGCI_LINT_VERSION: 'v1.54'
  AWS_REGION: us-east-1
  ECR_REGISTRY: 123456789012.dkr.ecr.us-east-1.amazonaws.com

jobs:
  detect-changes:
    runs-on: ubuntu-latest
    outputs:
      services: ${{ steps.filter.outputs.changes }}
    steps:
      - uses: actions/checkout@v3
      - uses: dorny/paths-filter@v2
        id: filter
        with:
          filters: |
            asmm8:
              - 'services/asmm8/**'
            naabum8:
              - 'services/naabum8/**'
            katanam8:
              - 'services/katanam8/**'
            num8:
              - 'services/num8/**'
            orchestratorm8:
              - 'services/orchestratorm8/**'
            reportingm8:
              - 'services/reportingm8/**'

  test:
    needs: detect-changes
    runs-on: ubuntu-latest
    strategy:
      matrix:
        service: ${{ fromJson(needs.detect-changes.outputs.services) }}
    steps:
      - name: Checkout code
        uses: actions/checkout@v3
      
      - name: Setup Go
        uses: actions/setup-go@v4
        with:
          go-version: ${{ env.GO_VERSION }}
          cache: true
          cache-dependency-path: services/${{ matrix.service }}/go.sum
      
      - name: Run tests
        working-directory: services/${{ matrix.service }}
        run: |
          go test -v -race -coverprofile=coverage.out ./...
          go tool cover -html=coverage.out -o coverage.html
      
      - name: Upload coverage
        uses: actions/upload-artifact@v3
        with:
          name: coverage-${{ matrix.service }}
          path: services/${{ matrix.service }}/coverage.html
      
      - name: Check test coverage
        working-directory: services/${{ matrix.service }}
        run: |
          COVERAGE=$(go tool cover -func=coverage.out | grep total | awk '{print substr($3, 1, length($3)-1)}')
          echo "Coverage: ${COVERAGE}%"
          if (( $(echo "$COVERAGE < 70" | bc -l) )); then
            echo "::error::Test coverage is below 70% (${COVERAGE}%)"
            exit 1
          fi

  lint:
    needs: detect-changes
    runs-on: ubuntu-latest
    strategy:
      matrix:
        service: ${{ fromJson(needs.detect-changes.outputs.services) }}
    steps:
      - uses: actions/checkout@v3
      - uses: actions/setup-go@v4
        with:
          go-version: ${{ env.GO_VERSION }}
      
      - name: Run golangci-lint
        uses: golangci/golangci-lint-action@v3
        with:
          version: ${{ env.GOLANGCI_LINT_VERSION }}
          working-directory: services/${{ matrix.service }}
          args: --timeout=5m

  security-scan:
    needs: detect-changes
    runs-on: ubuntu-latest
    strategy:
      matrix:
        service: ${{ fromJson(needs.detect-changes.outputs.services) }}
    steps:
      - uses: actions/checkout@v3
      
      - name: Run Gosec Security Scanner
        uses: securego/gosec@master
        with:
          args: '-fmt sarif -out gosec-${{ matrix.service }}.sarif ./services/${{ matrix.service }}/...'
      
      - name: Upload SARIF file
        uses: github/codeql-action/upload-sarif@v2
        with:
          sarif_file: gosec-${{ matrix.service }}.sarif
      
      - name: Run Trivy vulnerability scanner
        uses: aquasecurity/trivy-action@master
        with:
          scan-type: 'fs'
          scan-ref: 'services/${{ matrix.service }}'
          format: 'sarif'
          output: 'trivy-${{ matrix.service }}.sarif'
      
      - name: Upload Trivy results
        uses: github/codeql-action/upload-sarif@v2
        with:
          sarif_file: trivy-${{ matrix.service }}.sarif

  build-and-push:
    needs: [test, lint, security-scan]
    runs-on: ubuntu-latest
    if: github.ref == 'refs/heads/staging' || github.ref == 'refs/heads/main'
    strategy:
      matrix:
        service: ${{ fromJson(needs.detect-changes.outputs.services) }}
    steps:
      - uses: actions/checkout@v3
      
      - name: Set up Docker Buildx
        uses: docker/setup-buildx-action@v2
      
      - name: Configure AWS credentials
        uses: aws-actions/configure-aws-credentials@v2
        with:
          aws-access-key-id: ${{ secrets.AWS_ACCESS_KEY_ID }}
          aws-secret-access-key: ${{ secrets.AWS_SECRET_ACCESS_KEY }}
          aws-region: ${{ env.AWS_REGION }}
      
      - name: Login to Amazon ECR
        id: login-ecr
        uses: aws-actions/amazon-ecr-get-login@v1
      
      - name: Build and push Docker image
        uses: docker/build-push-action@v4
        with:
          context: services/${{ matrix.service }}
          file: services/${{ matrix.service }}/Dockerfile
          platforms: linux/amd64,linux/arm64
          push: true
          tags: |
            ${{ env.ECR_REGISTRY }}/cptm8/${{ matrix.service }}:${{ github.sha }}
            ${{ env.ECR_REGISTRY }}/cptm8/${{ matrix.service }}:${{ github.ref == 'refs/heads/main' && 'latest' || 'staging-latest' }}
          cache-from: type=gha
          cache-to: type=gha,mode=max
          build-args: |
            VERSION=${{ github.sha }}
            BUILD_DATE=$(date -u +'%Y-%m-%dT%H:%M:%SZ')
      
      - name: Scan Docker image with Trivy
        uses: aquasecurity/trivy-action@master
        with:
          image-ref: ${{ env.ECR_REGISTRY }}/cptm8/${{ matrix.service }}:${{ github.sha }}
          format: 'sarif'
          output: 'docker-trivy-${{ matrix.service }}.sarif'
          severity: 'CRITICAL,HIGH'
      
      - name: Upload Docker scan results
        uses: github/codeql-action/upload-sarif@v2
        with:
          sarif_file: docker-trivy-${{ matrix.service }}.sarif
```

## CI Pipeline - Frontend

```yaml
# .github/workflows/ci-frontend.yml
name: CI - Frontend

on:
  push:
    branches: [main, staging, develop]
    paths:
      - 'frontend/**'
      - 'package.json'
      - 'package-lock.json'
  pull_request:
    branches: [main, staging]
    paths:
      - 'frontend/**'

env:
  NODE_VERSION: '20'
  AWS_REGION: us-east-1
  ECR_REGISTRY: 123456789012.dkr.ecr.us-east-1.amazonaws.com

jobs:
  test-and-build:
    runs-on: ubuntu-latest
    strategy:
      matrix:
        app: [dashboardm8, socketm8]
    steps:
      - uses: actions/checkout@v3
      
      - name: Setup Node.js
        uses: actions/setup-node@v3
        with:
          node-version: ${{ env.NODE_VERSION }}
          cache: 'npm'
          cache-dependency-path: frontend/${{ matrix.app }}/package-lock.json
      
      - name: Install dependencies
        working-directory: frontend/${{ matrix.app }}
        run: npm ci
      
      - name: Run linting
        working-directory: frontend/${{ matrix.app }}
        run: npm run lint
      
      - name: Run tests
        working-directory: frontend/${{ matrix.app }}
        run: npm run test:ci
        env:
          CI: true
      
      - name: Build application
        working-directory: frontend/${{ matrix.app }}
        run: npm run build
        env:
          NODE_ENV: production
      
      - name: Run security audit
        working-directory: frontend/${{ matrix.app }}
        run: |
          npm audit --audit-level=high
          npx snyk test --severity-threshold=high || true
      
      - name: Upload build artifacts
        uses: actions/upload-artifact@v3
        with:
          name: ${{ matrix.app }}-build
          path: frontend/${{ matrix.app }}/.next

  docker-build-push:
    needs: test-and-build
    runs-on: ubuntu-latest
    if: github.ref == 'refs/heads/staging' || github.ref == 'refs/heads/main'
    strategy:
      matrix:
        app: [dashboardm8, socketm8]
    steps:
      - uses: actions/checkout@v3
      
      - name: Download build artifacts
        uses: actions/download-artifact@v3
        with:
          name: ${{ matrix.app }}-build
          path: frontend/${{ matrix.app }}/.next
      
      - name: Configure AWS credentials
        uses: aws-actions/configure-aws-credentials@v2
        with:
          aws-access-key-id: ${{ secrets.AWS_ACCESS_KEY_ID }}
          aws-secret-access-key: ${{ secrets.AWS_SECRET_ACCESS_KEY }}
          aws-region: ${{ env.AWS_REGION }}
      
      - name: Login to Amazon ECR
        uses: aws-actions/amazon-ecr-get-login@v1
      
      - name: Build and push Docker image
        uses: docker/build-push-action@v4
        with:
          context: frontend/${{ matrix.app }}
          push: true
          tags: |
            ${{ env.ECR_REGISTRY }}/cptm8/${{ matrix.app }}:${{ github.sha }}
            ${{ env.ECR_REGISTRY }}/cptm8/${{ matrix.app }}:${{ github.ref == 'refs/heads/main' && 'latest' || 'staging-latest' }}
```

## CD Pipeline - Staging

```yaml
# .github/workflows/cd-staging.yml
name: CD - Deploy to Staging

on:
  workflow_run:
    workflows: ["CI - Microservices", "CI - Frontend"]
    types: [completed]
    branches: [staging]
  workflow_dispatch:
    inputs:
      service:
        description: 'Service to deploy (leave empty for all)'
        required: false
        type: choice
        options:
          - ''
          - 'asmm8'
          - 'naabum8'
          - 'katanam8'
          - 'num8'
          - 'orchestratorm8'
          - 'reportingm8'
          - 'dashboardm8'
          - 'socketm8'

env:
  AWS_REGION: us-east-1
  EKS_CLUSTER: cptm8-staging
  NAMESPACE: cptm8-staging
  SLACK_WEBHOOK: ${{ secrets.SLACK_WEBHOOK_URL }}

jobs:
  deploy:
    runs-on: ubuntu-latest
    if: ${{ github.event.workflow_run.conclusion == 'success' || github.event_name == 'workflow_dispatch' }}
    steps:
      - name: Checkout code
        uses: actions/checkout@v3
      
      - name: Configure AWS credentials
        uses: aws-actions/configure-aws-credentials@v2
        with:
          aws-access-key-id: ${{ secrets.AWS_ACCESS_KEY_ID }}
          aws-secret-access-key: ${{ secrets.AWS_SECRET_ACCESS_KEY }}
          aws-region: ${{ env.AWS_REGION }}
      
      - name: Update kubeconfig
        run: |
          aws eks update-kubeconfig --region ${{ env.AWS_REGION }} --name ${{ env.EKS_CLUSTER }}
      
      - name: Install Helm
        run: |
          curl https://raw.githubusercontent.com/helm/helm/main/scripts/get-helm-3 | bash
      
      - name: Deploy with Helm
        run: |
          # Update Helm repository
          helm repo add cptm8 s3://cptm8-helm-charts/stable
          helm repo update
          
          # Deploy or upgrade
          helm upgrade --install cptm8-staging cptm8/cptm8 \
            --namespace ${{ env.NAMESPACE }} \
            --create-namespace \
            --values helm/cptm8/values.yaml \
            --values helm/cptm8/values-staging.yaml \
            --set global.imageTag=${{ github.sha }} \
            --wait \
            --timeout 10m
      
      - name: Run database migrations
        run: |
          kubectl exec -n ${{ env.NAMESPACE }} deployment/orchestratorm8 -- /app/migrate up
      
      - name: Verify deployment
        run: |
          # Wait for all deployments to be ready
          kubectl wait --for=condition=available --timeout=600s \
            deployment --all -n ${{ env.NAMESPACE }}
          
          # Check pod status
          kubectl get pods -n ${{ env.NAMESPACE }}
          
          # Run health checks
          ./scripts/health-check-staging.sh

  smoke-tests:
    needs: deploy
    runs-on: ubuntu-latest
    steps:
      - uses: actions/checkout@v3
      
      - name: Configure kubectl
        run: |
          aws eks update-kubeconfig --region ${{ env.AWS_REGION }} --name ${{ env.EKS_CLUSTER }}
      
      - name: Run smoke tests
        run: |
          # Test backend services
          SERVICES="asmm8 naabum8 katanam8 num8"
          for service in $SERVICES; do
            echo "Testing $service health endpoint..."
            kubectl exec -n ${{ env.NAMESPACE }} deployment/$service -- \
              curl -f http://localhost:8000/health || exit 1
            
            echo "Testing $service readiness endpoint..."
            kubectl exec -n ${{ env.NAMESPACE }} deployment/$service -- \
              curl -f http://localhost:8000/ready || exit 1
          done
          
          # Test frontend
          kubectl exec -n ${{ env.NAMESPACE }} deployment/dashboardm8 -- \
            curl -f http://localhost:3000/signin || exit 1
          
          kubectl exec -n ${{ env.NAMESPACE }} deployment/socketm8 -- \
            curl -f http://localhost:4000/ready || exit 1
      
      - name: Run integration tests
        run: |
          npm install -g newman
          newman run tests/postman/cptm8-staging-collection.json \
            --environment tests/postman/staging-environment.json \
            --reporters cli,json \
            --reporter-json-export test-results.json

  performance-tests:
    needs: smoke-tests
    runs-on: ubuntu-latest
    steps:
      - uses: actions/checkout@v3
      
      - name: Run K6 performance tests
        uses: grafana/k6-action@v0.3.0
        with:
          filename: tests/k6/staging-load-test.js
          flags: --out influxdb=http://monitoring.cptm8.net/influxdb
      
      - name: Analyze performance results
        run: |
          # Check if performance meets SLA
          python scripts/analyze-performance.py test-results.json
          
          # Upload results to S3
          aws s3 cp test-results.json \
            s3://cptm8-test-results/staging/${{ github.sha }}/

  security-validation:
    needs: deploy
    runs-on: ubuntu-latest
    steps:
      - name: Run OWASP ZAP scan
        uses: zaproxy/action-full-scan@v0.7.0
        with:
          target: 'https://dashboard-staging.cptm8.net'
          rules_file_name: '.zap/rules.tsv'
          cmd_options: '-a'
      
      - name: Run Kubescape security scan
        run: |
          curl -s https://raw.githubusercontent.com/kubescape/kubescape/master/install.sh | /bin/bash
          kubescape scan framework nsa \
            --namespace ${{ env.NAMESPACE }} \
            --format json \
            --output kubescape-results.json
          
          # Check for critical issues
          CRITICAL=$(jq '.summary.critical' kubescape-results.json)
          if [ "$CRITICAL" -gt 0 ]; then
            echo "::error::Found $CRITICAL critical security issues"
            exit 1
          fi

  notify:
    needs: [deploy, smoke-tests, performance-tests, security-validation]
    runs-on: ubuntu-latest
    if: always()
    steps:
      - name: Send Slack notification
        uses: 8398a7/action-slack@v3
        with:
          status: ${{ job.status }}
          text: |
            Deployment to Staging: ${{ job.status }}
            Commit: ${{ github.sha }}
            Author: ${{ github.actor }}
            Branch: ${{ github.ref }}
          webhook_url: ${{ env.SLACK_WEBHOOK }}
```

## Rollback Workflow

```yaml
# .github/workflows/rollback.yml
name: Rollback Deployment

on:
  workflow_dispatch:
    inputs:
      environment:
        description: 'Environment to rollback'
        required: true
        type: choice
        options:
          - staging
          - production
      revision:
        description: 'Helm revision number to rollback to'
        required: true
        type: number

jobs:
  rollback:
    runs-on: ubuntu-latest
    steps:
      - name: Configure AWS credentials
        uses: aws-actions/configure-aws-credentials@v2
        with:
          aws-access-key-id: ${{ secrets.AWS_ACCESS_KEY_ID }}
          aws-secret-access-key: ${{ secrets.AWS_SECRET_ACCESS_KEY }}
          aws-region: us-east-1
      
      - name: Update kubeconfig
        run: |
          CLUSTER_NAME=cptm8-${{ github.event.inputs.environment }}
          aws eks update-kubeconfig --region us-east-1 --name $CLUSTER_NAME
      
      - name: Rollback Helm release
        run: |
          NAMESPACE=cptm8-${{ github.event.inputs.environment }}
          
          # Show current revision
          echo "Current revision:"
          helm list -n $NAMESPACE
          
          # Rollback to specified revision
          helm rollback cptm8-${{ github.event.inputs.environment }} \
            ${{ github.event.inputs.revision }} \
            -n $NAMESPACE \
            --wait
          
          # Verify rollback
          echo "After rollback:"
          helm list -n $NAMESPACE
          kubectl get pods -n $NAMESPACE
```

## Custom GitHub Actions

### Build and Push to ECR

```yaml
# .github/actions/build-push-ecr/action.yml
name: 'Build and Push to ECR'
description: 'Build Docker image and push to Amazon ECR'

inputs:
  service-name:
    description: 'Name of the service'
    required: true
  dockerfile-path:
    description: 'Path to Dockerfile'
    required: true
  context-path:
    description: 'Build context path'
    required: true
  ecr-registry:
    description: 'ECR registry URL'
    required: true
  image-tags:
    description: 'Comma-separated list of tags'
    required: true

runs:
  using: 'composite'
  steps:
    - name: Set up Docker Buildx
      uses: docker/setup-buildx-action@v2
    
    - name: Build and push
      uses: docker/build-push-action@v4
      with:
        context: ${{ inputs.context-path }}
        file: ${{ inputs.dockerfile-path }}
        push: true
        tags: |
          ${{ inputs.ecr-registry }}/cptm8/${{ inputs.service-name }}:${{ github.sha }}
          ${{ inputs.ecr-registry }}/cptm8/${{ inputs.service-name }}:${{ inputs.image-tags }}
        cache-from: type=gha,scope=${{ inputs.service-name }}
        cache-to: type=gha,mode=max,scope=${{ inputs.service-name }}
```

## Supporting Scripts

### Health Check Script

```bash
#!/bin/bash
# scripts/health-check-staging.sh

set -e

NAMESPACE="cptm8-staging"
SERVICES=("asmm8" "naabum8" "katanam8" "num8" "orchestratorm8" "dashboardm8" "socketm8")
FAILED=0

echo "Running health checks for staging environment..."

for service in "${SERVICES[@]}"; do
    echo -n "Checking $service... "
    
    # Get pod name
    POD=$(kubectl get pod -n $NAMESPACE -l app=$service -o jsonpath='{.items[0].metadata.name}')
    
    if [ -z "$POD" ]; then
        echo "FAILED: No pod found"
        FAILED=$((FAILED + 1))
        continue
    fi
    
    # Check health endpoint
    if [ "$service" == "dashboardm8" ]; then
        HEALTH_URL="http://localhost:3000/signin"
    elif [ "$service" == "socketm8" ]; then
        HEALTH_URL="http://localhost:4000/ready"
    else
        HEALTH_URL="http://localhost:8000/health"
    fi
    
    if kubectl exec -n $NAMESPACE $POD -- curl -f -s $HEALTH_URL > /dev/null 2>&1; then
        echo "OK"
    else
        echo "FAILED"
        FAILED=$((FAILED + 1))
    fi
done

echo ""
if [ $FAILED -eq 0 ]; then
    echo "✅ All health checks passed!"
    exit 0
else
    echo "❌ $FAILED health checks failed!"
    exit 1
fi
```

### Performance Analysis Script

```python
#!/usr/bin/env python3
# scripts/analyze-performance.py

import json
import sys
from typing import Dict, Any

# Performance SLA thresholds
SLA_THRESHOLDS = {
    "p95_response_time_ms": 500,
    "p99_response_time_ms": 1000,
    "error_rate_percent": 1.0,
    "requests_per_second": 100
}

def analyze_results(results_file: str) -> bool:
    """Analyze K6 performance test results against SLA."""
    
    with open(results_file, 'r') as f:
        results = json.load(f)
    
    metrics = results.get('metrics', {})
    violations = []
    
    # Check response times
    p95 = metrics.get('http_req_duration', {}).get('p(95)', 0)
    if p95 > SLA_THRESHOLDS['p95_response_time_ms']:
        violations.append(f"P95 response time ({p95}ms) exceeds SLA ({SLA_THRESHOLDS['p95_response_time_ms']}ms)")
    
    p99 = metrics.get('http_req_duration', {}).get('p(99)', 0)
    if p99 > SLA_THRESHOLDS['p99_response_time_ms']:
        violations.append(f"P99 response time ({p99}ms) exceeds SLA ({SLA_THRESHOLDS['p99_response_time_ms']}ms)")
    
    # Check error rate
    failed = metrics.get('http_req_failed', {}).get('rate', 0) * 100
    if failed > SLA_THRESHOLDS['error_rate_percent']:
        violations.append(f"Error rate ({failed:.2f}%) exceeds SLA ({SLA_THRESHOLDS['error_rate_percent']}%)")
    
    # Check throughput
    rps = metrics.get('http_reqs', {}).get('rate', 0)
    if rps < SLA_THRESHOLDS['requests_per_second']:
        violations.append(f"Throughput ({rps:.2f} RPS) below SLA ({SLA_THRESHOLDS['requests_per_second']} RPS)")
    
    if violations:
        print("❌ Performance SLA Violations:")
        for violation in violations:
            print(f"  - {violation}")
        return False
    else:
        print("✅ All performance metrics within SLA")
        return True

if __name__ == "__main__":
    if len(sys.argv) != 2:
        print("Usage: analyze-performance.py <results.json>")
        sys.exit(1)
    
    success = analyze_results(sys.argv[1])
    sys.exit(0 if success else 1)
```

## Dependabot Configuration

```yaml
# .github/dependabot.yml
version: 2
updates:
  # Go dependencies
  - package-ecosystem: "gomod"
    directory: "/services/asmm8"
    schedule:
      interval: "weekly"
    labels:
      - "dependencies"
      - "go"
    assignees:
      - "deifzar"
  
  # Repeat for other services...
  
  # Frontend dependencies
  - package-ecosystem: "npm"
    directory: "/frontend/dashboardm8"
    schedule:
      interval: "weekly"
    labels:
      - "dependencies"
      - "javascript"
  
  # Docker base images
  - package-ecosystem: "docker"
    directory: "/services/asmm8"
    schedule:
      interval: "weekly"
    labels:
      - "dependencies"
      - "docker"
  
  # GitHub Actions
  - package-ecosystem: "github-actions"
    directory: "/"
    schedule:
      interval: "weekly"
    labels:
      - "dependencies"
      - "github-actions"
```

## K6 Performance Test

```javascript
// tests/k6/staging-load-test.js
import http from 'k6/http';
import { check, sleep } from 'k6';
import { Rate } from 'k6/metrics';

const errorRate = new Rate('errors');

export const options = {
  stages: [
    { duration: '2m', target: 10 },  // Ramp up to 10 users
    { duration: '5m', target: 10 },  // Stay at 10 users
    { duration: '2m', target: 50 },  // Ramp up to 50 users
    { duration: '5m', target: 50 },  // Stay at 50 users
    { duration: '2m', target: 100 }, // Ramp up to 100 users
    { duration: '5m', target: 100 }, // Stay at 100 users
    { duration: '2m', target: 0 },   // Ramp down to 0 users
  ],
  thresholds: {
    http_req_duration: ['p(95)<500', 'p(99)<1000'],
    errors: ['rate<0.01'],
    http_req_failed: ['rate<0.01'],
  },
};

const BASE_URL = 'https://api-staging.cptm8.net';

export default function () {
  // Test health endpoints
  const services = ['asmm8', 'naabum8', 'katanam8', 'num8'];
  
  for (const service of services) {
    const healthRes = http.get(`${BASE_URL}/${service}/health`);
    check(healthRes, {
      'health check status is 200': (r) => r.status === 200,
      'health check response time < 200ms': (r) => r.timings.duration < 200,
    });
    errorRate.add(healthRes.status !== 200);
  }
  
  // Test dashboard
  const dashboardRes = http.get('https://dashboard-staging.cptm8.net');
  check(dashboardRes, {
    'dashboard status is 200': (r) => r.status === 200,
    'dashboard response time < 500ms': (r) => r.timings.duration < 500,
  });
  
  sleep(1);
}
```

## Benefits of This CI/CD Pipeline

1. **Automated Testing**: Every commit triggers comprehensive testing
2. **Security Scanning**: Multiple layers of security validation
3. **Performance Validation**: Automated performance testing against SLAs
4. **Progressive Deployment**: Safe rollout with health checks
5. **Easy Rollback**: One-click rollback to previous versions
6. **Cost Optimization**: Build caching and parallel execution
7. **Observability**: Full deployment metrics and notifications

---

This CI/CD pipeline provides enterprise-grade automation for your CPTM8 platform, ensuring quality, security, and reliability in your staging deployments.
