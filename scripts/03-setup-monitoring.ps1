# Enterprise Monitoring and Observability Setup for AKS
# This script deploys a comprehensive monitoring stack with Prometheus, Grafana, Jaeger, and logging

param(
    [Parameter(Mandatory=$true)]
    [string]$ResourceGroupName,
    
    [Parameter(Mandatory=$true)]
    [string]$ClusterName,
    
    [Parameter(Mandatory=$false)]
    [string]$MonitoringNamespace = "monitoring",
    
    [Parameter(Mandatory=$false)]
    [string]$LoggingNamespace = "logging",
    
    [Parameter(Mandatory=$false)]
    [string]$TracingNamespace = "tracing",
    
    [Parameter(Mandatory=$false)]
    [switch]$EnablePrometheus,
    
    [Parameter(Mandatory=$false)]
    [switch]$EnableGrafana,
    
    [Parameter(Mandatory=$false)]
    [switch]$EnableJaeger,
    
    [Parameter(Mandatory=$false)]
    [switch]$EnableFluentd,
    
    [Parameter(Mandatory=$false)]
    [switch]$EnableAlertManager,
    
    [Parameter(Mandatory=$false)]
    [switch]$EnableVelero,
    
    [Parameter(Mandatory=$false)]
    [string]$StorageClass = "managed-csi"
)

# Color output functions
function Write-ColorOutput([String] $ForegroundColor, [String] $Message) {
    Write-Host $Message -ForegroundColor $ForegroundColor
}

function Write-Success([String] $Message) {
    Write-ColorOutput "Green" "✓ $Message"
}

function Write-Info([String] $Message) {
    Write-ColorOutput "Cyan" "ℹ $Message"
}

function Write-Warning([String] $Message) {
    Write-ColorOutput "Yellow" "⚠ $Message"
}

function Write-Error([String] $Message) {
    Write-ColorOutput "Red" "✗ $Message"
}

function Write-Header([String] $Message) {
    Write-Host ""
    Write-ColorOutput "Magenta" "=========================================="
    Write-ColorOutput "Magenta" $Message
    Write-ColorOutput "Magenta" "=========================================="
}

# Function to validate prerequisites
function Test-Prerequisites {
    Write-Header "Validating Prerequisites"
    
    # Check cluster connection
    try {
        az aks get-credentials --resource-group $ResourceGroupName --name $ClusterName --overwrite-existing --output none
        $clusterInfo = kubectl cluster-info --request-timeout=10s 2>$null
        if (-not $clusterInfo) {
            throw "Cannot connect to cluster"
        }
        Write-Success "Connected to AKS cluster '$ClusterName'"
    }
    catch {
        Write-Error "Failed to connect to cluster: $($_.Exception.Message)"
        exit 1
    }
    
    # Check Helm
    try {
        $helmVersion = helm version --short 2>$null
        Write-Success "Helm found: $helmVersion"
    }
    catch {
        Write-Error "Helm not found. Please install Helm first."
        exit 1
    }
    
    # Add required Helm repositories
    Write-Info "Adding Helm repositories..."
    helm repo add prometheus-community https://prometheus-community.github.io/helm-charts
    helm repo add grafana https://grafana.github.io/helm-charts
    helm repo add jaegertracing https://jaegertracing.github.io/helm-charts
    helm repo add fluent https://fluent.github.io/helm-charts
    helm repo add vmware-tanzu https://vmware-tanzu.github.io/helm-charts
    helm repo update
    
    Write-Success "Helm repositories added and updated"
}

# Function to create monitoring namespaces
function New-MonitoringNamespaces {
    Write-Header "Creating Monitoring Namespaces"
    
    $namespaces = @($MonitoringNamespace, $LoggingNamespace, $TracingNamespace)
    
    foreach ($ns in $namespaces) {
        try {
            kubectl create namespace $ns --dry-run=client -o yaml | kubectl apply -f -
            kubectl label namespace $ns monitoring=enabled --overwrite
            kubectl label namespace $ns security-level=medium --overwrite
            Write-Success "Namespace '$ns' created and configured"
        }
        catch {
            Write-Warning "Failed to create namespace '$ns': $($_.Exception.Message)"
        }
    }
}

