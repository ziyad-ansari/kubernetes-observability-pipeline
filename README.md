# Kubernetes Observability Pipeline

Terraform-provisioned AWS EKS cluster running Vector and OpenObserve. Vector generates synthetic logs and metrics, sends them to OpenObserve, and the repository includes dashboard JSON exports for the assignment.

## Assignment Coverage

| Requirement | Implementation |
|---|---|
| Managed Kubernetes | AWS EKS 1.35 provisioned with Terraform |
| Synthetic logs | Vector `demo_logs` source with enriched JSON events |
| Synthetic metrics | Vector `log_to_metric` transform and Prometheus remote write |
| High-volume target | Tunable event interval and payload size; calibrate against OpenObserve ingestion |
| OpenObserve | Single-replica in-cluster deployment with persistent storage and external LoadBalancer |
| Dashboards | Logs and metrics dashboard JSON exports in `dashboards/` |

## Architecture

```text
Internet
   |
AWS LoadBalancer -> OpenObserve Service -> OpenObserve StatefulSet -> gp2 PVC
                                             ^
                                             |
EKS private nodes <- Vector Deployment -> OpenObserve cluster DNS
       ^
       |
Private EKS API endpoint
```

The VPC spans two Availability Zones. Workers run in private subnets and use a NAT Gateway for outbound access. Public subnets host the NAT Gateway and external load-balancer resources; the EKS API endpoint is private-only.

## Prerequisites

- AWS CLI v2 with credentials configured.
- Terraform >= 1.9.
- `kubectl` configured to reach the private EKS endpoint through VPN, bastion, Direct Connect, or another private VPC path.
- An IAM identity allowed to create the Terraform resources and assume the platform admin role.

## Deployment

### 1. Provision EKS

```bash
cd terraform
cp terraform.tfvars.example terraform.tfvars
```

Set the region, node instance type, and admin role name in `terraform.tfvars`. The admin role is created by Terraform and receives `AmazonEKSClusterAdminPolicy` through an EKS access entry.

Do not commit `terraform.tfvars`; it is ignored because it may contain environment-specific or sensitive values. Commit only `terraform.tfvars.example`.

```bash
terraform init
terraform fmt -check
terraform validate
terraform plan
terraform apply
```

Configure `kubectl` to use the created role:

```bash
aws eks update-kubeconfig \
  --region "$(terraform output -raw region)" \
  --name "$(terraform output -raw cluster_name)" \
  --role-arn "$(terraform output -raw platform_admin_role_arn)"

kubectl get nodes
```

### 2. Deploy OpenObserve

Create credentials locally. Do not commit the resulting Secret; it is ignored by Git.

```bash
cp ../openobserve/openobserve-secret.example.yaml ../openobserve/openobserve-secret.yaml
# Edit the email and long random password

kubectl apply -f ../openobserve/namespace.yaml
kubectl apply -f ../openobserve/openobserve-secret.yaml
kubectl apply -f ../openobserve/openobserve.yaml
kubectl -n openobserve rollout status statefulset/openobserve --timeout=10m
kubectl -n openobserve get service openobserve
```

OpenObserve is exposed through the AWS LoadBalancer on port `5080`. Retrieve its address with:

```bash
kubectl -n openobserve get service openobserve
```

### 3. Deploy Vector

Create the Vector Secret with the same OpenObserve credentials. Use the internal service endpoint:

```text
http://openobserve.openobserve.svc.cluster.local:5080
```

```bash
cd ../manifests
cp openobserve-secret.example.yaml openobserve-secret.yaml
# Edit the endpoint, organization, username, and password

kubectl apply -f namespace.yaml
kubectl apply -f openobserve-secret.yaml
kubectl apply -f vector-rbac.yaml
kubectl apply -f vector-configmap.yaml
kubectl apply -f vector-deployment.yaml

kubectl -n observability rollout status deployment/vector --timeout=10m
kubectl -n observability get pods -o wide
```

## Validate Ingestion

Check Vector for delivery errors:

```bash
kubectl -n observability logs deployment/vector --since=10m | \
  grep -Ei 'error|failed|retry|dropped' || true
```

In OpenObserve, select the `default` organization and use a recent time range. Verify:

- Log stream: `k8s_demo_logs`
- Metrics: `observability_demo_requests_total`
- Metrics: `observability_demo_status_code_total`
- Metrics: `observability_demo_cpu_usage_percent`
- Metrics: `observability_demo_memory_usage_bytes`
- Metrics: `observability_demo_request_duration_ms`
- Metrics: `observability_demo_queue_depth`

Import the dashboard exports from:

```text
dashboards/logs-dashboard.json
dashboards/metrics-dashboard.json
```

The logs dashboard covers volume, log-level distribution, and top services. The metrics dashboard covers request, CPU, memory, duration, queue, and ingestion-rate views.

## Throughput Tuning

The Vector deployment runs two replicas. Tune these environment variables in `manifests/vector-deployment.yaml`:

- `DEMO_INTERVAL_SECS`: generation interval per pod; lower values increase throughput.
- `DEMO_PAYLOAD`: synthetic payload added to each event; larger values increase bytes per event.

The assignment target is approximately 5 GB/hour of logs and 5 GB/hour of metrics. Actual volume depends on event encoding, compression, batching, and OpenObserve storage. Measure the ingested data in OpenObserve and adjust gradually.

## Security Design

- EKS API access is private-only.
- Workers run in private subnets.
- Kubernetes secrets are encrypted at rest by EKS KMS encryption.
- EKS control-plane audit and authentication logs are enabled.
- Cluster administration uses a dedicated Terraform-created IAM role and EKS access entry.
- Vector runs as non-root with a RuntimeDefault seccomp profile, dropped capabilities, a read-only root filesystem, and no service-account token.
- Vector has no Kubernetes RBAC permissions because it only generates and ships synthetic telemetry.
- OpenObserve credentials are stored in Kubernetes Secrets and excluded from Git.
- Local `terraform.tfvars` and generated Secret manifests are ignored; only example templates are committed.
- OpenObserve data uses a persistent `gp2` volume.

The public OpenObserve LoadBalancer is suitable for this assignment demonstration. For production, use an internal LoadBalancer behind VPN/private access and add network restrictions or authentication controls at the edge.

## Teardown

Remove the application resources first, then destroy AWS infrastructure:

```bash
kubectl delete -f ../manifests/vector-deployment.yaml
kubectl delete -f ../manifests/vector-configmap.yaml
kubectl delete -f ../manifests/vector-rbac.yaml
kubectl delete -f ../openobserve/openobserve.yaml
kubectl delete -f ../openobserve/openobserve-secret.yaml

cd ../terraform
terraform destroy
```

Capture dashboard and ingestion evidence before teardown. Confirm the OpenObserve PVC and AWS resources are deleted to avoid ongoing charges.

## Repository Layout

```text
terraform/       EKS, VPC, IAM, addons, and access management
manifests/       Vector deployment, configuration, RBAC, and Secret template
openobserve/     OpenObserve StatefulSet, LoadBalancer, storage, and Secret template
dashboards/       OpenObserve dashboard JSON exports
docs/             Technical notes and submission checklist
scripts/          Prerequisite and smoke-test scripts
```
