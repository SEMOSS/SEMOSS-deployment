# SEMOSS deployment

## Prerequisites

Before proceeding with any deployment, ensure you have:

- ✅ A running Kubernetes cluster (v1.24 or later)
- ✅ kubectl configured with cluster admin access
- ✅ Database and storage bucket configured (see above)
- ✅ Base application deployed (deployment guide)

**For HTTPS deployments, you'll also need:**

- ✅ A domain name (or willingness to use self-signed certificates for testing)
- ✅ Basic understanding of TLS/SSL certificates

## Create the semoss namespace

In the kubernetes cluster create a namespace called **semoss**.

```bash
kubectl create ns semoss
```

## Deploying the ZooKeeper service

SEMOSS requires an Apache ZooKeeper deployment. The pod can be deployed with the [ZooKeeper-deployment](./zookeeper-deployment.yml) YAML file.
Once the ZooKeeper pod is running, create the service with the [ZooKeeper-service](./zookeeper-service.yml) YAML file.

After deploying the ZooKeeper service, obtain the service's cluster IP, as this will be used as the **ZK_SERVER** environment variable for the SEMOSS pod.

## Configuring the SEMOSS deployment

The SEMOSS pods can be configured and deployed using the [SEMOSS-deployment](./semoss-deployment.yml) YAML manifest file.
Please note that the manifest has environment variables that depend on the cloud provider where the Kubernetes cluster is hosted. The following is an example of a Kubernetes deployment YAML file used in an AWS environment:
<details>
  <summary>SEMOSS deployment file:</summary>