# Function to install Prometheus monitoring stack
function Install-PrometheusStack {
    Write-Header "Installing Prometheus Monitoring Stack"
    
    if (-not $EnablePrometheus) {
        Write-Info "Prometheus not enabled, skipping installation..."
        return
    }
    
    try {
        # Create Prometheus configuration
        $prometheusConfig = @"
prometheus:
  prometheusSpec:
    serviceMonitorSelectorNilUsesHelmValues: false
    podMonitorSelectorNilUsesHelmValues: false
    ruleSelectorNilUsesHelmValues: false
    retention: 30d
    storageSpec:
      volumeClaimTemplate:
        spec:
          storageClassName: $StorageClass
          accessModes: ["ReadWriteOnce"]
          resources:
            requests:
              storage: 50Gi
    resources:
      requests:
        cpu: 500m
        memory: 2Gi
      limits:
        cpu: 2000m
        memory: 8Gi
    additionalScrapeConfigs:
      - job_name: 'camel-k-integrations'
        kubernetes_sd_configs:
          - role: pod
            namespaces:
              names:
                - camel-k
        relabel_configs:
          - source_labels: [__meta_kubernetes_pod_annotation_prometheus_io_scrape]
            action: keep
            regex: true
          - source_labels: [__meta_kubernetes_pod_annotation_prometheus_io_path]
            action: replace
            target_label: __metrics_path__
            regex: (.+)
          - source_labels: [__address__, __meta_kubernetes_pod_annotation_prometheus_io_port]
            action: replace
            regex: ([^:]+)(?::\d+)?;(\d+)
            replacement: '${1}:${2}'
            target_label: __address__

grafana:
  enabled: true
  adminPassword: "admin123!"
  persistence:
    enabled: true
    storageClassName: $StorageClass
    size: 10Gi
  resources:
    requests:
      cpu: 100m
      memory: 128Mi
    limits:
      cpu: 500m
      memory: 512Mi
  dashboardProviders:
    dashboardproviders.yaml:
      apiVersion: 1
      providers:
      - name: 'default'
        orgId: 1
        folder: ''
        type: file
        disableDeletion: false
        editable: true
        options:
          path: /var/lib/grafana/dashboards/default
  dashboards:
    default:
      camel-k-overview:
        gnetId: 12052
        revision: 1
        datasource: Prometheus
      kubernetes-cluster:
        gnetId: 7249
        revision: 1
        datasource: Prometheus
      kubernetes-pods:
        gnetId: 6336
        revision: 1
        datasource: Prometheus
      jvm-micrometer:
        gnetId: 4701
        revision: 6
        datasource: Prometheus

alertmanager:
  enabled: $EnableAlertManager
  alertmanagerSpec:
    storage:
      volumeClaimTemplate:
        spec:
          storageClassName: $StorageClass
          accessModes: ["ReadWriteOnce"]
          resources:
            requests:
              storage: 10Gi
  config:
    global:
      smtp_smarthost: 'localhost:587'
      smtp_from: 'alerts@company.com'
    route:
      group_by: ['alertname']
      group_wait: 10s
      group_interval: 10s
      repeat_interval: 1h
      receiver: 'web.hook'
    receivers:
    - name: 'web.hook'
      webhook_configs:
      - url: 'http://localhost:5001/'

kubeStateMetrics:
  enabled: true

nodeExporter:
  enabled: true

defaultRules:
  create: true
  rules:
    alertmanager: true
    etcd: true
    general: true
    k8s: true
    kubeApiserver: true
    kubePrometheusNodeRecording: true
    kubernetesApps: true
    kubernetesResources: true
    kubernetesStorage: true
    kubernetesSystem: true
    node: true
    prometheus: true
"@
        
        $configFile = "$env:TEMP\prometheus-values.yaml"
        $prometheusConfig | Out-File -FilePath $configFile -Encoding UTF8
        
        # Install Prometheus stack
        Write-Info "Installing Prometheus monitoring stack (this may take several minutes)..."
        helm upgrade --install prometheus-stack prometheus-community/kube-prometheus-stack `
            --namespace $MonitoringNamespace `
            --create-namespace `
            --values $configFile `
            --wait `
            --timeout 20m
            
        Remove-Item $configFile -Force -ErrorAction SilentlyContinue
        
        Write-Success "Prometheus monitoring stack installed successfully"
        
        # Create ServiceMonitor for Camel K
        $camelkServiceMonitor = @"
apiVersion: monitoring.coreos.com/v1
kind: ServiceMonitor
metadata:
  name: camel-k-metrics
  namespace: $MonitoringNamespace
  labels:
    app: camel-k
spec:
  selector:
    matchLabels:
      camel.apache.org/integration: ""
  namespaceSelector:
    matchNames:
    - camel-k
  endpoints:
  - port: metrics
    path: /actuator/prometheus
    interval: 30s
    scrapeTimeout: 10s
  - port: http
    path: /metrics
    interval: 30s
    scrapeTimeout: 10s
"@
        
        $camelkServiceMonitor | kubectl apply -f -
        Write-Success "Camel K ServiceMonitor configured"
        
    }
    catch {
        Write-Error "Failed to install Prometheus stack: $($_.Exception.Message)"
    }
}

# Function to install Jaeger for distributed tracing
function Install-Jaeger {
    Write-Header "Installing Jaeger Distributed Tracing"
    
    if (-not $EnableJaeger) {
        Write-Info "Jaeger not enabled, skipping installation..."
        return
    }
    
    try {
        # Create Jaeger configuration
        $jaegerConfig = @"
provisionDataStore:
  cassandra: false
  elasticsearch: true

storage:
  type: elasticsearch
  elasticsearch:
    host: jaeger-elasticsearch
    port: 9200

elasticsearch:
  enabled: true
  replicas: 1
  minimumMasterNodes: 1
  resources:
    requests:
      cpu: 500m
      memory: 1Gi
    limits:
      cpu: 1000m
      memory: 2Gi
  volumeClaimTemplate:
    accessModes: ["ReadWriteOnce"]
    storageClassName: $StorageClass
    resources:
      requests:
        storage: 20Gi

agent:
  enabled: true
  annotations:
    prometheus.io/scrape: "true"
    prometheus.io/port: "14271"

collector:
  enabled: true
  replicaCount: 1
  resources:
    requests:
      cpu: 100m
      memory: 256Mi
    limits:
      cpu: 500m
      memory: 512Mi
  service:
    annotations:
      prometheus.io/scrape: "true"
      prometheus.io/port: "14269"

query:
  enabled: true
  replicaCount: 1
  resources:
    requests:
      cpu: 100m
      memory: 256Mi
    limits:
      cpu: 500m
      memory: 512Mi
  service:
    type: ClusterIP
    port: 80

hotrod:
  enabled: false
"@
        
        $configFile = "$env:TEMP\jaeger-values.yaml"
        $jaegerConfig | Out-File -FilePath $configFile -Encoding UTF8
        
        # Install Jaeger
        Write-Info "Installing Jaeger tracing stack..."
        helm upgrade --install jaeger jaegertracing/jaeger `
            --namespace $TracingNamespace `
            --create-namespace `
            --values $configFile `
            --wait `
            --timeout 15m
            
        Remove-Item $configFile -Force -ErrorAction SilentlyContinue
        
        Write-Success "Jaeger distributed tracing installed successfully"
        
        # Create Jaeger ServiceMonitor
        $jaegerServiceMonitor = @"
apiVersion: monitoring.coreos.com/v1
kind: ServiceMonitor
metadata:
  name: jaeger-metrics
  namespace: $MonitoringNamespace
  labels:
    app: jaeger
spec:
  selector:
    matchLabels:
      app.kubernetes.io/name: jaeger
  namespaceSelector:
    matchNames:
    - $TracingNamespace
  endpoints:
  - port: admin-http
    path: /metrics
    interval: 30s
"@
        
        $jaegerServiceMonitor | kubectl apply -f -
        Write-Success "Jaeger ServiceMonitor configured"
        
    }
    catch {
        Write-Error "Failed to install Jaeger: $($_.Exception.Message)"
    }
}

