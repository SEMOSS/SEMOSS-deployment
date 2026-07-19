# Deploying SEMOSS on AWS EKS

The kubernetes cluster can be created using the AWS console or IaC tools like [eksctl](https://eksctl.io/). The instructions can be found on the [AWS User Guide](https://docs.aws.amazon.com/eks/latest/userguide/create-cluster.html).

After the Kubernetes cluster has been created, it will have an [OpenID Connect](https://openid.net/developers/how-connect-works/) (OIDC) issuer URL associated with it. To use AWS Identity and Access Management (IAM) roles for service accounts, an IAM OIDC provider must exist for your cluster’s OIDC issuer URL.

You can find instructions on how to create the OIDC provider in the following AWS guide https://docs.aws.amazon.com/eks/latest/userguide/enable-iam-roles-for-service-accounts.html#_create_oidc_provider_console


## Granting the SEMOSS pod access to other AWS resources

The SEMOSS pod's configuration — including its object-storage settings — lives in
[`semoss-config-and-secrets.yml`](../semoss-config-and-secrets.yml), which the
[SEMOSS-deployment](../semoss-deployment.yml) consumes via `envFrom`. Non-sensitive
values go in the `ConfigMap`; credentials go in the `Secret`. Set the following for
an S3 bucket:

In the `ConfigMap` (non-sensitive):
```yaml
  SEMOSS_STORAGE_PROVIDER: "S3"
  RCLONE_S3_NO_CHECK_BUCKET: "true"
  S3_REGION: "<REGION>"
  S3_BUCKET: "<S3_BUCKET_NAME>"
```

In the `Secret` (credentials — only when using static keys, see below):
```yaml
  S3_ACCESS_KEY: "<ACCESS_KEY>"
  S3_SECRET_KEY: "<SECRET_KEY>"
```

The **SEMOSS_STORAGE_PROVIDER** key selects the blob-storage backend (`S3` for AWS),
and **RCLONE_S3_NO_CHECK_BUCKET** tells SEMOSS **not** to check whether the bucket
already exists. **S3_BUCKET** is the bucket name.

> **Other storage providers.** S3 is the AWS option; SEMOSS also supports MinIO,
> Google Cloud Storage, and Azure Blob Storage. The full list of providers and
> their keys is documented in the [main README](../README.md#using-managed--saas-dependencies)
> and the commented sections of [`semoss-config-and-secrets.yml`](../semoss-config-and-secrets.yml).

For the pod to write to the S3 bucket it can either use the **`S3_ACCESS_KEY`** /
**`S3_SECRET_KEY`** credentials, or — recommended — a Service Account linked to an
IAM role (IRSA), which needs no stored keys.

### Using the **"S3_ACCESS_KEY"** and the **"S3_SECRET_KEY"** environment variables
To get a *Secret* and *Access* key, you will need to create a user with programmatic access in the IAM console. Please find more information in the [AWS guide](https://docs.aws.amazon.com/IAM/latest/UserGuide/security-creds-programmatic-access.html)

The *user* needs to be associated to a policy that allows it interact with the S3 bucket. The following example shows a policy that allows all access to a specific S3 bucket called *amzn-s3-demo-bucket*:
```
{
    "Version": "2012-10-17",
    "Statement": [
        {
            "Sid": "S3BucketAccess",
            "Effect": "Allow",
            "Action": [
                "s3:*"
            ],
            "Resource": [
                "arn:aws:s3:::amzn-s3-demo-bucket",
                "arn:aws:s3:::amzn-s3-demo-bucket/*"
            ]
        }
    ]
}
```

> **Note:** 
> It is important to include the `bucket_name/*` entry in the resource section so the pod will be able to create objects **inside** the bucket.

### Using kubernetes Service Accounts linked to an IAM role

We can also use [Service Accounts](https://kubernetes.io/docs/concepts/security/service-accounts/) that allow the pod access to the S3 bucket using an IAM role.

The IAM role needs to use the OIDC provider to allow the Service Account to assume it. Please verify that one already exist for the cluster by checking if an OIDC provider id matches the one mentioned in the EKS cluster's "OpenID Connect provider URL".

#### Create the IAM Role

The instructions to create a role for an AWS service using can be found in this [AWS guide](https://docs.aws.amazon.com/IAM/latest/UserGuide/id_roles_create_for-service.html#roles-creatingrole-service-console).

The role's trusted relationship entity needs to allow the OIDC provider the `sts:AssumeRoleWithWebIdentity` action to the Service account subject. The trust relationship will look similar to the following:
```
{
    "Version": "2012-10-17",
    "Statement": [
        {
            "Effect": "Allow",
            "Principal": {
                "Federated": "arn:aws:iam::ACCOUNT:oidc-provider/oidc.eks.REGION.amazonaws.com/id/OIDC_PROVIDER"
            },
            "Action": "sts:AssumeRoleWithWebIdentity",
            "Condition": {
                "StringEquals": {
                    "oidc.eks.us-east-1.amazonaws.com/id/OIDC_PROVIDER:sub": [
                        "system:serviceaccount:NAMESPACE:SERVICE_ACCOUNT_NAME"
                    ]
                }
            }
        }
    ]
}
```

The permission policy associated to the role needs to allow the needed S3 actions to the S3 bucket. The following example shows a policy that allows all access to a specific S3 bucket called *amzn-s3-demo-bucket*:
```
{
    "Version": "2012-10-17",
    "Statement": [
        {
            "Sid": "S3BucketAccess",
            "Effect": "Allow",
            "Action": [
                "s3:*"
            ],
            "Resource": [
                "arn:aws:s3:::amzn-s3-demo-bucket",
                "arn:aws:s3:::amzn-s3-demo-bucket/*"
            ]
        }
    ]
}
```
> **Note:** 
> It is important to include the `bucket_name/*` entry in the resource section so the pod will be able to create objects **inside** the bucket.

The role can allow other actions to other AWS resources. More examples can be found on the [EKS guide](https://docs.aws.amazon.com/eks/latest/userguide/associate-service-account-role.html).

#### Create the Kubernetes Service Account

The repo ships a ready-to-fill Service Account at [`serviceaccount.yml`](../serviceaccount.yml).
Set the IAM Role's ARN as the `eks.amazonaws.com/role-arn` annotation:
```yaml
apiVersion: v1
kind: ServiceAccount
metadata:
  name: semoss-pod-s3-service-account
  namespace: semoss
  annotations:
    eks.amazonaws.com/role-arn: arn:aws:iam::ACCOUNT:role/IAM_ROLE_NAME
```
Then apply it (`kubectl apply -f serviceaccount.yml`), or uncomment its line in
[`kustomization.yaml`](../kustomization.yaml).

Finally, run the pod as that Service Account: uncomment the `serviceAccountName`
line already scaffolded in [`semoss-deployment.yml`](../semoss-deployment.yml) under
the pod template's **spec** section.
```yaml
    spec:
      serviceAccountName: semoss-pod-s3-service-account
      containers:
      ...
```
When using IRSA you don't need `S3_ACCESS_KEY` / `S3_SECRET_KEY` in the `Secret` —
remove them so no static credentials are stored.

#### Other clouds (GCP / Azure)

The same keyless pattern applies on other providers — bind the SEMOSS
`ServiceAccount` to a cloud identity via its annotation, then set
`serviceAccountName` on the pod:

| Cloud | Mechanism | ServiceAccount annotation |
|:------|:----------|:--------------------------|
| AWS EKS | IRSA | `eks.amazonaws.com/role-arn: arn:aws:iam::<ACCOUNT_ID>:role/<ROLE>` |
| GCP GKE | Workload Identity | `iam.gke.io/gcp-service-account: <GSA>@<PROJECT>.iam.gserviceaccount.com` |
| Azure AKS | Workload Identity | `azure.workload.identity/client-id: <CLIENT_ID>` |

> Azure Workload Identity also requires the pod label
> `azure.workload.identity/use: "true"` on the deployment's pod template.