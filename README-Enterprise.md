# Enterprise AKS + Quarkus + Camel K Setup Guide

## Overview

This guide provides a comprehensive, enterprise-grade setup for deploying Azure Kubernetes Service (AKS) with Quarkus and Apache Camel K integration. This setup includes security best practices, monitoring, compliance, and production-ready configurations.

## Table of Contents

1. [Architecture Overview](#architecture-overview)
2. [Enterprise Features](#enterprise-features)
3. [Prerequisites](#prerequisites)
4. [Quick Start Guide](#quick-start-guide)
5. [Detailed Setup Instructions](#detailed-setup-instructions)
6. [Security Configuration](#security-configuration)
7. [Monitoring and Observability](#monitoring-and-observability)
8. [Backup and Disaster Recovery](#backup-and-disaster-recovery)
9. [Compliance and Governance](#compliance-and-governance)
10. [Operations and Maintenance](#operations-and-maintenance)
11. [Troubleshooting](#troubleshooting)
12. [Cost Optimization](#cost-optimization)

## Architecture Overview

```
┌─────────────────────────────────────────────────────────────┐
│                     Azure Cloud                              │
│                                                               │
│  ┌─────────────────────────────────────────────────────────┐ │
│  │                AKS Cluster                              │ │
│  │                                                         │ │
│  │  ┌─────────────┐  ┌─────────────┐  ┌─────────────┐     │ │
│  │  │   System    │  │   Camel K   │  │ Application │     │ │
│  │  │  Namespace  │  │ Namespace   │  │ Namespaces  │     │ │
│  │  │             │  │             │  │             │     │ │
│  │  │ • Monitoring│  │ • Operator  │  │ • Quarkus   │     │ │
│  │  │ • Logging   │  │ • Platform  │  │   Apps      │     │ │
│  │  │ • Security  │  │ • Runtime   │  │ • Services  │     │ │
│  │  │ • Tracing   │  │ • Metrics   │  │ • APIs      │     │ │
│  │  └─────────────┘  └─────────────┘  └─────────────┘     │ │
│  │                                                         │ │
│  │  Network Policies • RBAC • Pod Security Standards      │ │
│  └─────────────────────────────────────────────────────────┘ │
│                                                               │
│  ┌─────────────────────────────────────────────────────────┐ │
│  │              Supporting Services                        │ │
│  │  • Azure Container Registry (ACR)                      │ │
│  │  • Azure Key Vault (Secrets Management)                │ │
│  │  • Azure Monitor / Log Analytics                       │ │
│  │  • Azure Active Directory (Identity)                   │ │
│  │  • Azure Storage (Backup)                              │ │
│  └─────────────────────────────────────────────────────────┘ │
└─────────────────────────────────────────────────────────────┘
```

## Enterprise Features

### 🔒 Security
- ✅ Azure Active Directory integration
- ✅ Role-Based Access Control (RBAC)
- ✅ Network security policies
- ✅ Pod Security Standards
- ✅ Container image scanning
- ✅ Secret management with Azure Key Vault
- ✅ Runtime security monitoring (Falco)
- ✅ TLS/SSL encryption
- ✅ Security policy enforcement

### 📊 Monitoring & Observability
- ✅ Prometheus metrics collection
- ✅ Grafana dashboards and visualization
- ✅ Centralized logging with Fluentd/Elasticsearch
- ✅ Distributed tracing with Jaeger
- ✅ Application Performance Monitoring (APM)
- ✅ Health checks and probes
- ✅ Alerting and notifications
- ✅ Custom Camel K dashboards

### 🚀 High Availability & Resilience
- ✅ Multi-zone deployment
- ✅ Auto-scaling (HPA & VPA)
- ✅ Circuit breakers and retry policies
- ✅ Backup strategies with Velero
- ✅ Disaster recovery procedures
- ✅ Load balancing and traffic management

### 📋 Compliance & Governance
- ✅ Policy enforcement with OPA Gatekeeper
- ✅ Resource tagging and organization
- ✅ Audit logging and compliance reporting
- ✅ Cost management and optimization
- ✅ Documentation and runbooks

## Prerequisites

### System Requirements
- **Operating System**: Windows 10/11 or Windows Server 2019+
- **PowerShell**: Version 5.1 or PowerShell Core 7+
- **Memory**: 8 GB RAM minimum (16 GB recommended)
- **Storage**: 50 GB available disk space
- **Network**: Stable internet connection (minimum 10 Mbps)

### Required Software
- Azure CLI 2.50+
- kubectl 1.28+
- Helm 3.12+
- Docker Desktop (optional, for local development)
- Git for Windows
- Visual Studio Code (recommended)

### Azure Requirements
- Azure subscription with sufficient quotas
- Permissions to create:
  - Resource groups
  - AKS clusters
  - Azure Container Registry
  - Azure Key Vault
  - Log Analytics workspaces
  - Storage accounts

### Installation Commands
```powershell
# Install Azure CLI
winget install Microsoft.AzureCLI

# Install kubectl
az aks install-cli

# Install Helm
choco install kubernetes-helm

# Install Git
winget install Git.Git

# Install Visual Studio Code
winget install Microsoft.VisualStudioCode
```

## Quick Start Guide

### 1. Download and Setup
```powershell
# Navigate to your workspace
cd C:\
mkdir enterprise-aks-setup
cd enterprise-aks-setup

# Download the scripts (copy the provided scripts to this directory)
```

### 2. Login to Azure
```powershell
# Login to Azure
az login

# Set your subscription (if you have multiple)
az account set --subscription "your-subscription-id"

# Verify login
az account show
```

### 3. Configure Parameters
Create a configuration file `config\enterprise-config.json`:

```json
{
  "azure": {
    "subscription": "your-subscription-id",
    "location": "East US 2",
    "environment": "production"
  },
  "cluster": {
    "resourceGroupName": "rg-aks-prod-001",
    "clusterName": "aks-prod-cluster-001",
    "nodeCount": 3,
    "nodeSize": "Standard_D4s_v3",
    "kubernetesVersion": "1.28.3"
  },
  "security": {
    "enableAAD": true,
    "enableRBAC": true,
    "enableNetworkPolicy": true,
    "keyVaultName": "kv-aks-prod-001"
  },
  "monitoring": {
    "enablePrometheus": true,
    "enableGrafana": true,
    "enableJaeger": true,
    "enableFluentd": true,
    "enableVelero": true
  }
}
```

### 4. Execute Enterprise Setup
```powershell
# Run the complete enterprise setup
.\scripts\00-run-enterprise-setup.ps1 -ConfigFile "config\enterprise-config.json"
```

## Detailed Setup Instructions

### Step 1: Enterprise AKS Infrastructure
```powershell
# Create enterprise-grade AKS cluster
.\scripts\01-enterprise-aks-setup.ps1 `
  -ResourceGroupName "rg-aks-prod-001" `
  -ClusterName "aks-prod-cluster-001" `
  -Location "East US 2" `
  -NodeCount 3 `
  -NodeSize "Standard_D4s_v3" `
  -Environment "production" `
  -EnablePrivateCluster `
  -EnableAADIntegration `
  -EnableNetworkPolicy `
  -EnableAutoScaling `
  -EnableMonitoring `
  -EnableBackup
```

**This script creates:**
- Resource group with enterprise tagging
- AKS cluster with security features
- Azure Container Registry (Premium tier)
- Azure Key Vault with advanced security
- Log Analytics workspace
- Managed identity configuration
- Auto-scaling configuration

### Step 2: Security Hardening
```powershell
# Apply comprehensive security configuration
.\scripts\02-security-hardening.ps1 `
  -ResourceGroupName "rg-aks-prod-001" `
  -ClusterName "aks-prod-cluster-001" `
  -KeyVaultName "kv-aks-prod-001" `
  -Environment "production" `
  -EnableNetworkPolicies `
  -EnablePodSecurityStandards `
  -EnableFalco `
  -EnableImageScanning
```

**Security features applied:**
- Pod Security Standards (PSS)
- Network policies for traffic isolation
- RBAC with least privilege principles
- Azure Key Vault integration
- Runtime security monitoring with Falco
- Security scanning and compliance

### Step 3: Monitoring and Observability
```powershell
# Deploy comprehensive monitoring stack
.\scripts\03-setup-monitoring.ps1 `
  -ResourceGroupName "rg-aks-prod-001" `
  -ClusterName "aks-prod-cluster-001" `
  -EnablePrometheus `
  -EnableGrafana `
  -EnableJaeger `
  -EnableFluentd `
  -EnableAlertManager `
  -EnableVelero
```

**Monitoring components installed:**
- Prometheus for metrics collection
- Grafana with enterprise dashboards
- Jaeger for distributed tracing
- Fluentd for centralized logging
- AlertManager for notifications
- Velero for backup and disaster recovery

### Step 4: Quarkus Development Environment
```powershell
# Install enterprise Quarkus environment
.\scripts\04-install-quarkus-enterprise.ps1 `
  -JavaVersion "17" `
  -EnableEnterpriseExtensions `
  -ConfigureIDE `
  -SetupDevContainers
```

**Development tools installed:**
- Java OpenJDK 17 LTS
- Apache Maven with enterprise repositories
- Quarkus CLI with extensions
- VS Code with productivity extensions
- Code quality tools (SonarQube, CheckStyle)
- Container development tools

### Step 5: Camel K Enterprise Deployment
```powershell
# Deploy Camel K with enterprise configuration
.\scripts\05-install-camelk-enterprise.ps1 `
  -Namespace "camel-k" `
  -EnableMonitoring `
  -EnableSecurity `
  -EnableTracing `
  -RegistrySecret "acr-secret" `
  -InstallSamples
```

**Camel K features configured:**
- Operator with RBAC and security
- Integration platform for enterprise
- Monitoring and metrics collection
- Distributed tracing integration
- Container registry authentication
- Sample enterprise integrations

### Step 6: Verification and Testing
```powershell
# Run comprehensive verification
.\scripts\06-verify-enterprise-setup.ps1 `
  -RunSecurityScan `
  -RunPerformanceTest `
  -GenerateReport
```

## Security Configuration

### Network Security

#### Network Policies
Network policies control traffic flow between pods and namespaces:

```yaml
# Example: Camel K namespace network policy
apiVersion: networking.k8s.io/v1
kind: NetworkPolicy
metadata:
  name: camel-k-network-policy
  namespace: camel-k
spec:
  podSelector:
    matchLabels:
      camel.apache.org/integration: ""
  policyTypes:
  - Ingress
  - Egress
  ingress:
  - from:
    - namespaceSelector:
        matchLabels:
          name: monitoring
    ports:
    - protocol: TCP
      port: 8080
  egress:
  - to: []
    ports:
    - protocol: TCP
      port: 443
    - protocol: TCP
      port: 80
```

#### Pod Security Standards
Pod Security Standards enforce security policies:

```yaml
# Pod Security Policy for restricted workloads
apiVersion: policy/v1beta1
kind: PodSecurityPolicy
metadata:
  name: restricted
spec:
  privileged: false
  allowPrivilegeEscalation: false
  requiredDropCapabilities:
    - ALL
  volumes:
    - 'configMap'
    - 'emptyDir'
    - 'projected'
    - 'secret'
    - 'downwardAPI'
    - 'persistentVolumeClaim'
  runAsUser:
    rule: 'MustRunAsNonRoot'
```

### RBAC Configuration

#### Service Accounts and Roles
```yaml
# Camel K developer role
apiVersion: rbac.authorization.k8s.io/v1
kind: ClusterRole
metadata:
  name: camel-k-developer
rules:
- apiGroups: ["camel.apache.org"]
  resources: ["integrations", "integrationkits", "integrationplatforms"]
  verbs: ["get", "list", "create", "update", "patch", "delete"]
- apiGroups: [""]
  resources: ["configmaps", "secrets", "services"]
  verbs: ["get", "list", "create", "update", "patch"]
```

### Secret Management

#### Azure Key Vault Integration
```yaml
apiVersion: secrets-store.csi.x-k8s.io/v1
kind: SecretProviderClass
metadata:
  name: camel-k-secrets
  namespace: camel-k
spec:
  provider: azure
  parameters:
    usePodIdentity: "false"
    useVMManagedIdentity: "true"
    keyvaultName: "kv-aks-prod-001"
    objects: |
      array:
        - |
          objectName: database-password
          objectType: secret
        - |
          objectName: api-key
          objectType: secret
```

## Monitoring and Observability

### Prometheus Configuration

#### Custom Metrics for Camel K
```yaml
# ServiceMonitor for Camel K integrations
apiVersion: monitoring.coreos.com/v1
kind: ServiceMonitor
metadata:
  name: camel-k-metrics
  namespace: monitoring
spec:
  selector:
    matchLabels:
      camel.apache.org/integration: ""
  endpoints:
  - port: metrics
    path: /actuator/prometheus
    interval: 30s
```

### Grafana Dashboards

#### Camel K Enterprise Dashboard
- Integration status and health
- Message throughput and latency
- Resource utilization (CPU, Memory)
- Error rates and patterns
- Performance trends

#### Security Dashboard
- Security alerts and violations
- Pod security policy compliance
- Network policy effectiveness
- Runtime security events

### Alerting Rules

#### Critical Alerts
```yaml
groups:
- name: camel-k-critical
  rules:
  - alert: CamelKIntegrationDown
    expr: sum(camel_k_integration_status{status="Error"}) > 0
    for: 5m
    labels:
      severity: critical
    annotations:
      summary: "Camel K integration is down"
      description: "Integration {{ $labels.integration }} is in error state"
```

## Backup and Disaster Recovery

### Velero Backup Strategy

#### Automated Daily Backups
```yaml
apiVersion: velero.io/v1
kind: Schedule
metadata:
  name: daily-backup
spec:
  schedule: "0 2 * * *"
  template:
    ttl: "168h"
    includedNamespaces:
    - camel-k
    - monitoring
    - logging
    storageLocation: azure
```

#### Recovery Procedures
1. **Cluster Recovery**: Automated recreation with Terraform
2. **Application Recovery**: GitOps-based restoration
3. **Data Recovery**: Persistent volume snapshots
4. **Configuration Recovery**: YAML manifests in Git

### Backup Verification
```powershell
# Test backup and restore
velero backup create test-backup --include-namespaces camel-k
velero restore create --from-backup test-backup
```

## Compliance and Governance

### Supported Compliance Frameworks
- **SOC 2 Type II**: Security and availability controls
- **ISO 27001**: Information security management
- **PCI DSS**: Payment card industry standards
- **HIPAA**: Healthcare data protection
- **GDPR**: General Data Protection Regulation

### Policy Enforcement

#### OPA Gatekeeper Policies
```yaml
apiVersion: templates.gatekeeper.sh/v1beta1
kind: ConstraintTemplate
metadata:
  name: k8srequiredlabels
spec:
  crd:
    spec:
      names:
        kind: K8sRequiredLabels
      validation:
        type: object
        properties:
          labels:
            type: array
            items:
              type: string
```

### Audit and Compliance

#### Audit Trail Configuration
```yaml
apiVersion: v1
kind: ConfigMap
metadata:
  name: audit-policy
  namespace: kube-system
data:
  audit-policy.yaml: |
    apiVersion: audit.k8s.io/v1
    kind: Policy
    rules:
    - level: RequestResponse
      namespaces: ["camel-k"]
      verbs: ["create", "update", "delete"]
      resources:
      - group: "camel.apache.org"
        resources: ["integrations"]
```

## Operations and Maintenance

### Daily Operations Checklist
- [ ] Review monitoring dashboards
- [ ] Check security alerts
- [ ] Verify backup completion
- [ ] Monitor resource utilization
- [ ] Review audit logs

### Weekly Maintenance Tasks
```powershell
# Run weekly maintenance script
.\scripts\maintenance\weekly-maintenance.ps1 `
  -UpdateImages `
  -CleanupOrphanedResources `
  -GenerateHealthReport `
  -RotateSecrets
```

### Monthly Reviews
- Security assessment and updates
- Performance optimization
- Cost analysis and optimization
- Backup and recovery testing
- Compliance reporting

### Performance Tuning

#### Node Pool Optimization
```powershell
# Optimize node pools for workloads
az aks nodepool update `
  --resource-group $ResourceGroupName `
  --cluster-name $ClusterName `
  --name nodepool1 `
  --enable-cluster-autoscaler `
  --min-count 2 `
  --max-count 10
```

#### Resource Quotas
```yaml
apiVersion: v1
kind: ResourceQuota
metadata:
  name: camel-k-quota
  namespace: camel-k
spec:
  hard:
    requests.cpu: "4"
    requests.memory: 8Gi
    limits.cpu: "8"
    limits.memory: 16Gi
    pods: "10"
```

## Troubleshooting

### Common Issues and Solutions

#### Issue: Camel K Integration Fails to Start
**Symptoms:**
- Integration stuck in "Building" or "Error" state
- Pod fails to start

**Diagnosis:**
```powershell
# Check integration status
kubectl get integrations -n camel-k

# Check operator logs
kubectl logs -f deployment/camel-k-operator -n camel-k

# Check integration pod logs
kubectl logs -f <integration-pod> -n camel-k
```

**Solutions:**
1. Check resource quotas and limits
2. Verify container registry access
3. Review integration configuration
4. Check network policies

#### Issue: Monitoring Stack Not Collecting Metrics
**Symptoms:**
- Missing metrics in Grafana
- Prometheus targets down

**Diagnosis:**
```powershell
# Check Prometheus targets
kubectl port-forward -n monitoring svc/prometheus-stack-prometheus 9090:9090
# Navigate to http://localhost:9090/targets

# Check ServiceMonitor configuration
kubectl get servicemonitor -n monitoring -o yaml
```

**Solutions:**
1. Verify ServiceMonitor selectors
2. Check network policies
3. Restart Prometheus pods
4. Review metric endpoints

#### Issue: Security Policy Violations
**Symptoms:**
- Pods failing to start
- Security alerts firing

**Diagnosis:**
```powershell
# Check security policies
kubectl get networkpolicies -A
kubectl get podsecuritypolicies

# Review audit logs
kubectl logs -n kube-system -l component=audit
```

**Solutions:**
1. Review and update security policies
2. Check pod security contexts
3. Verify RBAC permissions
4. Update network policies

### Debugging Commands

#### Cluster Health
```powershell
# Node status
kubectl get nodes -o wide

# Pod status across namespaces
kubectl get pods -A

# Resource utilization
kubectl top nodes
kubectl top pods -A

# Events
kubectl get events -A --sort-by='.lastTimestamp'
```

#### Application Debugging
```powershell
# Camel K integration logs
kamel logs <integration-name> -n camel-k

# Describe integration
kubectl describe integration <integration-name> -n camel-k

# Check integration platform
kubectl get integrationplatform -n camel-k -o yaml
```

## Cost Optimization

### Cost Management Strategies

#### Right-Sizing Resources
```powershell
# Analyze resource utilization
kubectl top pods -A --sort-by='cpu'
kubectl top pods -A --sort-by='memory'

# Adjust resource requests and limits based on actual usage
```

#### Auto-Scaling Configuration
```yaml
# Horizontal Pod Autoscaler
apiVersion: autoscaling/v2
kind: HorizontalPodAutoscaler
metadata:
  name: camel-k-hpa
  namespace: camel-k
spec:
  scaleTargetRef:
    apiVersion: apps/v1
    kind: Deployment
    name: camel-k-integration
  minReplicas: 1
  maxReplicas: 10
  metrics:
  - type: Resource
    resource:
      name: cpu
      target:
        type: Utilization
        averageUtilization: 70
```

#### Reserved Instances
- Use Azure Reserved VM Instances for predictable workloads
- Implement Spot instances for development environments
- Optimize storage tiers for different data types

### Cost Monitoring
```powershell
# Generate cost report
.\scripts\cost\generate-cost-report.ps1 `
  -ResourceGroupName "rg-aks-prod-001" `
  -Period "LastMonth" `
  -ExportPath "reports\cost-analysis.xlsx"
```

### Optimization Recommendations
1. **Cluster Auto-scaling**: Enable cluster autoscaler
2. **Pod Disruption Budgets**: Implement for high availability
3. **Resource Quotas**: Set appropriate limits
4. **Storage Optimization**: Use appropriate storage classes
5. **Network Optimization**: Optimize egress costs

## Support and Maintenance

### Support Channels
- **Technical Documentation**: This comprehensive guide
- **Community Support**: Kubernetes and Camel K communities
- **Azure Support**: Azure portal support tickets
- **Emergency Procedures**: Incident response playbooks

### SLA Commitments
- **Uptime**: 99.9% availability
- **Response Time**: < 4 hours for critical issues
- **Resolution Time**: < 24 hours for critical issues
- **Support Hours**: 24/7 for production environments

### Maintenance Windows
- **Planned Maintenance**: First Sunday of each month, 2:00 AM - 6:00 AM UTC
- **Emergency Maintenance**: As needed with 4-hour notice
- **Security Updates**: Applied during maintenance windows

## Conclusion

This enterprise-grade setup provides a robust, secure, and scalable platform for running Quarkus applications with Camel K on Azure Kubernetes Service. The configuration includes comprehensive monitoring, security, backup, and compliance features suitable for production environments.

### Key Benefits
- **Security**: Enterprise-grade security with defense in depth
- **Observability**: Comprehensive monitoring and alerting
- **Reliability**: High availability and disaster recovery
- **Compliance**: Support for major compliance frameworks
- **Scalability**: Auto-scaling and performance optimization
- **Maintainability**: Automated operations and clear procedures

### Next Steps
1. Complete the setup using the provided scripts
2. Customize configuration for your specific requirements
3. Implement CI/CD pipelines for application deployment
4. Conduct security and performance testing
5. Train your team on operations and troubleshooting

---

**Document Version**: 1.0  
**Last Updated**: October 29, 2025  
**Next Review**: January 29, 2026  
**Classification**: Enterprise Internal Use