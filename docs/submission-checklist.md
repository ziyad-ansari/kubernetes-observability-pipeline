# Submission Checklist

## Required deliverables

- [x] Terraform code for managed Kubernetes cluster
- [x] Kubernetes manifests for Vector
- [x] OpenObserve dashboard JSON exports
- [x] README with deployment instructions
- [x] README with design decisions

## Evidence to capture before submitting

1. `terraform apply` completes successfully.
2. `kubectl get nodes` shows the EKS workers Ready.
3. `kubectl -n observability get pods` shows Vector replicas Running.
4. Vector logs show no persistent OpenObserve authentication or connection errors.
5. OpenObserve shows the `k8s_demo_logs` stream receiving data.
6. OpenObserve shows the synthetic metric names receiving data.
7. Logs dashboard panels show volume, levels and services.
8. Metrics dashboard panels show CPU, memory, request and ingestion-rate views.
9. Export the final dashboard JSON from the OpenObserve UI once the panels are confirmed; replace the repository JSON files with those tenant-validated exports if the UI adds tenant-specific metadata.
10. Run `terraform destroy` after evidence capture.