# Function to install Fluentd for centralized logging
function Install-FluentdLogging {
    Write-Header "Installing Fluentd Centralized Logging"
    
    if (-not $EnableFluentd) {
        Write-Info "Fluentd not enabled, skipping installation..."
        return
    }
    
    try {
        # Create Fluentd configuration
        $fluentdConfig = @"
elasticsearch:
  enabled: true
  host: "fluentd-elasticsearch"
  port: 9200
  scheme: http
  
  # Elasticsearch cluster configuration
  replicas: 1
  minimumMasterNodes: 1
  resources:
    requests:
      cpu: 500m
      memory: 1Gi
    limits:
      cpu: 1000m
      memory: 2Gi
  volumeClaimTemplate:
    accessModes: ["ReadWriteOnce"]
    storageClassName: $StorageClass
    resources:
      requests:
        storage: 50Gi

kibana:
  enabled: true
  resources:
    requests:
      cpu: 100m
      memory: 512Mi
    limits:
      cpu: 1000m
      memory: 1Gi
  service:
    type: ClusterIP
    port: 5601

fluentd:
  replicaCount: 1
  resources:
    requests:
      cpu: 100m
      memory: 256Mi
    limits:
      cpu: 500m
      memory: 1Gi
  
  # Custom configuration for Camel K logs
  configMaps:
    output.conf: |
      <match kubernetes.**>
        @type elasticsearch
        @id out_es
        @log_level info
        include_tag_key true
        host "#{ENV['OUTPUT_HOST']}"
        port "#{ENV['OUTPUT_PORT']}"
        path "#{ENV['OUTPUT_PATH']}"
        scheme "#{ENV['OUTPUT_SCHEME']}"
        ssl_version "#{ENV['OUTPUT_SSL_VERSION']}"
        ssl_verify true
        reload_connections true
        reconnect_on_error true
        reload_on_failure true
        log_es_400_reason true
        logstash_prefix camel-k
        logstash_dateformat %Y.%m.%d
        logstash_format true
        index_name fluentd
        type_name fluentd
        <buffer>
          flush_thread_count 8
          flush_interval 5s
          chunk_limit_size 2M
          queue_limit_length 32
          retry_max_interval 30
          retry_forever true
        </buffer>
      </match>
    
    filter.conf: |
      <filter kubernetes.**>
        @type kubernetes_metadata
        @id filter_kube_metadata
        kubernetes_url "#{ENV['FLUENT_FILTER_KUBERNETES_URL']}"
        verify_ssl "#{ENV['KUBERNETES_VERIFY_SSL']}"
        ca_file "#{ENV['KUBERNETES_CA_FILE']}"
        skip_labels true
        skip_container_metadata true
        skip_master_url true
        skip_namespace_metadata true
      </filter>
      
      <filter kubernetes.var.log.containers.**camel-k**.log>
        @type parser
        key_name log
        reserve_data true
        remove_key_name_field true
        <parse>
          @type multi_format
          <pattern>
            format json
          </pattern>
          <pattern>
            format regex
            expression /^(?<time>\d{4}-\d{2}-\d{2} \d{2}:\d{2}:\d{2}.\d{3})\s+(?<level>\w+)\s+(?<thread>\S+)\s+(?<logger>\S+)\s+-\s+(?<message>.*)$/
          </pattern>
        </parse>
      </filter>

filebeat:
  enabled: false

logstash:
  enabled: false
"@
        
        $configFile = "$env:TEMP\fluentd-values.yaml"
        $fluentdConfig | Out-File -FilePath $configFile -Encoding UTF8
        
        # Install Fluentd
        Write-Info "Installing Fluentd logging stack..."
        helm upgrade --install fluentd fluent/fluentd `
            --namespace $LoggingNamespace `
            --create-namespace `
            --values $configFile `
            --wait `
            --timeout 15m
            
        Remove-Item $configFile -Force -ErrorAction SilentlyContinue
        
        Write-Success "Fluentd centralized logging installed successfully"
        
    }
    catch {
        Write-Error "Failed to install Fluentd: $($_.Exception.Message)"
    }
}

# Function to install Velero for backup
function Install-Velero {
    Write-Header "Installing Velero Backup Solution"
    
    if (-not $EnableVelero) {
        Write-Info "Velero not enabled, skipping installation..."
        return
    }
    
    try {
        # Create Azure storage account for Velero backups
        $storageAccountName = "velero$($ClusterName.Replace('-','').ToLower())$(Get-Random -Minimum 100 -Maximum 999)"
        $containerName = "velero"
        
        Write-Info "Creating Azure storage account for Velero backups..."
        az storage account create `
            --name $storageAccountName `
            --resource-group $ResourceGroupName `
            --location $Location `
            --sku Standard_LRS `
            --kind StorageV2 `
            --output none
            
        $storageKey = az storage account keys list --resource-group $ResourceGroupName --account-name $storageAccountName --query "[0].value" --output tsv
        
        az storage container create `
            --name $containerName `
            --account-name $storageAccountName `
            --account-key $storageKey `
            --output none
            
        Write-Success "Azure storage account '$storageAccountName' created for Velero"
        
        # Create Velero secret
        kubectl create secret generic cloud-credentials `
            --namespace velero `
            --from-literal AZURE_STORAGE_ACCOUNT_ACCESS_KEY=$storageKey `
            --from-literal AZURE_CLOUD_NAME=AzurePublicCloud `
            --dry-run=client -o yaml | kubectl apply -f -
            
        # Create Velero configuration
        $veleroConfig = @"
configuration:
  provider: azure
  backupStorageLocation:
    name: azure
    provider: azure
    bucket: $containerName
    config:
      resourceGroup: $ResourceGroupName
      storageAccount: $storageAccountName
  volumeSnapshotLocation:
    name: azure
    provider: azure
    config:
      resourceGroup: $ResourceGroupName

credentials:
  useSecret: true
  name: cloud-credentials

schedules:
  daily-backup:
    disabled: false
    schedule: "0 2 * * *"
    template:
      ttl: "168h"
      includedNamespaces:
      - camel-k
      - monitoring
      - logging
      - tracing
      storageLocation: azure
      volumeSnapshotLocations:
      - azure

deployRestic: true

restic:
  podVolumePath: /var/lib/kubelet/pods
  privileged: false
  resources:
    requests:
      cpu: 500m
      memory: 512Mi
    limits:
      cpu: 1000m
      memory: 1Gi

metrics:
  enabled: true
  scrapeInterval: 30s
  serviceMonitor:
    enabled: true
    additionalLabels:
      monitoring: enabled

initContainers:
- name: velero-plugin-for-microsoft-azure
  image: velero/velero-plugin-for-microsoft-azure:v1.7.0
  imagePullPolicy: IfNotPresent
  volumeMounts:
  - mountPath: /target
    name: plugins
"@
        
        $configFile = "$env:TEMP\velero-values.yaml"
        $veleroConfig | Out-File -FilePath $configFile -Encoding UTF8
        
        # Install Velero
        Write-Info "Installing Velero backup solution..."
        helm upgrade --install velero vmware-tanzu/velero `
            --namespace velero `
            --create-namespace `
            --values $configFile `
            --wait `
            --timeout 10m
            
        Remove-Item $configFile -Force -ErrorAction SilentlyContinue
        
        Write-Success "Velero backup solution installed successfully"
        Write-Info "Daily backups scheduled at 2:00 AM"
        
    }
    catch {
        Write-Error "Failed to install Velero: $($_.Exception.Message)"
    }
}

