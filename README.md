# SEMOSS-deployment
## Kubernetes deployment guide

SEMOSS can be deployed as a service running in a Kubernetes cluster on a cloud provider. The SEMOSS deployment requires the following infrastructure resources:

- Storage bucket.
- Database (PostgreSQL)
- Kubernetes cluster

The Following diagram details the Kubernetes and cloud provider resources that will be created.

<div align="center">
  <a href="kubernetes-deployment.png">
    <img alt="ollama" width="840" src="kubernetes-deployment.png">
  </a>
  </br>
</div>

Before deploying the SEMOSS container, ensure that the pod has access to both the storage bucket (e.g., S3, Azure Blob, Google Bucket) and the database. Once the necessary policies are in place, the pods and services can be deployed to the Kubernetes cluster.

The details of these cloud resources will be passed to the SEMOSS pods as environment variables declared in the deployment YAML file.

## Database configuration

If you are using a managed database service, the following databases or schemas need to be created.

Databases/Schemas that need to be created:

- security
- localmaster
- scheduler
- themes
- user_tracking
- model_logs
- prompt_hub

The names used for the schemas/databases can be changed to fit the project's naming standards.

If you are using a PostgreSQL database, you can use [psql](https://www.postgresql.org/docs/current/app-psql.html) to create the databases or schemas.
<details>
  <summary>psql installation:</summary>

- Install psql [Ubuntu](https://www.postgresql.org/download/linux/ubuntu/):
```
apt install postgresql
```
- Install psql [Amazon Linux 2023](https://docs.aws.amazon.com/AmazonRDS/latest/UserGuide/USER_ConnectToPostgreSQLInstance.html):
``` 
sudo dnf update -y
sudo dnf install postgresql -y
```

</details>

<details>
  <summary>psql example:</summary>

> **Note:** An AWS RDS is used in the following commands, please check your cloud provider for instructions on how to connect to the database.

1.- Connect to database.
```
psql -h mydb.xxxxxxx.us-east-1.rds.amazonaws.com -p 5432 -U myuser -d postgres
```
2.- Once connected, run the following commands inside the prompt.
```
CREATE DATABASE <DATABASE_NAME>;
```
3.- To confirm the databases have been created:
```
\l
```
4.- To exit from the database
```
\q
```

</details>


Once SEMOSS pods are launched, they will connect to the databases and initialize tables upon its first launch.

## Ingress service
We use a load balancer to expose the SEMOSS application, and a way to control the load balancer creation in a cloud environment is by using [Ingress Controllers](https://kubernetes.io/docs/concepts/services-networking/ingress-controllers/). The [Ingress-NGINX](https://github.com/kubernetes/ingress-nginx) Ingress controller is recommended to externally expose the SEMOSS service.

The Ingress-Nginx can launch a load balancer and manage it using [annotations](https://kubernetes.github.io/ingress-nginx/user-guide/nginx-configuration/annotations/). The instructions on how to deploy the Ingress controller in the cloud environment can be found in the project's [guide](https://kubernetes.github.io/ingress-nginx/deploy/) page.

> **Note:** The Ingress-NGINX controller can use annotations from a cloud provider's controller, such as the [AWS Load Balancer Controller](https://github.com/kubernetes-sigs/aws-load-balancer-controller). Please see the documentation for your cloud provider for more information and the Ingress-NGINX documentation for compatibility and usage information.

## Deploying the ZooKeeper service

In the kubernetes cluster create a namespace called **semoss**.

```kubectl create ns semoss```

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

The storage bucket information also needs to be added and the environment variables depend on the cloud provider. For more information about these environment variables, refer to the [AI Server Configuration Parameters]().
  
After updating the environment variables, deploy the SEMOSS pod using the deployment YAML file. Once the pods are running, expose the SEMOSS pods by creating a service object with the [SEMOSS-service](./semoss-service.yml) yaml file:

```apiVersion: v1
kind: Service
metadata:
  name: semoss-service
  namespace: semoss
spec:
  internalTrafficPolicy: Cluster
  ipFamilies:
  - IPv4
  ipFamilyPolicy: SingleStack
  ports:
  - port: 8080
    protocol: TCP
    targetPort: 8080
  selector:
    app.kubernetes.io/instance: semoss
    app.kubernetes.io/name: semoss
  sessionAffinity: None
  type: ClusterIP
```

## Creating the Ingress service


Use the [SEMOSS-ingress](./semoss-ingress.yml) YAML file to create the ingress resource and define the rules for routing traffic to the backend SEMOSS service.
> **Note:** The ingress resource can be configured to have externally-reachable URLs and terminate SSL / TLS. Please see the Kubernetes [documentation](https://kubernetes.io/docs/concepts/services-networking/ingress/) for more information.

<details>
  <summary>Example of the SEMOSS-ingress resource that uses SSL certificates:</summary>

Create a kubernetes TLS secret:

```
kubectl -n semoss create secret tls <testsecret-tls> --cert=path/to/tls.crt --key=path/to/tls.key    
```

If the certifificate includes the cert and the encrypted RSA key (the cert will show *-----BEGIN RSA PRIVATE KEY-----* and *Proc-Type: 4,ENCRYPTED*) in the same file, obtain the key by running `openssl rsa -in encrypted.key -out tls.key`

After the secret has been created use the secret name in the Ingress resource manifest:
```
apiVersion: networking.k8s.io/v1
kind: Ingress
metadata:
  name: semoss-ingress
  namespace: semoss
  annotations:
    kubernetes.io/ingress.class: nginx
    nginx.ingress.kubernetes.io/affinity: cookie
    nginx.ingress.kubernetes.io/force-ssl-redirect: "true"
    nginx.ingress.kubernetes.io/proxy-body-size: 500m
    nginx.ingress.kubernetes.io/proxy-read-timeout: "600"
    nginx.ingress.kubernetes.io/proxy-send-timeout: "600"
    nginx.ingress.kubernetes.io/session-cookie-expires: "172800"
    nginx.ingress.kubernetes.io/session-cookie-max-age: "172800"
    nginx.ingress.kubernetes.io/session-cookie-name: semoss-nginx-sticky
    nginx.ingress.kubernetes.io/session-cookie-path: /
    nginx.ingress.kubernetes.io/ssl-redirect: "true"
    nginx.org/client-max-body-size: 500m
spec:
  tls:
  - hosts:
      - demo.semoss.org # URL
    secretName: testsecret-tls
  rules:
    - host: demo.semoss.org # URL
      http:
        paths:
          - path: /
            pathType: ImplementationSpecific
            backend:
              service:
                name: semoss-service
                port:
                  number: 8080

  
```
</details>

<details>
  <summary> Example of the SEMOSS-ingress resource that is not using SSL certificates</summary>

```
apiVersion: networking.k8s.io/v1
kind: Ingress
metadata:
  annotations:
    nginx.ingress.kubernetes.io/affinity: cookie
    nginx.ingress.kubernetes.io/app-root: /SemossWeb
    nginx.ingress.kubernetes.io/force-ssl-redirect: "true"
    nginx.ingress.kubernetes.io/hsts: "true"
    nginx.ingress.kubernetes.io/hsts-include-subdomains: "true"
    nginx.ingress.kubernetes.io/hsts-max-age: "31536000"
    nginx.ingress.kubernetes.io/hsts-preload: "true"
    nginx.ingress.kubernetes.io/proxy-body-size: 500m
    nginx.ingress.kubernetes.io/proxy-cookie-path: ~*^/.* /
    nginx.ingress.kubernetes.io/proxy-read-timeout: "350"
    nginx.ingress.kubernetes.io/proxy-send-timeout: "350"
    nginx.ingress.kubernetes.io/session-cookie-expires: "172800"
    nginx.ingress.kubernetes.io/session-cookie-max-age: "172800"
    nginx.ingress.kubernetes.io/session-cookie-name: semoss-nginx-prod
    nginx.ingress.kubernetes.io/session-cookie-path: /
    nginx.ingress.kubernetes.io/session-cookie-secure: "true"
    nginx.ingress.kubernetes.io/ssl-redirect: "true"
    nginx.org/client-max-body-size: 500m
  name: semoss-ingress
  namespace: semoss
spec:
  ingressClassName: nginx
  rules:
  - http:
      paths:
      - backend:
          service:
            name: semoss-service
            port:
              number: 8080
        path: /
        pathType: ImplementationSpecific
```
</details>

After the ingress resource has been created get the Load balancer's Address.
```
$ kubectl -n semoss get ingress -o wide
NAME             CLASS    HOSTS             ADDRESS                      PORTS   AGE
semoss-ingress   <none>   demo.semoss.org   ID.elb.REGION.amazonaws.com   80      87d
```

The address value will be used to replace the INGRESS_DNS placeholder mentioned in the **REDIRECT** key value.

## Additional information
- [AWS](./docs/aws_semoss-deployment.md)
