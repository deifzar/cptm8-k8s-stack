# 🌐 Frontend Access Guide - CPTM8 Platform

## 🎯 Purpose

This guide shows you how to access your frontend applications (DashboardM8 and SocketM8) across the **Development (Kind)** environment.

> **📋 Prerequisites**: Complete **local-deployment-guide.md** first to have your platform deployed.

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

### **🌍 Option 2: Ingress with Custom Domains **

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

### **🔧 Option 3: Port Forwarding **

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

#### **LoadBalancer Services Stuck in Pending **
```bash
# This is expected on Kind! LoadBalancer doesn't work without cloud provider
kubectl get svc -n cptm8-dev
# If you see LoadBalancer with <pending>, that's the issue

# Solution: Use NodePort services instead
kubectl delete -f services/frontend-external-services-dev.yaml  # Remove LoadBalancer
kubectl apply -f services/frontend-nodeport-dev.yaml  # Use NodePort
```

#### **Ingress Not Working **
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

### **Environment Variables**

Replace `[ENV]` in commands with:
- `dev` - Development (Kind cluster)
- `staging` - Staging (Cloud cluster)
- `prod` - Production (Cloud cluster)

---

## 🎯 What You've Learned

✅ **Kind-specific networking** with NodePort and extraPortMappings
✅ **Debugging techniques** with port forwarding and health checks
✅ **Troubleshooting skills** for environment-specific issues
✅ **Security best practices** for network policies and ingress annotations