```apiVersion: apps/v1
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
    spec:
      serviceAccountName: SERVICE_ACCOUNT_NAME
      containers:
      - args:
        - -c
        - git reset --hard; git pull; chmod 777 *; cd $TOMCAT_HOME/webapps/Monolith/WEB-INF/lib;
          rm $TOMCAT_HOME/webapps/Monolith/WEB-INF/lib/slf4j-log4j12-1.6.1.jar $TOMCAT_HOME/webapps/Monolith/WEB-INF/lib/logback-classic-1.2.10.jar
          $TOMCAT_HOME/webapps/Monolith/WEB-INF/lib/slf4j-nop-1.7.25.jar; runCS.sh
        command:
        - /bin/bash
        env:
        - name: CUSTOM_SECURITY_DRIVER
          value: org.postgresql.Driver
        - name: CUSTOM_SECURITY_RDBMS_TYPE
          value: POSTGRES
        - name: CUSTOM_SECURITY_USERNAME
          value: DATABASE_USER
        - name: CUSTOM_SECURITY_PASSWORD
          value: DATABASE_PASSWORD
        - name: CUSTOM_SECURITY_SCHEMA
          value: SECURITY_SCHEMA_NAME
        - name: CUSTOM_SECURITY_DATABASE
          value: SECURITY_DATABASE_NAME
        - name: CUSTOM_SECURITY_CONNECTION_URL
          value: jdbc:postgresql://DATABASE_URL:DATABASE_PORT/SECURITY_DATABASE_NAME?currentSchema=SECURITY_SCHEMA_NAME
        - name: CUSTOM_LM_DRIVER
          value: org.postgresql.Driver
        - name: CUSTOM_LM_RDBMS_TYPE
          value: POSTGRES
        - name: CUSTOM_LM_USERNAME
          value: DATABASE_USER
        - name: CUSTOM_LM_PASSWORD
          value: DATABASE_PASSWORD
        - name: CUSTOM_LM_SCHEMA
          value: LOCALMASTER_SCHEMA_NAME
        - name: CUSTOM_LM_DATABASE
          value: LOCALMASTER_DATABASE_NAME
        - name: CUSTOM_LM_CONNECTION_URL
          value: jdbc:postgresql://DATABASE_URL:DATABASE_PORT/LOCALMASTER_DATABASE_NAME?currentSchema=CUSTOM_LM_SCHEMA
        - name: CUSTOM_SCHEDULER_DRIVER
          value: org.postgresql.Driver
        - name: CUSTOM_SCHEDULER_RDBMS_TYPE
          value: POSTGRES
        - name: CUSTOM_SCHEDULER_USERNAME
          value: DATABASE_USER
        - name: CUSTOM_SCHEDULER_PASSWORD
          value: DATABASE_PASSWORD
        - name: CUSTOM_SCHEDULER_SCHEMA
          value: SCHEDULER_SCHEMA_NAME
        - name: CUSTOM_SCHEDULER_DATABASE
          value: SCHEDULER_DATABASE_NAME
        - name: CUSTOM_SCHEDULER_CONNECTION_URL
          value: jdbc:postgresql://DATABASE_URL:DATABASE_PORT/SCHEDULER_DATABASE_NAME?currentSchema=CUSTOM_SCHEDULER_SCHEMA
        - name: CUSTOM_THEMES_DRIVER
          value: org.postgresql.Driver
        - name: CUSTOM_THEMES_RDBMS_TYPE
          value: POSTGRES
        - name: CUSTOM_THEMES_USERNAME
          value: DATABASE_USER
        - name: CUSTOM_THEMES_PASSWORD
          value: DATABASE_PASSWORD
        - name: CUSTOM_THEMES_SCHEMA
          value: THEMES_SCHEMA_NAME
        - name: CUSTOM_THEMES_DATABASE
          value: THEMES_DATABASE_NAME
        - name: CUSTOM_THEMES_CONNECTION_URL
          value: jdbc:postgresql://DATABASE_URL:DATABASE_PORT/THEMES_DATABASE_NAME?currentSchema=THEMES_SCHEMA_NAME
        - name: CUSTOM_USER_TRACKING_DRIVER
          value: org.postgresql.Driver
        - name: CUSTOM_USER_TRACKING_RDBMS_TYPE
          value: POSTGRES
        - name: CUSTOM_USER_TRACKING_USERNAME
          value: DATABASE_USER
        - name: CUSTOM_USER_TRACKING_PASSWORD
          value: DATABASE_PASSWORD
        - name: CUSTOM_USER_TRACKING_SCHEMA
          value: USER_TRACKING_SCHEMA_NAME
        - name: CUSTOM_USER_TRACKING_DATABASE
          value: USER_TRACKING_DATABASE_NAME
        - name: CUSTOM_USER_TRACKING_CONNECTION_URL
          value: jdbc:postgresql://DATABASE_URL:DATABASE_PORT/USER_TRACKING_DATABASE_NAME?currentSchema=USER_TRACKING_SCHEMA_NAME
        - name: USER_TRACKING_ENABLED
          value: "true"
        - name: CUSTOM_MODEL_INFERENCE_LOGS_DRIVER
          value: org.postgresql.Driver
        - name: CUSTOM_MODEL_INFERENCE_LOGS_RDBMS_TYPE
          value: POSTGRES
        - name: CUSTOM_MODEL_INFERENCE_LOGS_USERNAME
          value: DATABASE_USER
        - name: CUSTOM_MODEL_INFERENCE_LOGS_PASSWORD
          value: DATABASE_PASSWORD
        - name: CUSTOM_MODEL_INFERENCE_LOGS_SCHEMA
          value: MODEL_LOGS_SCHEMA_NAME
        - name: CUSTOM_MODEL_INFERENCE_LOGS_DATABASE
          value: MODEL_LOGS_DATABASE_NAME
        - name: CUSTOM_MODEL_INFERENCE_LOGS_CONNECTION_URL
          value: jdbc:postgresql://DATABASE_URL:DATABASE_PORT/MODEL_LOGS_DATABASE_NAME?currentSchema=MODEL_LOGS_SCHEMA_NAME
        - name: MODEL_INFERENCE_LOGS_ENABLED
          value: "true"
        - name: CUSTOM_PROMPT_DRIVER
          value: org.postgresql.Driver
        - name: CUSTOM_PROMPT_RDBMS_TYPE
          value: POSTGRES
        - name: CUSTOM_PROMPT_USERNAME
          value: DATABASE_USER
        - name: CUSTOM_PROMPT_PASSWORD
          value: DATABASE_PASSWORD
        - name: CUSTOM_PROMPTS_SCHEMA
          value: PROMPT_HUB_SCHEMA_NAME
        - name: CUSTOM_PROMPT_DATABASE
          value: PROMPT_HUB_DATABASE_NAME
        - name: CUSTOM_PROMPT_CONNECTION_URL
          value: jdbc:postgresql://DATABASE_URL:DATABASE_PORT/PROMPT_HUB_DATABASE_NAME?currentSchema=PROMPT_HUB_SCHEMA_NAME
        - name: PROMPT_DB_ENABLED
          value: "true"
        - name: SECURITY_ON
          value: "true"
        - name: SETSOCIAL
          value: "true"
        - name: ENABLE_NATIVE
          value: "true"
        - name: ENABLE_NATIVE_REGISTRATION
          value: "true"
        - name: ENABLE_NATIVE_ACCESS_KEY_ALLOWED
          value: "true"
        - name: ENABLE_API_USER
          value: "true"
        - name: API_USER_DYNAMIC
          value: "false"
        - name: REDIRECT
          value: https://INGRESS_DNS/SemossWeb/packages/client/dist/
        - name: R_ON
          value: "false"
        - name: R_CONNECTION_TYPE
          value: JRI
        - name: R_HOME
          value: /tmp
        - name: USE_TCP_PY
          value: "false"
        - name: USE_PY_FILE
          value: "false"
        - name: USE_FILE_PY
          value: "false"
        - name: NATIVE_PY_SERVER
          value: "true"
        - name: SMSS_PYTHONHOME
          value: /usr/lib/python/semossvenv
        - name: FILE_TRANSFER_LIMIT
          value: "500"
        - name: FILE_UPLOAD_LIMIT
          value: "500"
        - name: TCP_WORKER
          value: prerna.tcp.SocketServer
        - name: TCP_CLIENT
          value: prerna.tcp.client.NativePySocketClient
        - name: NETTY_R
          value: "true"
        - name: NETTY_PYTHON
          value: "true"
        - name: MONOLITH_COOKIE
          value: semoss-eks
        - name: SEMOSS_IS_CLUSTER
          value: "true"
        - name: SCHEDULER_ENDPOINT
          value: http://localhost:8080/Monolith
        - name: SEMOSS_STORAGE_PROVIDER
          value: S3
        - name: S3_REGION
          value: REGION
        - name: S3_BUCKET
          value: BUCKET_NAME 
        - name: SESSION_TIMEOUT
          value: "15"
        - name: OPTIONAL_COOKIES
          value: "false"
        - name: ZK_SERVER
          value: ZK_CLUSTER_IP
        - name: SEMOSS_IS_CLUSTER_ZK
          value: "true"
        - name: T_ON
          value: "false"
        - name: CHROOT_ENABLE
          value: "true"
        - name: CHROOT_DIR
          value: /opt
        - name: CHROOT_SYMLINK_PATHS
          value: /usr/lib/python
        - name: FAKECHROOT_EXCLUDE_PATH
          value: /dev
        - name: ERROR_REPORT_VALVE_ENABLED
          value: "true"
        - name: POD_IP
          valueFrom:
            fieldRef:
              apiVersion: v1
              fieldPath: status.podIP
        image: SEMOSS_IMAGE:SEMOSS_IMAGE_TAG
        imagePullPolicy: Always
        livenessProbe:
          failureThreshold: 3
          httpGet:
            path: /Monolith/api/config
            port: 8080
            scheme: HTTP
          initialDelaySeconds: 45
          periodSeconds: 10
          successThreshold: 1 #needs to be 1
          timeoutSeconds: 10
        name: semoss
        ports:
        - containerPort: 8080
          protocol: TCP
        readinessProbe:
          failureThreshold: 3
          httpGet:
            path: /Monolith/api/config
            port: 8080
            scheme: HTTP
          initialDelaySeconds: 45
          periodSeconds: 10
          successThreshold: 2
          timeoutSeconds: 10
        resources:
          limits:
            cpu: "8"
            memory: 30Gi
          requests:
            cpu: "6"
            memory: 24Gi
        securityContext:
          capabilities:
            drop:
            - NET_RAW
        terminationMessagePath: /dev/termination-log
        terminationMessagePolicy: File
      dnsPolicy: ClusterFirst
      restartPolicy: Always
      schedulerName: default-scheduler
      securityContext:
        fsGroup: 0
        runAsUser: 1001
        seccompProfile:
          type: RuntimeDefault
      terminationGracePeriodSeconds: 30
```

