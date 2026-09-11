# In-cluster OpenObserve

This deployment runs a single OpenObserve instance with persistent EBS-backed storage and exposes its UI/API through an AWS Network Load Balancer.

## Deploy

```bash
kubectl apply -f openobserve/namespace.yaml
kubectl apply -f openobserve/openobserve-secret.yaml
kubectl apply -f openobserve/openobserve.yaml
kubectl -n openobserve rollout status statefulset/openobserve --timeout=10m
kubectl -n openobserve get service openobserve
```

Create the ignored secret from the example and replace both values before applying:

```bash
cp openobserve/openobserve-secret.example.yaml openobserve/openobserve-secret.yaml
```

The public LoadBalancer is intended for assignment access. Restrict access at the AWS load-balancer/security boundary or use an internal LoadBalancer plus VPN for a production deployment.

Vector should use this internal endpoint:

```text
http://openobserve.openobserve.svc.cluster.local:5080
```
