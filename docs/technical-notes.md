# Technical Notes

## Why the pipeline is designed this way

The assignment asks Vector to generate both logs and metrics and send them to OpenObserve. Vector provides a stable `demo_logs` source for synthetic log generation. Its `log_to_metric` transform converts log events into metric events, which lets the same high-rate generator feed both telemetry paths.

For logs, the implementation uses OpenObserve's JSON ingestion endpoint through Vector's HTTP sink. For metrics, it uses OpenObserve's Prometheus remote-write endpoint through Vector's native `prometheus_remote_write` sink.

## Volume model

The repository deliberately exposes the event interval and payload size rather than hard-coding a claim of exactly 5 GB/hour. Actual volume depends on serialized event size, compression, batching, and downstream acceptance. The intended workflow is to start with the included high-rate defaults, observe actual ingestion, and calibrate.

## Security model

- EKS API endpoint is private-only; administrative access requires connectivity to the VPC through a VPN, Direct Connect, bastion, or equivalent private path.
- Workers run only in private subnets.
- EKS Kubernetes secrets are encrypted at rest.
- EKS control-plane audit logs are enabled.
- Cluster administration uses a Terraform-created IAM role with a restricted trust policy and an EKS access entry instead of granting the Terraform caller cluster-admin permissions.
- Vector runs as non-root, drops Linux capabilities, uses a read-only root filesystem, and does not receive a Kubernetes API token.
- Vector has no Kubernetes RBAC permissions because this deployment only generates synthetic telemetry.
