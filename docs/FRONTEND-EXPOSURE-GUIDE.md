# 🌐 Frontend Access Guide - CPTM8 Platform

## 🎯 Purpose

This guide shows you how to access your frontend applications (DashboardM8 and SocketM8) across different environments: **Development (Kind)**, **Staging**, and **Production**.

> **📋 Prerequisites**: Complete **DEPLOYMENT-GUIDE.md** first to have your platform deployed.

> **🏗️ Environment-Specific**: This guide covers different access methods for each environment. Make sure to use the right approach for your deployment target.

---

## 🛠️ Development Environment (Kind Kubernetes)

### **🚀 Option 1: NodePort Services** ⭐ Recommended for Kind

**Best for**: Local development and testing on Kind cluster

#### **How It Works**
Kind's `extraPortMappings` configured during cluster creation forward host ports to NodePorts inside the cluster:
- Host `localhost:3000` → NodePort `30080` → dashboardm8 pod port `3000`
- Host `localhost:4000` → NodePort `30081` → socketm8 pod port `4000`

#### **Deploy NodePort Services**
```bash
# Apply NodePort services (development only - Kind specific)
kubectl apply -f services/frontend-nodeport-dev.yaml

# Verify services are created
kubectl get svc -n cptm8-dev | grep nodeport
# Expected output:
# dashboardm8-nodeport   NodePort   10.x.x.x   <none>   3000:30080/TCP
# socketm8-nodeport      NodePort   10.x.x.x   <none>   4000:30081/TCP
```

#### **Access Your Applications**
```bash
# Dashboard - Next.js frontend
http://localhost:3000

# Socket.io - Real-time server
http://localhost:4000

# Test connectivity
curl -s http://localhost:3000 | head -5
curl -I http://localhost:4000
```

> **💡 Kind Configuration Reminder**: This only works because your Kind cluster was created with `extraPortMappings` in the cluster config (see DEPLOYMENT-GUIDE.md Step 1):
> ```yaml
> extraPortMappings:
> - containerPort: 30080
>   hostPort: 3000
> - containerPort: 30081
>   hostPort: 4000
> ```

> **⚠️ Development Only**: NodePort services are perfect for Kind local development but should NOT be used in staging/production. See staging/production sections below.

### **🌍 Option 2: Ingress with Custom Domains (Development)**

**Best for**: Learning production patterns, testing with real domain names on Kind

#### **Setup Custom Domains**
```bash
# Add entries to /etc/hosts for local domain resolution
echo "127.0.0.1 dashboard-dev.cptm8.net client.socket-dev.cptm8.net" | sudo tee -a /etc/hosts

# Deploy ingress
kubectl apply -f ingress/frontend-ingress-dev.yaml

# Verify ingress is ready
kubectl get ingress -n cptm8-dev frontend-ingress
```

#### **Access via Domains**
```bash
# Dashboard: http://dashboard-dev.cptm8.net
# Socket.IO: http://client.socket-dev.cptm8.net

# Test the domains
curl -I http://dashboard-dev.cptm8.net
curl -I http://client.socket-dev.cptm8.net
```

> **🎓 Learning Note**: Ingress routes requests based on hostname, just like production load balancers. The NGINX controller handles SSL termination and routing.

#### **Check Ingress Status**
```bash
# View ingress details
kubectl describe ingress -n cptm8-dev frontend-ingress

# Check ingress controller logs
kubectl logs -n ingress-nginx deployment/ingress-nginx-controller
```

### **🔧 Option 3: Port Forwarding (Development Debug)**

**Best for**: Debugging, bypassing network issues, direct pod access

#### **Forward Specific Services**
```bash
# Dashboard (runs in foreground)
kubectl port-forward -n cptm8-dev svc/dashboardm8-service 3000:3000

# Socket.IO (in another terminal)
kubectl port-forward -n cptm8-dev svc/socketm8-service 4000:4000

# Access via localhost:3000 and localhost:4000
```

#### **Forward with Background Process**
```bash
# Run in background
kubectl port-forward -n cptm8-dev svc/dashboardm8-service 3000:3000 &
kubectl port-forward -n cptm8-dev svc/socketm8-service 4000:4000 &

# Kill background processes when done
pkill -f "kubectl port-forward"
```

