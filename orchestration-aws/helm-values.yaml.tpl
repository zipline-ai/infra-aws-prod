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

# Ingress configuration
ingress:
  ui:
    className: nginx-ui
%{ if ui_domain != "" }
    host: "${ui_domain}"
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