# Function to create custom Grafana dashboards
function New-CustomDashboards {
    Write-Header "Creating Custom Grafana Dashboards"
    
    try {
        # Camel K Enterprise Dashboard
        $camelkDashboard = @"
apiVersion: v1
kind: ConfigMap
metadata:
  name: camel-k-enterprise-dashboard
  namespace: $MonitoringNamespace
  labels:
    grafana_dashboard: "1"
data:
  camel-k-enterprise.json: |
    {
      "dashboard": {
        "id": null,
        "title": "Camel K Enterprise Overview",
        "tags": ["camel-k", "enterprise"],
        "timezone": "browser",
        "panels": [
          {
            "id": 1,
            "title": "Integration Status",
            "type": "stat",
            "targets": [
              {
                "expr": "sum(camel_k_integration_status{namespace=\"camel-k\"})",
                "legendFormat": "Total Integrations"
              }
            ],
            "fieldConfig": {
              "defaults": {
                "color": {
                  "mode": "palette-classic"
                },
                "custom": {
                  "displayMode": "list",
                  "orientation": "horizontal"
                },
                "mappings": [],
                "thresholds": {
                  "steps": [
                    {
                      "color": "green",
                      "value": null
                    },
                    {
                      "color": "red",
                      "value": 80
                    }
                  ]
                }
              }
            },
            "gridPos": {
              "h": 8,
              "w": 12,
              "x": 0,
              "y": 0
            }
          },
          {
            "id": 2,
            "title": "Message Throughput",
            "type": "graph",
            "targets": [
              {
                "expr": "rate(camel_k_messages_total[5m])",
                "legendFormat": "Messages/sec"
              }
            ],
            "gridPos": {
              "h": 8,
              "w": 12,
              "x": 12,
              "y": 0
            }
          },
          {
            "id": 3,
            "title": "CPU Usage",
            "type": "graph",
            "targets": [
              {
                "expr": "rate(container_cpu_usage_seconds_total{namespace=\"camel-k\"}[5m])",
                "legendFormat": "{{ pod }}"
              }
            ],
            "gridPos": {
              "h": 8,
              "w": 12,
              "x": 0,
              "y": 8
            }
          },
          {
            "id": 4,
            "title": "Memory Usage",
            "type": "graph",
            "targets": [
              {
                "expr": "container_memory_usage_bytes{namespace=\"camel-k\"}",
                "legendFormat": "{{ pod }}"
              }
            ],
            "gridPos": {
              "h": 8,
              "w": 12,
              "x": 12,
              "y": 8
            }
          }
        ],
        "time": {
          "from": "now-1h",
          "to": "now"
        },
        "refresh": "30s"
      }
    }
"@
        
        $camelkDashboard | kubectl apply -f -
        Write-Success "Camel K Enterprise dashboard created"
        
        # Security Dashboard
        $securityDashboard = @"
apiVersion: v1
kind: ConfigMap
metadata:
  name: security-dashboard
  namespace: $MonitoringNamespace
  labels:
    grafana_dashboard: "1"
data:
  security-overview.json: |
    {
      "dashboard": {
        "id": null,
        "title": "Security Overview",
        "tags": ["security", "enterprise"],
        "timezone": "browser",
        "panels": [
          {
            "id": 1,
            "title": "Security Alerts",
            "type": "stat",
            "targets": [
              {
                "expr": "sum(ALERTS{alertname=~\".*Security.*\"})",
                "legendFormat": "Active Security Alerts"
              }
            ],
            "gridPos": {
              "h": 4,
              "w": 6,
              "x": 0,
              "y": 0
            }
          },
          {
            "id": 2,
            "title": "Pod Security Policy Violations",
            "type": "graph",
            "targets": [
              {
                "expr": "increase(pod_security_policy_violations_total[5m])",
                "legendFormat": "PSP Violations"
              }
            ],
            "gridPos": {
              "h": 8,
              "w": 12,
              "x": 0,
              "y": 4
            }
          },
          {
            "id": 3,
            "title": "Network Policy Denials",
            "type": "graph",
            "targets": [
              {
                "expr": "increase(networkpolicy_drop_total[5m])",
                "legendFormat": "Network Denials"
              }
            ],
            "gridPos": {
              "h": 8,
              "w": 12,
              "x": 12,
              "y": 4
            }
          }
        ],
        "time": {
          "from": "now-24h",
          "to": "now"
        },
        "refresh": "1m"
      }
    }
"@
        
        $securityDashboard | kubectl apply -f -
        Write-Success "Security overview dashboard created"
        
    }
    catch {
        Write-Error "Failed to create custom dashboards: $($_.Exception.Message)"
    }
}

