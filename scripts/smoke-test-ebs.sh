#!/usr/bin/env bash
#
# Disposable EBS CSI smoke test.
#
# Creates a temporary namespace, a 1 GiB gp3 PVC, and a pod that mounts it.
# Writes and reads data through the mounted volume, then deletes the namespace.
#
# Requirements:
#   - kubectl configured for the target cluster
#   - EBS CSI driver installed and a default (or STORAGE_CLASS) StorageClass
#
# Optional environment variables:
#   SMOKE_NAMESPACE   namespace name (default: ebs-smoke-<epoch>-<random>)
#   STORAGE_CLASS     StorageClass to use (default: gp3)
#   SMOKE_IMAGE       test pod image (default: public.ecr.aws/docker/library/busybox:1.36)
#   SMOKE_TIMEOUT     wait timeout in seconds (default: 300)
#   KEEP_SMOKE_TEST   set to 1 to leave the namespace for evidence/debugging
#
set -euo pipefail

NAMESPACE="${SMOKE_NAMESPACE:-ebs-smoke-$(date +%s)-${RANDOM}}"
PVC_NAME="ebs-smoke"
POD_NAME="ebs-smoke"
STORAGE_CLASS="${STORAGE_CLASS:-gp3}"
IMAGE="${SMOKE_IMAGE:-public.ecr.aws/docker/library/busybox:1.36}"
TIMEOUT="${SMOKE_TIMEOUT:-300}"
KEEP="${KEEP_SMOKE_TEST:-0}"
VALUE="ebs-smoke-$(date +%s)-${RANDOM}"
NAMESPACE_CREATED=0

die() {
  echo "ERROR: $*" >&2
  exit 1
}

cleanup() {
  if [[ "${NAMESPACE_CREATED}" != "1" ]]; then
    return 0
  fi

  if [[ "${KEEP}" == "1" ]]; then
    echo "KEEP_SMOKE_TEST=1: leaving namespace ${NAMESPACE} in place."
    echo "Delete it with: kubectl delete namespace ${NAMESPACE}"
    return 0
  fi

  echo "Cleaning up namespace ${NAMESPACE}..."
  # The namespace finalizer waits for the EBS volume to be deleted.
  kubectl delete namespace "${NAMESPACE}" --ignore-not-found --wait=true --timeout=180s >/dev/null 2>&1 || true
}

on_exit() {
  local status=$?
  trap - EXIT

  if [[ ${status} -ne 0 ]]; then
    echo "Smoke test failed; collecting diagnostics..." >&2
    kubectl -n "${NAMESPACE}" get pvc,pods -o wide 2>/dev/null || true
    kubectl -n "${NAMESPACE}" describe pvc "${PVC_NAME}" 2>/dev/null | tail -30 || true
    kubectl -n "${NAMESPACE}" describe pod "${POD_NAME}" 2>/dev/null | tail -40 || true
  fi

  cleanup
  exit "${status}"
}

trap on_exit EXIT

command -v kubectl >/dev/null 2>&1 || die "kubectl is not installed"
kubectl cluster-info >/dev/null 2>&1 || die "kubectl cannot reach a cluster; check the current context"
kubectl get storageclass "${STORAGE_CLASS}" >/dev/null 2>&1 || die "StorageClass '${STORAGE_CLASS}' not found"

echo "Creating namespace ${NAMESPACE}..."
kubectl create namespace "${NAMESPACE}" >/dev/null
NAMESPACE_CREATED=1

cat <<EOF | kubectl apply -f - >/dev/null
apiVersion: v1
kind: PersistentVolumeClaim
metadata:
  name: ${PVC_NAME}
  namespace: ${NAMESPACE}
spec:
  accessModes: [ReadWriteOnce]
  storageClassName: ${STORAGE_CLASS}
  resources:
    requests:
      storage: 1Gi
---
apiVersion: v1
kind: Pod
metadata:
  name: ${POD_NAME}
  namespace: ${NAMESPACE}
spec:
  restartPolicy: Never
  containers:
    - name: app
      image: ${IMAGE}
      command: ["sh", "-c", "sleep 3600"]
      volumeMounts:
        - name: data
          mountPath: /data
  volumes:
    - name: data
      persistentVolumeClaim:
        claimName: ${PVC_NAME}
EOF

echo "Waiting for PVC to bind..."
kubectl -n "${NAMESPACE}" wait --for=jsonpath='{.status.phase}'=Bound "pvc/${PVC_NAME}" --timeout="${TIMEOUT}s"

echo "Waiting for pod to become ready..."
kubectl -n "${NAMESPACE}" wait --for=condition=Ready "pod/${POD_NAME}" --timeout="${TIMEOUT}s"

echo "Writing and reading test data..."
kubectl -n "${NAMESPACE}" exec "${POD_NAME}" -- sh -c \
  "printf '%s' '${VALUE}' > /data/smoke.txt && test \"\$(cat /data/smoke.txt)\" = '${VALUE}'"

kubectl -n "${NAMESPACE}" get pvc "${PVC_NAME}" -o wide
kubectl -n "${NAMESPACE}" get pod "${POD_NAME}" -o wide

if [[ "${KEEP}" == "1" ]]; then
  echo "PASS: EBS PVC bound, mounted, and read/write verified."
  echo "Namespace ${NAMESPACE} was kept for evidence."
  cleanup
  trap - EXIT
  exit 0
fi

cleanup
trap - EXIT

if kubectl get namespace "${NAMESPACE}" >/dev/null 2>&1; then
  die "cleanup failed: namespace ${NAMESPACE} still exists"
fi

echo "PASS: EBS PVC bound, mounted, read/write verified, and cleaned up."