</details>

To configure the SEMOSS container to use the database, storage, and ZooKeeper, update the following environment variables in the SEMOSS deployment YAML file:

| Environment Variable | Default value | New value |
|:-------------------------|:-------|:--------|
| **CUSTOM_(Table name)_USERNAME**| *DATABASE_USER* | Replace DATABASE_USER with the user name created for the Database |
| **CUSTOM_(Table name)_PASSWORD**| *DATABASE_PASSWORD* | Replace DATABASE_PASSWORD with the password created for the Database|
| **CUSTOM_(Table name)_SCHEMA**| *(table name)_SCHEMA_NAME* | Replace (table name)_SCHEMA_NAME with the Schema created for the Database|
| **CUSTOM_(Table name)_DATABASE**| *(Table name)_DATABASE_NAME* | Replace (Table name)_DATABASE_NAME with the name created for the Database|
| **CUSTOM_(Table name)_CONNECTION_URL** | *jdbc:postgresql://DATABASE_URL:DATABASE_PORT/DATABASE_NAME?currentSchema=SCHEMA_NAME* | Replace DATABASE_URL with the Database's endpoint, DATABASE_PORT with the Database's port, DATABASE_NAME and the SCHEMA_NAME |
| **REDIRECT**| *https://INGRESS_DNS/SemossWeb/packages/client/dist/* | Replace INGRESS_DNS for the redirect url|
| **ZK_SERVER** | *ZK_CLUSTER_IP* | Replace ZK_CLUSTER_IP with the ZooKeeper service's cluster IP  |
| **image** | *SEMOSS_IMAGE:SEMOSS_IMAGE_TAG* | Replace SEMOSS_IMAGE:SEMOSS_IMAGE_TAG with the image of SEMOSS to be deployed  |