# Function to configure monitoring alerts
function Set-MonitoringAlerts {
    Write-Header "Configuring Monitoring Alerts"
    
    try {
        # Create enterprise alerting rules
        $alertingRules = @"
apiVersion: monitoring.coreos.com/v1
kind: PrometheusRule
metadata:
  name: enterprise-alerting-rules
  namespace: $MonitoringNamespace
  labels:
    prometheus: kube-prometheus
    role: alert-rules
spec:
  groups:
  - name: camel-k-enterprise
    rules:
    - alert: CamelKIntegrationDown
      expr: sum(camel_k_integration_status{status="Error"}) > 0
      for: 5m
      labels:
        severity: critical
      annotations:
        summary: "Camel K integration is down"
        description: "Camel K integration {{ \$labels.integration }} in namespace {{ \$labels.namespace }} is in error state"
    
    - alert: CamelKHighErrorRate
      expr: rate(camel_k_errors_total[5m]) > 0.1
      for: 5m
      labels:
        severity: warning
      annotations:
        summary: "High error rate in Camel K integration"
        description: "Camel K integration {{ \$labels.integration }} has high error rate: {{ \$value }} errors/sec"
    
    - alert: CamelKHighMemoryUsage
      expr: container_memory_usage_bytes{namespace="camel-k"} / container_spec_memory_limit_bytes > 0.8
      for: 10m
      labels:
        severity: warning
      annotations:
        summary: "High memory usage in Camel K pod"
        description: "Pod {{ \$labels.pod }} is using {{ \$value | humanizePercentage }} of memory limit"
    
    - alert: CamelKHighCPUUsage
      expr: rate(container_cpu_usage_seconds_total{namespace="camel-k"}[5m]) / container_spec_cpu_quota * 100 > 80
      for: 10m
      labels:
        severity: warning
      annotations:
        summary: "High CPU usage in Camel K pod"
        description: "Pod {{ \$labels.pod }} is using {{ \$value }}% CPU"
  
  - name: security-enterprise
    rules:
    - alert: SecurityPolicyViolation
      expr: increase(pod_security_policy_violations_total[5m]) > 0
      for: 0m
      labels:
        severity: critical
      annotations:
        summary: "Security policy violation detected"
        description: "Security policy violation in namespace {{ \$labels.namespace }}"
    
    - alert: UnauthorizedNetworkAccess
      expr: increase(networkpolicy_drop_total[5m]) > 10
      for: 2m
      labels:
        severity: warning
      annotations:
        summary: "High number of network policy denials"
        description: "Unusual network access patterns detected"
        
    - alert: SuspiciousProcessActivity
      expr: increase(falco_events{rule_name=~".*Suspicious.*"}[5m]) > 0
      for: 0m
      labels:
        severity: critical
      annotations:
        summary: "Suspicious process activity detected"
        description: "Falco detected suspicious activity: {{ \$labels.rule_name }}"
  
  - name: infrastructure-enterprise
    rules:
    - alert: NodeNotReady
      expr: kube_node_status_condition{condition="Ready",status="true"} == 0
      for: 10m
      labels:
        severity: critical
      annotations:
        summary: "Kubernetes node not ready"
        description: "Node {{ \$labels.node }} has been not ready for more than 10 minutes"
    
    - alert: PodCrashLooping
      expr: rate(kube_pod_container_status_restarts_total[15m]) > 0
      for: 5m
      labels:
        severity: warning
      annotations:
        summary: "Pod is crash looping"
        description: "Pod {{ \$labels.pod }} in namespace {{ \$labels.namespace }} is restarting frequently"
"@
        
        $alertingRules | kubectl apply -f -
        Write-Success "Enterprise alerting rules configured"
        
    }
    catch {
        Write-Error "Failed to configure monitoring alerts: $($_.Exception.Message)"
    }
}