> **🎓 Learning Note**: Port forwarding creates a direct tunnel to a specific pod/service, bypassing all networking layers. Great for debugging.

---

## 🏢 Staging/Production Environments (Cloud Kubernetes)

> **⚠️ Important**: The development methods above (NodePort with Kind extraPortMappings, /etc/hosts) will NOT work in cloud environments. Use the methods below for staging and production.

### **🚀 Option 1: LoadBalancer Services** (Cloud-Native)

**Best for**: Simple cloud deployments on AWS, GCP, Azure

#### **Deploy LoadBalancer Services**
```bash
# For staging environment
kubectl apply -f services/frontend-external-services-staging.yaml

# For production environment
kubectl apply -f services/frontend-external-services-prod.yaml

# Wait for external IP assignment (may take 2-5 minutes)
kubectl get svc -n cptm8-[ENV] -w
```

#### **Get External IPs**
```bash
# Check assigned external IPs
kubectl get svc -n cptm8-staging | grep LoadBalancer
# Expected output:
# dashboardm8-external   LoadBalancer   10.x.x.x   a1b2c3d4.us-east-1.elb.amazonaws.com   3000:30080/TCP
# socketm8-external      LoadBalancer   10.x.x.x   e5f6g7h8.us-east-1.elb.amazonaws.com   4000:30081/TCP

# Access via external DNS names
curl -I http://<dashboard-loadbalancer-dns>:3000
curl -I http://<socket-loadbalancer-dns>:4000
```

> **💰 Cost Note**: LoadBalancer services create cloud load balancers (AWS ELB/ALB, GCP LB, Azure LB) which incur additional costs. Use Ingress for production to minimize costs.

### **🌐 Option 2: Ingress Controller** ⭐ Recommended for Production

**Best for**: Production deployments with custom domains, SSL/TLS, cost optimization

#### **Prerequisites**
```bash
# Install NGINX Ingress Controller (if not already installed)
# For AWS
kubectl apply -f https://raw.githubusercontent.com/kubernetes/ingress-nginx/controller-v1.8.1/deploy/static/provider/aws/deploy.yaml

# For GCP
kubectl apply -f https://raw.githubusercontent.com/kubernetes/ingress-nginx/controller-v1.8.1/deploy/static/provider/cloud/deploy.yaml

# Verify ingress controller is ready
kubectl get pods -n ingress-nginx
```

#### **Deploy Ingress Resources**
```bash
# For staging environment
kubectl apply -f ingress/frontend-ingress-staging.yaml

# For production environment
kubectl apply -f ingress/frontend-ingress-prod.yaml

# Get ingress external IP/hostname
kubectl get ingress -n cptm8-[ENV]
```

#### **Configure DNS**
```bash
# Get the ingress controller's external IP
INGRESS_IP=$(kubectl get svc -n ingress-nginx ingress-nginx-controller -o jsonpath='{.status.loadBalancer.ingress[0].ip}')

# Or get hostname (AWS ELB)
INGRESS_HOST=$(kubectl get svc -n ingress-nginx ingress-nginx-controller -o jsonpath='{.status.loadBalancer.ingress[0].hostname}')

# Create DNS A records in your domain registrar:
# dashboard.cptm8.net → $INGRESS_IP
# socket.cptm8.net → $INGRESS_IP
```

#### **Access via Custom Domains**
```bash
# Staging
https://dashboard-staging.cptm8.net
https://socket-staging.cptm8.net

# Production
https://dashboard.cptm8.net
https://socket.cptm8.net
```

### **🔐 SSL/TLS Configuration (Production)**

