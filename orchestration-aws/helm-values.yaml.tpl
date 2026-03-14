global:
  customer_name: "${customer_name}"
  artifact_prefix: "${artifact_prefix}"
  version: "${version}"

imagePullSecrets:
  - name: "${image_pull_secret}"

# AWS-specific configuration
aws:
  region: "${aws_region}"
  secretsArn: "${secrets_arn}"
  dynamodbTableName: "${dynamodb_table_name}"
  eksClusterName: "${eks_cluster_name}"
  flinkEksServiceAccount: "${flink_eks_service_account}"
  flinkEksNamespace: "${flink_eks_namespace}"
  databricksSpSecretArn: "${databricks_sp_secret_arn}"
  flinkEksServiceAccount: "${flink_eks_service_account}"
  flinkEksNamespace: "${flink_eks_namespace}"
  emrServerlessAppId: "${emr_serverless_app_id}"
  emrExecutionRoleArn: "${emr_serverless_execution_role_arn}"
  emrLogUri: "${emr_log_uri}"
  emrCloudWatchLogGroup: "${emr_cloudwatch_log_group}"

# Database configuration
database:
  host: "${db_host}"
  name: "${db_name}"

# Service account with IRSA
serviceAccount:
  create: true
  name: orchestration-sa
  annotations:
    eks.amazonaws.com/role-arn: "${irsa_role_arn}"

# Ingress NGINX Controller for UI
ingress-nginx-ui:
  enabled: true
  controller:
    ingressClassResource:
      name: nginx-ui
      enabled: true
      default: false
      controllerValue: "k8s.io/ingress-nginx-ui"
    ingressClass: nginx-ui
    service:
      annotations:
        service.beta.kubernetes.io/aws-load-balancer-type: "nlb"
        service.beta.kubernetes.io/aws-load-balancer-scheme: "internet-facing"
%{ if ui_cert_arn != "" }
        # TLS termination at NLB - decrypts HTTPS traffic here
        service.beta.kubernetes.io/aws-load-balancer-ssl-cert: "${ui_cert_arn}"
        service.beta.kubernetes.io/aws-load-balancer-ssl-ports: "443"
        # NLB sends plain HTTP to NGINX (TLS already terminated)
        service.beta.kubernetes.io/aws-load-balancer-backend-protocol: "tcp"
%{ endif }
      # When TLS terminates at NLB, forward port 443 to NGINX's HTTP handler
      targetPorts:
        https: http
    electionID: ingress-controller-leader-ui

# Ingress NGINX Controller for Fetcher
ingress-nginx-fetcher:
  enabled: true
  fullnameOverride: nginx-fetcher
  controller:
    ingressClassResource:
      name: nginx-fetcher
      enabled: true
      default: false
      controllerValue: "k8s.io/ingress-nginx-fetcher"
    ingressClass: nginx-fetcher
    service:
      annotations:
        service.beta.kubernetes.io/aws-load-balancer-type: "nlb"
        service.beta.kubernetes.io/aws-load-balancer-scheme: "internet-facing"
        service.beta.kubernetes.io/aws-load-balancer-healthcheck-path: "/ping"
%{ if fetcher_cert_arn != "" }
        # TLS termination at NLB - decrypts HTTPS traffic here
        service.beta.kubernetes.io/aws-load-balancer-ssl-cert: "${fetcher_cert_arn}"
        service.beta.kubernetes.io/aws-load-balancer-ssl-ports: "443"
        # NLB sends plain HTTP to NGINX (TLS already terminated)
        service.beta.kubernetes.io/aws-load-balancer-backend-protocol: "tcp"
%{ endif }
      # When TLS terminates at NLB, forward port 443 to NGINX's HTTP handler
      targetPorts:
        https: http
    electionID: ingress-controller-leader-fetcher

# Ingress NGINX Controller for Eval
ingress-nginx-eval:
  enabled: true
  controller:
    ingressClassResource:
      name: nginx-eval
      enabled: true
      default: false
      controllerValue: "k8s.io/ingress-nginx-eval"
    ingressClass: nginx-eval
    service:
      annotations:
        service.beta.kubernetes.io/aws-load-balancer-type: "nlb"
        service.beta.kubernetes.io/aws-load-balancer-scheme: "internet-facing"
        service.beta.kubernetes.io/aws-load-balancer-healthcheck-path: "/ping"
