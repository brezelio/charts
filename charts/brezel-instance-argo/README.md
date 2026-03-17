# Brezel Instance Helm Chart

A Helm chart for deploying a Brezel instance on Kubernetes. This chart is designed to be cloud-native, supporting S3 for file storage and horizontal scaling.

## Features

- **Cloud Native**: Uses S3 for file storage (`FILESYSTEM_DISK=s3`), keeping the application layer stateless.
- **Argo Rollouts**: Uses Argo Rollouts for advanced deployment strategies (Canary).
- **Bootstrap Job**: Runs Brezel/KAB initialization explicitly as a Kubernetes Job instead of hidden supervisor side effects.
- **Dedicated Workers**: Supports explicit worker Deployments for async processing instead of generating supervisor configs at runtime.
- **Integrated Services**: Optionally includes a MySQL database pod, PHPMyAdmin, and Brotcast (WebSocket server).
- **Configurable**: Highly configurable via `values.yaml`.

## Prerequisites

- Kubernetes 1.19+
- Helm 3.2.0+
- Argo Rollouts controller installed in the cluster
- Cert-Manager (for Ingress TLS)

## Installation

### Using ArgoCD

Create an `Application` resource pointing to this chart.

```yaml
apiVersion: argoproj.io/v1alpha1
kind: Application
metadata:
  name: my-brezel-instance
  namespace: argocd
spec:
  project: default
  source:
    path: modules/brezel-instance-argo
    repoURL: <your-repo-url>
    targetRevision: HEAD
    helm:
      values: |
        namespace: my-namespace
        api_hostnames:
          - api.example.com
        hostnames:
          - app.example.com
        # ... other values
  destination:
    server: https://kubernetes.default.svc
    namespace: my-namespace
```

### Manual Install

```bash
helm install my-brezel ./modules/brezel-instance-argo -n my-namespace --create-namespace -f my-values.yaml
```

## Configuration

The following table lists the configurable parameters of the Brezel chart and their default values.

| Parameter | Description | Default |
|-----------|-------------|---------|
| `namespace` | Target namespace for resources | `default` |
| `api_replicas` | Number of API replicas | `1` |
| `image` | Brezel API image | `""` |
| `spa_image` | Brezel SPA image | `""` |
| `brotcast_image` | Brotcast image | `""` |
| `global_gitlab_registry_data` | Docker config JSON for pulling images | `""` |
| `existing_secret_name` | Existing Kubernetes Secret to use instead of rendering `brezel-api` | `""` |
| `secure` | Enable HTTPS/TLS | `true` |
| `api_hostnames` | List of hostnames for the API | `[]` |
| `hostnames` | List of hostnames for the SPA | `[]` |
| `pma_hostname` | Hostname for PHPMyAdmin | `""` |
| `brotcast_hostname` | Hostname for Brotcast | `""` |
| `export_hostname` | Hostname for Export service | `""` |
| `app_key` | Laravel APP_KEY | `""` |
| `app_env` | Laravel APP_ENV | `production` |
| `env` | Non-secret environment variables for the main app ConfigMap | `{}` |
| `secret_env` | Secret environment variables for the main app Secret | `{}` |
| `system_envs` | Non-secret system-specific environment variables (nested map) | `{}` |
| `system_secret_envs` | Secret system-specific environment variables (nested map) | `{}` |
| `default_system` | Default system identifier used by the bootstrap job | `""` |
| `bootstrap.enabled` | Enable the bootstrap Job | `true` |
| `bootstrap.command` | Bootstrap command executed in the Job | see `values.yaml` |
| `workers` | List of worker Deployments with `name`, `replicas`, `command` | `[]` |
| `cronjob.enabled` | Enable the schedule CronJob | `true` |
| `cronjob.command` | Command executed by the scheduler CronJob | `"/usr/local/bin/php bakery schedule"` |
| `with_database_pod` | Deploy a MySQL pod within the release | `true` |
| `db_host` | External DB host (if `with_database_pod` is false) | `""` |
| `db_port` | External DB port | `3306` |
| `db_name` | Database name | `brezel` |
| `db_user` | Database user | `brezel` |
| `mysql_password` | Root password for internal DB or password for external DB | `""` |
| `s3_access_key` | AWS Access Key ID for S3 | `""` |
| `s3_secret_key` | AWS Secret Access Key for S3 | `""` |
| `s3_region` | AWS Region | `eu-central-1` |
| `s3_bucket` | S3 Bucket name | `""` |
| `s3_endpoint` | S3 Endpoint URL | `""` |
| `storage` | Size of ephemeral storage request | `10Gi` |
| `db_storage` | Deprecated; internal MySQL uses ephemeral storage when enabled | `10Gi` |

### S3 Configuration

To enable cloud-native mode, you **must** provide S3 credentials. The application is configured to use the `s3` disk driver by default.

```yaml
s3_access_key: "your-access-key"
s3_secret_key: "your-secret-key"
s3_region: "fr-par"
s3_bucket: "my-bucket"
s3_endpoint: "https://s3.fr-par.scw.cloud"
```

### Bootstrap And Workers

For KAB-style setups, bootstrap and async workers should be explicit Kubernetes resources.
The bootstrap commands run only in the dedicated Job, not in the API pods, so `init`, `migrate`, `system create`, `apply`, and `load` are no longer executed per replica.

```yaml
default_system: kab

bootstrap:
  enabled: true

workers:
  - name: workflows-default
    replicas: 2
    queues: ["default"]
    timeout: 1200
  - name: workflows-domain-checks
    replicas: 1
    queues: ["domain-checks"]
    timeout: 1200
  - name: workflows-newsletter
    replicas: 1
    queues: ["newsletter-tagging", "newsletter-emails", "newsletter-tag-sync"]
    timeout: 1200
  - name: broadcasts
    replicas: 2
    command: "php bakery work --timeout=1200"
  - name: import
    replicas: 1
    command: "php bakery work --timeout=1200"
```

If `command` is omitted, the chart builds `php bakery work` automatically from `queues`, `sleep`, `tries`, and `timeout`.

### Existing Secret

If runtime secrets are provisioned outside Helm, for example by Terraform, set `existing_secret_name`.

```yaml
existing_secret_name: kab-runtime
```

The chart will then reference that Secret instead of rendering its own `brezel-api` Secret.

### System Environments

You can inject system-specific environment variables using the `system_envs` map.

```yaml
system_envs:
  MySystem:
    API_KEY: "secret-value"
    VERIFY_URL: "https://..."
```

This will generate environment variables like `BREZEL_SYSTEM_MySystem_API_KEY`.

Use `system_secret_envs` for credentials and other sensitive values.