# Function to create monitoring summary
function New-MonitoringSummary {
    Write-Header "Generating Monitoring Setup Summary"
    
    try {
        $summaryPath = "C:\temp\aks-quarkus-camelk-setup\reports"
        if (-not (Test-Path $summaryPath)) {
            New-Item -ItemType Directory -Path $summaryPath -Force | Out-Null
        }
        
        $summaryFile = "$summaryPath\monitoring-summary-$(Get-Date -Format 'yyyy-MM-dd-HHmm').txt"
        
        $summary = @"
ENTERPRISE MONITORING SETUP SUMMARY
===================================
Generated: $(Get-Date)
Cluster: $ClusterName
Resource Group: $ResourceGroupName

MONITORING COMPONENTS INSTALLED:
"@
        
        if ($EnablePrometheus) {
            $summary += "`n✓ Prometheus Stack (Prometheus + Grafana + AlertManager)"
            $summary += "`n  - Prometheus: http://prometheus.$MonitoringNamespace.svc.cluster.local:9090"
            $summary += "`n  - Grafana: http://grafana.$MonitoringNamespace.svc.cluster.local"
            $summary += "`n  - AlertManager: http://alertmanager.$MonitoringNamespace.svc.cluster.local"
        }
        
        if ($EnableJaeger) {
            $summary += "`n✓ Jaeger Distributed Tracing"
            $summary += "`n  - Jaeger UI: http://jaeger-query.$TracingNamespace.svc.cluster.local"
        }
        
        if ($EnableFluentd) {
            $summary += "`n✓ Fluentd Centralized Logging"
            $summary += "`n  - Kibana: http://kibana.$LoggingNamespace.svc.cluster.local:5601"
        }
        
        if ($EnableVelero) {
            $summary += "`n✓ Velero Backup Solution"
            $summary += "`n  - Daily backups scheduled at 2:00 AM"
            $summary += "`n  - Retention: 7 days"
        }
        
        $summary += @"

ACCESS INSTRUCTIONS:
==================

Port Forwarding Commands:
# Grafana Dashboard
kubectl port-forward -n $MonitoringNamespace svc/prometheus-stack-grafana 3000:80

# Prometheus UI
kubectl port-forward -n $MonitoringNamespace svc/prometheus-stack-prometheus 9090:9090

# Jaeger UI
kubectl port-forward -n $TracingNamespace svc/jaeger-query 16686:80

# Kibana
kubectl port-forward -n $LoggingNamespace svc/fluentd-kibana 5601:5601

Default Credentials:
- Grafana: admin / admin123!

DASHBOARDS AVAILABLE:
- Camel K Enterprise Overview
- Security Overview
- Kubernetes Cluster Monitoring
- JVM Micrometer Metrics

ALERTS CONFIGURED:
- Camel K integration health
- High resource usage
- Security policy violations
- Infrastructure issues

BACKUP SCHEDULE:
- Daily backup at 2:00 AM
- Includes: camel-k, monitoring, logging, tracing namespaces
- Retention: 7 days

NEXT STEPS:
1. Access Grafana and review dashboards
2. Configure alert notification channels
3. Set up log retention policies
4. Test backup and restore procedures
5. Monitor and tune alert thresholds
"@
        
        $summary | Out-File -FilePath $summaryFile -Encoding UTF8
        Write-Success "Monitoring summary generated: $summaryFile"
        
        # Display quick access commands
        Write-Info ""
        Write-Info "Quick Access Commands:"
        Write-Info "kubectl port-forward -n $MonitoringNamespace svc/prometheus-stack-grafana 3000:80"
        Write-Info "kubectl port-forward -n $MonitoringNamespace svc/prometheus-stack-prometheus 9090:9090"
        if ($EnableJaeger) {
            Write-Info "kubectl port-forward -n $TracingNamespace svc/jaeger-query 16686:80"
        }
        
    }
    catch {
        Write-Error "Failed to generate monitoring summary: $($_.Exception.Message)"
    }
}