#### **Using cert-manager (Automated Let's Encrypt)**
```bash
# Install cert-manager
kubectl apply -f https://github.com/cert-manager/cert-manager/releases/download/v1.13.0/cert-manager.yaml

# Create Let's Encrypt issuer
cat <<EOF | kubectl apply -f -
apiVersion: cert-manager.io/v1
kind: ClusterIssuer
metadata:
  name: letsencrypt-prod
spec:
  acme:
    server: https://acme-v02.api.letsencrypt.org/directory
    email: your-email@example.com
    privateKeySecretRef:
      name: letsencrypt-prod
    solvers:
    - http01:
        ingress:
          class: nginx
EOF

# Update your Ingress to use TLS
# Add to ingress/frontend-ingress-prod.yaml:
# metadata:
#   annotations:
#     cert-manager.io/cluster-issuer: "letsencrypt-prod"
# spec:
#   tls:
#   - hosts:
#     - dashboard.cptm8.net
#     - socket.cptm8.net
#     secretName: cptm8-tls-cert
```

#### **Using AWS Certificate Manager (ACM)**
```bash
# Create certificate in ACM console for:
# - dashboard.cptm8.net
# - socket.cptm8.net

# Update LoadBalancer service annotations:
# metadata:
#   annotations:
#     service.beta.kubernetes.io/aws-load-balancer-ssl-cert: arn:aws:acm:region:account:certificate/xxx
#     service.beta.kubernetes.io/aws-load-balancer-backend-protocol: http
#     service.beta.kubernetes.io/aws-load-balancer-ssl-ports: "443"
```

### **🔧 Port Forwarding (Staging/Production Debug)**

**Best for**: Emergency debugging in cloud environments

```bash
# Port forward in staging/production (same as development)
kubectl port-forward -n cptm8-staging svc/dashboardm8-service 3000:3000
kubectl port-forward -n cptm8-prod svc/socketm8-service 4000:4000
```

> **⚠️ Security Warning**: Port forwarding requires kubectl access with proper RBAC permissions. Never expose port forwards to the public internet.

---

## 🔍 Troubleshooting Frontend Access

### **🛠️ Development (Kind) Issues**

#### **Can't Access localhost:3000 or localhost:4000**
```bash
# 1. Verify Kind cluster has extraPortMappings configured
kind get clusters
docker ps | grep kind

# 2. Check NodePort services exist
kubectl get svc -n cptm8-dev | grep nodeport
# Should show: dashboardm8-nodeport and socketm8-nodeport

# 3. Verify pods are running
kubectl get pods -n cptm8-dev -l tier=frontend

# 4. Test from inside cluster first
kubectl exec -n cptm8-dev deployment/dashboardm8 -- curl -f http://localhost:3000/signin
kubectl exec -n cptm8-dev deployment/socketm8 -- curl -f http://localhost:4000/ready

# 5. Test NodePort from Kind container
docker exec -it cptm8-dev-control-plane curl -I http://localhost:30080
docker exec -it cptm8-dev-control-plane curl -I http://localhost:30081

# 6. Test from host machine
curl -I http://localhost:3000
curl -I http://localhost:4000
```

#### **LoadBalancer Services Stuck in Pending (Development)**
```bash
# This is expected on Kind! LoadBalancer doesn't work without cloud provider
kubectl get svc -n cptm8-dev
# If you see LoadBalancer with <pending>, that's the issue

# Solution: Use NodePort services instead
kubectl delete -f services/frontend-external-services-dev.yaml  # Remove LoadBalancer
kubectl apply -f services/frontend-nodeport-dev.yaml  # Use NodePort
```

#### **Ingress Not Working (Development)**
```bash
# Check if ingress controller is running
kubectl get pods -n ingress-nginx

# Verify ingress has an address (should be localhost on Kind)
kubectl get ingress -n cptm8-dev

# Check /etc/hosts entries are correct
cat /etc/hosts | grep cptm8.net

# Test ingress controller directly
curl -I http://localhost/
```

### **🏢 Staging/Production (Cloud) Issues**

#### **LoadBalancer Services Stuck in Pending (Cloud)**
```bash
# 1. Check cloud provider integration
kubectl describe svc -n cptm8-[ENV] dashboardm8-external | grep -A10 Events

# 2. Verify cloud provider permissions (AWS example)
# - EKS cluster needs proper IAM role
# - VPC must have public subnets with internet gateway

# 3. Check service annotations (AWS example)
kubectl get svc -n cptm8-staging dashboardm8-external -o yaml | grep annotations -A5
```

