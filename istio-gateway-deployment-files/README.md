The Istio sidecar can be enabled at the namespace level with the **istio-injection=enabled** label or it can be done at the pod template level with the **sidecar.istio.io/inject: "true"** annotation.

Since we do not explicitly need the zookeper pod to have an Istio side car, we are adding the label to the deployment yaml:
```
apiVersion: apps/v1
kind: Deployment
metadata:
  labels:
    app.kubernetes.io/name: semoss
  name: semoss
  namespace: semoss
spec:
  replicas: 1
  selector:
    matchLabels:
      app.kubernetes.io/instance: semoss
      app.kubernetes.io/name: semoss
  strategy:
    type: Recreate
  template:
    metadata:
      labels:
        app.kubernetes.io/instance: semoss
        app.kubernetes.io/name: semoss
        sidecar.istio.io/inject: "true" # Enable Istio sidecar injection
```
For reference, the namespace can be created with:
```
apiVersion: v1
kind: Namespace
metadata:
  name: semoss
  labels:
    istio-injection: enabled
```