# Main execution
Write-Header "Enterprise Monitoring and Observability Setup"
Write-Info "Deploying comprehensive monitoring stack for AKS cluster..."

# Set defaults if switches not specified
if (-not $PSBoundParameters.ContainsKey('EnablePrometheus')) { $EnablePrometheus = $true }
if (-not $PSBoundParameters.ContainsKey('EnableGrafana')) { $EnableGrafana = $true }
if (-not $PSBoundParameters.ContainsKey('EnableJaeger')) { $EnableJaeger = $true }
if (-not $PSBoundParameters.ContainsKey('EnableFluentd')) { $EnableFluentd = $true }
if (-not $PSBoundParameters.ContainsKey('EnableAlertManager')) { $EnableAlertManager = $true }
if (-not $PSBoundParameters.ContainsKey('EnableVelero')) { $EnableVelero = $true }

# Validate prerequisites
Test-Prerequisites

# Create monitoring namespaces
New-MonitoringNamespaces

# Install monitoring components
Install-PrometheusStack
Install-Jaeger
Install-FluentdLogging
Install-Velero

# Configure custom dashboards and alerts
New-CustomDashboards
Set-MonitoringAlerts

# Generate summary report
New-MonitoringSummary

Write-Success "Enterprise monitoring and observability setup completed successfully!"
Write-Header "Monitoring Stack Summary"
Write-Info "✓ Prometheus metrics collection"
Write-Info "✓ Grafana dashboards and visualization"
Write-Info "✓ Jaeger distributed tracing"
Write-Info "✓ Fluentd centralized logging"
Write-Info "✓ Velero backup solution"
Write-Info "✓ Enterprise alerting rules"
Write-Info "✓ Custom dashboards for Camel K"
Write-Info ""
Write-Info "Next Steps:"
Write-Info "1. Run '.\scripts\04-install-quarkus-enterprise.ps1' for Quarkus setup"
Write-Info "2. Run '.\scripts\05-install-camelk-enterprise.ps1' for Camel K deployment"
Write-Info "3. Access monitoring tools using port-forward commands"
Write-Info "4. Review and customize alert notification channels"