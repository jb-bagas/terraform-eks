# Amazon Managed Prometheus Workspace
resource "aws_prometheus_workspace" "this" {
  count = var.enable_observability ? 1 : 0

  alias = "${var.cluster_name}-amp"
  tags  = var.tags
}

# Amazon Managed Grafana Workspace
resource "aws_grafana_workspace" "this" {
  count = var.enable_observability ? 1 : 0

  name                     = "${var.cluster_name}-amg"
  account_access_type      = "CURRENT_ACCOUNT"
  authentication_providers = ["AWS_SSO"]
  permission_type          = "SERVICE_MANAGED"
  role_arn                 = aws_iam_role.grafana[0].arn

  data_sources = ["PROMETHEUS", "CLOUDWATCH", "XRAY"]
  tags         = var.tags
}

resource "aws_iam_role" "grafana" {
  count = var.enable_observability ? 1 : 0
  name  = "${var.cluster_name}-grafana-role"

  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [{
      Action    = "sts:AssumeRole"
      Effect    = "Allow"
      Principal = { Service = "grafana.amazonaws.com" }
    }]
  })
  tags = var.tags
}

resource "aws_iam_role_policy_attachment" "grafana_prometheus" {
  count      = var.enable_observability ? 1 : 0
  role       = aws_iam_role.grafana[0].name
  policy_arn = "arn:aws:iam::aws:policy/AmazonPrometheusQueryAccess"
}

resource "aws_iam_role_policy_attachment" "grafana_cloudwatch" {
  count      = var.enable_observability ? 1 : 0
  role       = aws_iam_role.grafana[0].name
  policy_arn = "arn:aws:iam::aws:policy/CloudWatchReadOnlyAccess"
}

# ADOT Collector (DaemonSet with full production config)
resource "helm_release" "adot_collector" {
  count = var.enable_observability ? 1 : 0

  name       = "adot-collector"
  repository = "https://open-telemetry.github.io/opentelemetry-helm-charts"
  chart      = "opentelemetry-collector"
  version    = var.adot_collector_version
  namespace  = "adot-collector"

  create_namespace = true
  atomic           = true
  cleanup_on_fail  = true
  wait             = true

  values = [yamlencode({
    mode = "daemonset"

    image = {
      repository = "public.ecr.aws/aws-observability/aws-otel-collector"
    }

    # IRSA
    serviceAccount = {
      create = true
      name   = "adot-collector"
      annotations = {
        "eks.amazonaws.com/role-arn" = var.adot_collector_role_arn
      }
    }

    # Resource limits (crucial for DaemonSets to avoid node pressure)
    resources = {
      requests = { cpu = "100m", memory = "256Mi" }
      limits   = { cpu = "500m", memory = "1Gi" }
    }

    tolerations = local.system_tolerations

    # Full production-grade collector config
    config = {
      receivers = {
        otlp = {
          protocols = {
            grpc = { endpoint = "0.0.0.0:4317" }
            http = { endpoint = "0.0.0.0:4318" }
          }
        }
        prometheus = {
          config = {
            global = {
              scrape_interval     = "30s"
              scrape_timeout      = "10s"
              evaluation_interval = "30s"
            }
            scrape_configs = [
              {
                job_name              = "kubernetes-pods"
                kubernetes_sd_configs = [{ role = "pod" }]
                relabel_configs = [
                  {
                    source_labels = ["__meta_kubernetes_pod_annotation_prometheus_io_scrape"]
                    action        = "keep"
                    regex         = "true"
                  },
                  {
                    source_labels = ["__meta_kubernetes_pod_annotation_prometheus_io_path"]
                    action        = "replace"
                    target_label  = "__metrics_path__"
                    regex         = "(.+)"
                  },
                  {
                    source_labels = ["__address__", "__meta_kubernetes_pod_annotation_prometheus_io_port"]
                    action        = "replace"
                    regex         = "([^:]+)(?::\\d+)?;(\\d+)"
                    replacement   = "$1:$2"
                    target_label  = "__address__"
                  }
                ]
              },
              {
                job_name              = "kubernetes-nodes"
                kubernetes_sd_configs = [{ role = "node" }]
                scheme                = "https"
                tls_config            = { insecure_skip_verify = true }
                bearer_token_file     = "/var/run/secrets/kubernetes.io/serviceaccount/token"
              }
            ]
          }
        }
      }
      processors = {
        batch = {
          send_batch_size     = 8192
          timeout             = "10s"
          send_batch_max_size = 10000
        }
        memory_limiter = {
          check_interval         = "1s"
          limit_percentage       = 80
          spike_limit_percentage = 20
        }
        resourcedetection = {
          detectors = ["env", "eks", "ec2"]
          timeout   = "2s"
        }
      }
      exporters = {
        prometheusremotewrite = {
          endpoint                         = "http://${aws_prometheus_workspace.this[0].prometheus_endpoint}api/v1/remote_write"
          auth                             = { authenticator = "sigv4auth" }
          resource_to_telemetry_conversion = { enabled = true }
        }
        awsxray = { region = var.aws_region }
        debug   = { verbosity = "basic" }
      }
      extensions = {
        sigv4auth    = { region = var.aws_region }
        health_check = { endpoint = "0.0.0.0:13133" }
      }
      service = {
        extensions = ["sigv4auth", "health_check"]
        pipelines = {
          metrics = {
            receivers  = ["prometheus", "otlp"]
            processors = ["memory_limiter", "batch", "resourcedetection"]
            exporters  = ["prometheusremotewrite"]
          }
          traces = {
            receivers  = ["otlp"]
            processors = ["memory_limiter", "batch", "resourcedetection"]
            exporters  = ["awsxray"]
          }
        }
        telemetry = {
          logs = { level = "info" }
        }
      }
    }
  })]

  depends_on = [aws_prometheus_workspace.this]
}