The storage bucket information also needs to be added and the environment variables depend on the cloud provider. The pod can also be granted access to other cloud resources using service accounts. Please see the [AWS SEMOSS deployment](../docs/aws_semoss-deployment.md) guide for information on AWS based deployments for more information.
  
After updating the environment variables, deploy the SEMOSS pod using the deployment YAML file. Once the pods are running, expose the SEMOSS pods by creating a service object with the [SEMOSS-service](./semoss-service.yml) yaml file.

> **Note:** The Kubernetes Service of type **ClusterIP** has the following limitations:
>
> - Only accessible within the cluster
> - No external connectivity
> - Suitable for internal microservices communication only

Once the SEMOSS service has been created, you can expose the service using an Ingress or Gateway implemetation.

**Already know which tool you will use to expose the SEMOSS service?** → Jump directly to:

- [Ingress-NGINX guide](../ingress-nginx/README.md)
- [Envoy Gateway guide](../envoy-gateway/README.md)
- [Istio Gateway guide](../istio-gateway/README.md)

**Want to compare options first?** → Read the [comparison matrix](../docs/gateway-comparison-information.md)

<!-- 
To uninstall the gateway api 
$ kubectl get crd gateways.gateway.networking.k8s.io &> /dev/null || \
  { kubectl kustomize "github.com/kubernetes-sigs/gateway-api/config/crd?ref=v1.4.1" | kubectl delete -f -; } -->

---
**← Back to [Main Guide](../README.md)**  
