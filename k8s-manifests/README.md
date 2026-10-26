# Example Kubernetes Manifests

These manifests demonstrate the platform patterns; they are not applied by Terraform. They assume the `addons` module is enabled with the AWS Load Balancer Controller, EBS CSI, and Secrets Store CSI driver.

## Before applying

1. Replace the `eks.amazonaws.com/role-arn` placeholder in `serviceaccount.yaml` with a real IRSA role for `system:serviceaccount:demo:demo-app`.
2. Create a Secrets Manager secret named `demo/app` in the configured region, or edit `secretproviderclass.yaml`.
3. Set `region` in `secretproviderclass.yaml` to the cluster region.
4. For HTTPS, add a certificate ARN and HTTPS listener annotations to `ingress.yaml`.

## Apply

```sh
kubectl apply -k k8s-manifests
kubectl get pods -n demo -w
kubectl get ingress -n demo
```

Get the ALB address:

```sh
kubectl get ingress demo-app -n demo \
  -o jsonpath='{.status.loadBalancer.ingress[0].hostname}{"\n"}'
```

## Observability

The Deployment carries `prometheus.io/scrape`, `prometheus.io/port`, and `prometheus.io/path` annotations. The ADOT Collector discovers these pods and remote-writes their metrics to Amazon Managed Prometheus. Add OTLP instrumentation to the application and send traces to `adot-collector.adot-collector.svc:4317`.

## Cleanup

```sh
kubectl delete -k k8s-manifests
```