%{ if eval_cert_arn != "" }
        # TLS termination at NLB - decrypts HTTPS traffic here
        service.beta.kubernetes.io/aws-load-balancer-ssl-cert: "${eval_cert_arn}"
        service.beta.kubernetes.io/aws-load-balancer-ssl-ports: "443"
        # NLB sends plain HTTP to NGINX (TLS already terminated)
        service.beta.kubernetes.io/aws-load-balancer-backend-protocol: "tcp"
%{ endif }
      # When TLS terminates at NLB, forward port 443 to NGINX's HTTP handler
      targetPorts:
        https: http
    electionID: ingress-controller-leader-eval

# Ingress NGINX Controller for Hub
ingress-nginx-hub:
  enabled: true
  controller:
    ingressClassResource:
      name: nginx-hub
      enabled: true
      default: false
      controllerValue: "k8s.io/ingress-nginx-hub"
    ingressClass: nginx-hub
    service:
      annotations:
        service.beta.kubernetes.io/aws-load-balancer-type: "nlb"
        service.beta.kubernetes.io/aws-load-balancer-scheme: "internet-facing"
        service.beta.kubernetes.io/aws-load-balancer-healthcheck-path: "/ping"
%{ if hub_cert_arn != "" }
        # TLS termination at NLB - decrypts HTTPS traffic here
        service.beta.kubernetes.io/aws-load-balancer-ssl-cert: "${hub_cert_arn}"
        service.beta.kubernetes.io/aws-load-balancer-ssl-ports: "443"
        # NLB sends plain HTTP to NGINX (TLS already terminated)
        service.beta.kubernetes.io/aws-load-balancer-backend-protocol: "tcp"
%{ endif }
      # When TLS terminates at NLB, forward port 443 to NGINX's HTTP handler
      targetPorts:
        https: http
    electionID: ingress-controller-leader-hub

# Orchestration services configuration
orchestration:
  eval:
    image: "ziplineai/eval-aws"
    replicas: 1
    port: 3904
    resources:
      limits:
        cpu: "2"
        memory: "8Gi"
      requests:
        cpu: "500m"
        memory: "4Gi"

  hub:
    image: "ziplineai/hub-aws"
    replicas: 1
    port: 3903
    resources:
      limits:
        cpu: "6"
        memory: "28Gi"
      requests:
        cpu: "2"
        memory: "8Gi"

  ui:
    image: "ziplineai/web-ui"
    replicas: 1
    port: 3000
    resources:
      limits:
        cpu: "1000m"
        memory: "1Gi"
      requests:
        cpu: "250m"
        memory: "256Mi"

  fetcher:
    image: "ziplineai/chronon-fetcher"
    tag: "dev"
    replicas: 1
    port: 9000
    resources:
      limits:
        cpu: "4"
        memory: "8Gi"
      requests:
        cpu: "1"
        memory: "2Gi"

# Ingress configuration
ingress:
  ui:
    className: nginx-ui
%{ if ui_domain != "" }
    host: "${ui_domain}"
%{ endif }
    annotations: {}
  eval:
    className: nginx-eval
%{ if eval_domain != "" }
    host: "${eval_domain}"
%{ endif }
    annotations: {}
  hub:
    className: nginx-hub
%{ if hub_domain != "" }
    host: "${hub_domain}"
%{ endif }
    annotations:
      nginx.ingress.kubernetes.io/health-check-path: "/ping"
      nginx.ingress.kubernetes.io/proxy-body-size: "20m"
  fetcher:
    className: nginx-fetcher
%{ if fetcher_domain != "" }
    host: "${fetcher_domain}"
%{ endif }
    annotations:
      nginx.ingress.kubernetes.io/health-check-path: "/ping"

# Prometheus configuration
prometheus:
  queryEndpoint: "${prometheus_query_endpoint}"
  namespace: "zipline-system"
