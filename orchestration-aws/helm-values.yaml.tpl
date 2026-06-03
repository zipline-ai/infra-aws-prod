# ============================================================================
# Rendered by Terraform (orchestration-aws/helm.tf) from terraform.tfvars +
# module outputs. Mirrors the chart's infra/platform/compute layering — see
# charts/zipline-orchestration/values.yaml for the schema. Only emit values
# Terraform owns; chart defaults supply the rest.
# ============================================================================

# ---------------------------------------------------------------------------
# Terraform-owned: infrastructure bindings.
# ---------------------------------------------------------------------------
infra:
  global:
    customerName: "${customer_name}"
    artifactPrefix: "${artifact_prefix}"

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

  storage:
    warehouseBucket: "${warehouse_bucket}"

  database:
    host: "${db_host}"
    name: "${db_name}"

  iam:
    orchestrationIrsaArn: "${irsa_role_arn}"
    sparkComputeRoleArn: "${spark_compute_role_arn}"

  domains:
    ui: "${ui_domain}"
    hub: "${hub_domain}"
    fetcher: "${fetcher_domain}"
    eval: "${eval_domain}"

  prometheus:
    queryEndpoint: "${prometheus_query_endpoint}"
    namespace: "zipline-system"

# ---------------------------------------------------------------------------
# Helm-owned platform behavior. Terraform supplies version + ingress hosts +
# auth wiring; chart defaults provide images, replicas, resources.
# ---------------------------------------------------------------------------
platform:
  version: "${version}"
  deployFetcher: ${deploy_fetcher}

  imagePullSecrets:
    - name: "${image_pull_secret}"

  serviceAccount:
    create: true
    name: orchestration-sa

  orchestration:
    fetcher:
      replicas: ${fetcher_replicas}

  ingress:
    hub:
      externalUrl: "${hub_external_url}"

  auth:
    enabled: ${zipline_auth_enabled}
    url: "${zipline_auth_url}"
    secretsArn: "${auth_secrets_arn}"
    jwksUrl: "${zipline_auth_jwksUrl}"
    googleOauthClientId: "${google_oauth_client_id}"
    googleOauthClientSecret: "${google_oauth_client_secret}"
    githubOauthClientId: "${github_oauth_client_id}"
    githubOauthClientSecret: "${github_oauth_client_secret}"
    microsoftEntraTenantId: "${microsoft_entra_tenant_id}"
    microsoftEntraOauthClientId: "${microsoft_entra_oauth_client_id}"
    microsoftEntraOauthClientSecret: "${microsoft_entra_oauth_client_secret}"
    ssoProviderId: "${sso_provider_id}"
    ssoDomain: "${sso_domain}"
    ssoIssuer: "${sso_issuer}"
    ssoClientId: "${sso_client_id}"
    ssoClientSecret: "${sso_client_secret}"
    idpRoleMapping: "${idp_role_mapping}"
    idpGroupClaim: "${idp_group_claim}"

# ---------------------------------------------------------------------------
# Helm-owned, gated on spark_compute_enabled. Chart defaults provide team
# bootstrap config, sparkDefaults, history server, loki, etc.
# ---------------------------------------------------------------------------
compute:
  enabled: ${spark_compute_enabled}
  imagePrepull:
    enabled: ${spark_compute_enabled}

# ---------------------------------------------------------------------------
# Helm subcharts: must stay at root. TF injects ACM cert ARNs into the NLB
# annotations when present so TLS terminates at the load balancer.
# ---------------------------------------------------------------------------
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

ingress-nginx-fetcher:
  enabled: ${deploy_fetcher}
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