#### **Ingress Not Getting External IP (Cloud)**
```bash
# 1. Check ingress controller service
kubectl get svc -n ingress-nginx ingress-nginx-controller

# 2. Verify cloud load balancer was created
# AWS: Check EC2 → Load Balancers in console
# GCP: gcloud compute forwarding-rules list
# Azure: az network lb list

# 3. Check ingress controller logs
kubectl logs -n ingress-nginx deployment/ingress-nginx-controller --tail=50
```

#### **DNS Not Resolving**
```bash
# 1. Verify DNS records are configured
nslookup dashboard.cptm8.net
dig dashboard.cptm8.net

# 2. Check ingress external IP matches DNS
kubectl get ingress -n cptm8-prod

# 3. Wait for DNS propagation (can take up to 48 hours)
# Use online DNS checker: https://dnschecker.org
```

### **🚨 Common Issues (All Environments)**

#### **Frontend Pods Not Starting**
```bash
# Check pod status
kubectl get pods -n cptm8-[ENV] -l tier=frontend

# View logs for issues
kubectl logs -f deployment/dashboardm8 -n cptm8-[ENV]
kubectl logs -f deployment/socketm8 -n cptm8-[ENV]

# Common issues:
# - Missing environment variables
# - Database connection failures
# - Image pull errors (ImagePullBackOff)

# If you see ImagePullBackOff, check ECR authentication
kubectl describe pod <pod-name> -n cptm8-[ENV] | grep -A5 "Failed to pull image"

# Manually refresh ECR token if needed
kubectl create job --from=cronjob/ecr-token-refresher ecr-token-manual-refresh -n cptm8-[ENV]
kubectl wait --for=condition=complete job/ecr-token-manual-refresh -n cptm8-[ENV] --timeout=60s
kubectl logs job/ecr-token-manual-refresh -n cptm8-[ENV]
```

#### **Services Have No Endpoints**
```bash
# Verify services have endpoints
kubectl get endpoints -n cptm8-[ENV] dashboardm8-service socketm8-service

# If empty, check pod labels match service selector
kubectl get pods -n cptm8-[ENV] -l app=dashboardm8 --show-labels
kubectl get svc -n cptm8-[ENV] dashboardm8-service -o yaml | grep selector -A3
```

#### **WebSocket Issues (SocketM8)**
```bash
# Ensure ingress has WebSocket annotations
kubectl describe ingress -n cptm8-[ENV] frontend-ingress | grep websocket

# Check CORS configuration in your application
kubectl exec -n cptm8-[ENV] deployment/socketm8 -- env | grep CORS

# Test WebSocket connection directly
kubectl port-forward -n cptm8-[ENV] deployment/socketm8 4000:4000
# Then test WebSocket from browser console
```

#### **SSL/TLS Certificate Issues**
```bash
# Check cert-manager certificates
kubectl get certificate -n cptm8-[ENV]
kubectl describe certificate -n cptm8-[ENV] cptm8-tls-cert

# View cert-manager logs
kubectl logs -n cert-manager deployment/cert-manager

# Manually trigger certificate renewal
kubectl delete secret -n cptm8-[ENV] cptm8-tls-cert
# cert-manager will automatically recreate it
```

---

## 🔐 Security Considerations

### **🛠️ Development (Kind)**
> **⚠️ Important**: Development configurations are for local use only. Never use in production:
> - NodePort with Kind extraPortMappings
> - /etc/hosts domain modifications
> - Unencrypted HTTP traffic

### **🏢 Staging/Production (Cloud)**

#### **Network Policies**
```bash
# Restrict frontend access to only ingress controller
cat <<EOF | kubectl apply -f -
apiVersion: networking.k8s.io/v1
kind: NetworkPolicy
metadata:
  name: frontend-netpol
  namespace: cptm8-prod
spec:
  podSelector:
    matchLabels:
      tier: frontend
  policyTypes:
  - Ingress
  ingress:
  - from:
    - namespaceSelector:
        matchLabels:
          name: ingress-nginx
    - podSelector:
        matchLabels:
          tier: application
EOF
```

