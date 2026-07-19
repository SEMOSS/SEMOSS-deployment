#!/usr/bin/env bash
#
# Staged, dependency-gated deploy for SEMOSS.
#
# Unlike `kubectl apply -k .` (which creates objects in order but does not wait),
# this script blocks on each dependency becoming Ready before deploying the next
# stage, so the coordination backend is actually running before SEMOSS starts.
#
# Usage:
#   ./deploy.sh                            # Redis + Sentinel backend (default)
#   CLUSTER_BACKEND=zookeeper ./deploy.sh  # ZooKeeper ensemble instead
#   TIMEOUT=300s ./deploy.sh               # override per-stage readiness timeout
#
set -euo pipefail

NS="semoss"
TIMEOUT="${TIMEOUT:-180s}"
CLUSTER_BACKEND="${CLUSTER_BACKEND:-redis}"   # redis | zookeeper

cd "$(dirname "$0")"

apply()        { echo "==> apply: $*"; kubectl apply -f "$@"; }
wait_rollout() { echo "==> wait:  $1 (timeout ${TIMEOUT})"; kubectl rollout status "$1" -n "$NS" --timeout="$TIMEOUT"; }

# 1. Namespace
apply namespace.yml

# 2. Config + secrets — must exist before any pod that envFrom's them
apply semoss-config-and-secrets.yml

# 3. Cluster coordination backend — deploy and wait until Ready
case "$CLUSTER_BACKEND" in
  redis)
    apply redis-headless-service.yml
    apply redis-config-configmap.yml
    apply redis-statefulset.yml
    wait_rollout statefulset/redis
    apply sentinel-config-configmap.yml
    apply redis-sentinel-service.yml
    apply sentinel-statefulset.yml
    wait_rollout statefulset/redis-sentinel
    ;;
  zookeeper)
    apply zookeeper-headless-service.yml
    apply zookeeper-service.yml
    apply zookeeper-statefulset.yml
    wait_rollout statefulset/zookeeper
    ;;
  *)
    echo "ERROR: unknown CLUSTER_BACKEND '$CLUSTER_BACKEND' (expected 'redis' or 'zookeeper')" >&2
    exit 1
    ;;
esac

# 4. SEMOSS application — its dependencies are Ready at this point
apply semoss-deployment.yml
apply semoss-service.yml
wait_rollout deployment/semoss-deployment

# 5. Ingress — last, routes to the now-running service
apply semoss-ingress.yml

echo "==> Done. SEMOSS deployed to namespace '$NS' using the '$CLUSTER_BACKEND' backend."
