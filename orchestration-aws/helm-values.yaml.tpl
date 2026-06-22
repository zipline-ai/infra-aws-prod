global:
  customer_name: "${customer_name}"
  artifact_prefix: "${artifact_prefix}"
  version: "${version}"
  deploy_fetcher: ${deploy_fetcher}

imagePullSecrets:
  - name: "${image_pull_secret}"

# AWS-specific configuration
aws:
  region: "${aws_region}"
  secretsArn: "${secrets_arn}"
  kvTablePrefix: "${kv_table_prefix}"
  kvEnableTtl: "${kv_enable_ttl}"
  kvReplicaRegions: "${kv_replica_regions}"
  eksClusterName: "${eks_cluster_name}"
  flinkEksServiceAccount: "${flink_eks_service_account}"
  flinkEksNamespace: "${flink_eks_namespace}"
  databricksSpSecretArn: "${databricks_sp_secret_arn}"
  emrExecutionRoleArn: "${emr_serverless_execution_role_arn}"
  emrLogUri: "${emr_log_uri}"
  emrCloudWatchLogGroup: "${emr_cloudwatch_log_group}"

compute:
  enabled: ${in_cluster_compute_enabled}
  cloudProvider: aws
  defaultNamespace: "${spark_compute_namespace}"
  namespaces:
    - name: "${spark_compute_namespace}"
      team: default
  objectStore:
    bucket: "s3://${warehouse_bucket}"
    region: "${aws_region}"
  serviceAccount:
    annotations:
      eks.amazonaws.com/role-arn: "${spark_compute_role_arn}"
  sparkDefaults:
    image: "${spark_compute_image}"
    eventLogDir: "s3a://${warehouse_bucket}/spark-events"
  flinkDefaults:
%{ if flink_compute_image != "" }    image: "${flink_compute_image}"
%{ endif }    serviceAccount: "flink"
    serviceAccountAnnotations:
      eks.amazonaws.com/role-arn: "${flink_compute_role_arn}"
  historyServer:
    image: "${spark_history_server_image}"
  imagePrepull:
    enabled: ${in_cluster_compute_enabled}
    images:
      - "${spark_compute_image}"

spark-operator:
  spark:
    jobNamespaces: []
    jobNamespaceSelector: zipline.ai/namespace-type=compute
    serviceAccount:
      create: false
      name: spark-operator-spark
    rbac:
      create: false

# Database configuration
database:
  host: "${db_host}"
  name: "${db_name}"

polaris:
  realm: "${polaris_realm}"
  bootstrap:
    credentialsSecret:
      name: "${polaris_bootstrap_credentials_secret}"

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
    resources:
      requests:
        cpu: 50m
        memory: 128Mi
      limits:
        cpu: 200m
        memory: 256Mi
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
  enabled: ${use_zipline_custom_domain ? false : deploy_fetcher}
  fullnameOverride: nginx-fetcher
  controller:
    ingressClassResource:
      name: nginx-fetcher
      enabled: true
      default: false
      controllerValue: "k8s.io/ingress-nginx-fetcher"
    ingressClass: nginx-fetcher
    resources:
      requests:
        cpu: 50m
        memory: 128Mi
      limits:
        cpu: 200m
        memory: 256Mi
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
  enabled: ${use_zipline_custom_domain ? false : true}
  controller:
    ingressClassResource:
      name: nginx-eval
      enabled: true
      default: false
      controllerValue: "k8s.io/ingress-nginx-eval"
    ingressClass: nginx-eval
    resources:
      requests:
        cpu: 50m
        memory: 128Mi
      limits:
        cpu: 200m
        memory: 256Mi
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
  enabled: ${use_zipline_custom_domain ? false : true}
  controller:
    ingressClassResource:
      name: nginx-hub
      enabled: true
      default: false
      controllerValue: "k8s.io/ingress-nginx-hub"
    ingressClass: nginx-hub
    resources:
      requests:
        cpu: 50m
        memory: 128Mi
      limits:
        cpu: 200m
        memory: 256Mi
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
    replicas: ${fetcher_replicas}
    port: 9000
    resources:
      limits:
        cpu: "8"
        memory: "32Gi"
      requests:
        cpu: "8"
        memory: "32Gi"

# Ingress configuration
ingress:
  ui:
    className: ${ui_ingress_class}
%{ if ui_domain != "" }
    host: "${ui_domain}"
%{ endif }
    path: "${ui_path}"
    annotations: {}
  eval:
    className: ${eval_ingress_class}
%{ if eval_domain != "" }
    host: "${eval_domain}"
%{ endif }
    path: "${eval_path}"
    annotations:
%{ if eval_path != "/" }
      nginx.ingress.kubernetes.io/use-regex: "true"
      nginx.ingress.kubernetes.io/rewrite-target: "/$2"
%{ endif }
  hub:
    className: ${hub_ingress_class}
%{ if hub_domain != "" }
    host: "${hub_domain}"
%{ endif }
%{ if hub_external_url != "" }
    externalUrl: "${hub_external_url}"
%{ endif }
    path: "${hub_path}"
    annotations:
      nginx.ingress.kubernetes.io/health-check-path: "/ping"
      nginx.ingress.kubernetes.io/proxy-body-size: "20m"
%{ if hub_path != "/" }
      nginx.ingress.kubernetes.io/rewrite-target: "/$2"
%{ endif }
  fetcher:
    className: ${fetcher_ingress_class}
%{ if fetcher_domain != "" }
    host: "${fetcher_domain}"
%{ endif }
    path: "${fetcher_path}"
    annotations:
      nginx.ingress.kubernetes.io/health-check-path: "/ping"
%{ if fetcher_path != "/" }
      nginx.ingress.kubernetes.io/use-regex: "true"
      nginx.ingress.kubernetes.io/rewrite-target: "/$2"
%{ endif }

# Prometheus configuration
prometheus:
  queryEndpoint: "${prometheus_query_endpoint}"
  namespace: "zipline-system"

auth:
  enabled: ${zipline_auth_enabled}
  url: "${zipline_auth_url}"
  secrets_arn: "${auth_secrets_arn}"
  jwksUrl: "${zipline_auth_jwksUrl}"
  google_oauth_client_id: "${google_oauth_client_id}"
  github_oauth_client_id: "${github_oauth_client_id}"
  microsoft_entra_tenant_id: "${microsoft_entra_tenant_id}"
  microsoft_entra_oauth_client_id: "${microsoft_entra_oauth_client_id}"
  sso_provider_id: "${sso_provider_id}"
  sso_domain: "${sso_domain}"
  sso_issuer: "${sso_issuer}"
  sso_client_id: "${sso_client_id}"
  sso_use_saml: ${sso_use_saml}
  sso_saml_entry_point: "${sso_saml_entry_point}"
  sso_saml_issuer: "${sso_saml_issuer}"
  sso_saml_callback_url: "${sso_saml_callback_url}"
  idp_role_mapping: "${idp_role_mapping}"
  idp_group_claim: "${idp_group_claim}"