#### **Security Headers (Ingress)**
```yaml
# Add to ingress annotations for production
metadata:
  annotations:
    nginx.ingress.kubernetes.io/force-ssl-redirect: "true"
    nginx.ingress.kubernetes.io/ssl-protocols: "TLSv1.2 TLSv1.3"
    nginx.ingress.kubernetes.io/enable-cors: "true"
    nginx.ingress.kubernetes.io/cors-allow-origin: "https://dashboard.cptm8.net"
```

#### **Web Application Firewall (AWS)**
```bash
# Associate AWS WAF with ALB
# metadata:
#   annotations:
#     service.beta.kubernetes.io/aws-load-balancer-waf-acl-id: "arn:aws:wafv2:..."
```

---

## 📊 Monitoring Your Frontend

### **Check Service Health**
```bash
# Dashboard health (replace [ENV] with dev/staging/prod)
kubectl exec -n cptm8-[ENV] deployment/dashboardm8 -- curl -f http://localhost:3000/signin

# Socket.IO health
kubectl exec -n cptm8-[ENV] deployment/socketm8 -- curl -f http://localhost:4000/ready

# Check resource usage
kubectl top pods -n cptm8-[ENV]
```

### **View Application Logs**
```bash
# Real-time logs
kubectl logs -f deployment/dashboardm8 -n cptm8-[ENV]
kubectl logs -f deployment/socketm8 -n cptm8-[ENV]

# Recent logs
kubectl logs --tail=50 deployment/dashboardm8 -n cptm8-[ENV]

# Logs from Vector (aggregated logs)
kubectl logs -f deployment/vector -n cptm8-[ENV]
```

### **Monitor with Prometheus/Grafana (Production)**
```bash
# Install kube-prometheus-stack (optional)
helm repo add prometheus-community https://prometheus-community.github.io/helm-charts
helm install prometheus prometheus-community/kube-prometheus-stack -n monitoring --create-namespace

# Access Grafana dashboard
kubectl port-forward -n monitoring svc/prometheus-grafana 3001:80
# Visit http://localhost:3001 (default: admin/prom-operator)
```

---

## 📋 Quick Reference

### **Development (Kind)**

| Access Method | URL | Configuration File | Use Case |
|---------------|-----|-------------------|----------|
| **NodePort** ⭐ | `localhost:3000`, `localhost:4000` | `services/frontend-nodeport-dev.yaml` | Quick development |
| **Ingress** | `dashboard-dev.cptm8.net`, `client.socket-dev.cptm8.net` | `ingress/frontend-ingress-dev.yaml` | Production-like testing |
| **Port Forward** | `localhost:3000`, `localhost:4000` | N/A (kubectl command) | Debugging, direct access |

### **Staging/Production (Cloud)**

| Access Method | URL | Configuration File | Use Case |
|---------------|-----|-------------------|----------|
| **LoadBalancer** | `<external-lb-dns>:3000`, `<external-lb-dns>:4000` | `services/frontend-external-services-[ENV].yaml` | Simple cloud deployment |
| **Ingress** ⭐ | `dashboard.cptm8.net`, `socket.cptm8.net` | `ingress/frontend-ingress-[ENV].yaml` | Production with SSL/TLS |
| **Port Forward** | `localhost:3000`, `localhost:4000` | N/A (kubectl command) | Emergency debugging |

### **Environment Variables**

Replace `[ENV]` in commands with:
- `dev` - Development (Kind cluster)
- `staging` - Staging (Cloud cluster)
- `prod` - Production (Cloud cluster)

---

## 🎯 What You've Learned

✅ **Environment-specific access patterns** for development vs staging/production
✅ **Kind-specific networking** with NodePort and extraPortMappings
✅ **Cloud-native patterns** using LoadBalancer and Ingress controllers
✅ **Production-ready SSL/TLS** with cert-manager and ACM
✅ **Debugging techniques** with port forwarding and health checks
✅ **Troubleshooting skills** for environment-specific issues
✅ **Security best practices** for network policies and ingress annotations

> **🎉 Success!** You now understand how to expose and access frontend applications in Kubernetes across all environments, from local development on Kind to production-ready cloud deployments with SSL/TLS and custom domains.