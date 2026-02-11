# Deploying SEMOSS on AWS EKS

The kubernetes cluster can be created using the AWS console or IaC tools like [eksctl](https://eksctl.io/). The instructions can be found on the [AWS User Guide](https://docs.aws.amazon.com/eks/latest/userguide/create-cluster.html).

After the Kubernetes cluster has been created, it will have an [OpenID Connect](https://openid.net/developers/how-connect-works/) (OIDC) issuer URL associated with it. To use AWS Identity and Access Management (IAM) roles for service accounts, an IAM OIDC provider must exist for your cluster’s OIDC issuer URL.

You can find instructions on how to create the OIDC provider in the following AWS guide https://docs.aws.amazon.com/eks/latest/userguide/enable-iam-roles-for-service-accounts.html#_create_oidc_provider_console


## Granting the SEMOSS pod access to other AWS resources

As mentioned before, the [SEMOSS-deployment](../semoss-deployment.yml) can use AWS specific environment variables that allow the SEMOSS pod to interact with AWS resources.
The pod launched by the SEMOSS deployment needs to be able to use a storage bucket that is created in S3.

The following environment variables allow the pod to interact with the S3 bucket:
```
        - name: SEMOSS_STORAGE_PROVIDER
          value: S3
        - name: RCLONE_S3_NO_CHECK_BUCKET
          value: "true"
        - name: S3_REGION
          value: REGION
        - name: S3_BUCKET
          value: S3_BUCKET_NAME 
        - name: S3_ACCESS_KEY
          value: ACCESS_KEY
        - name: S3_SECRET_KEY
          value: SECRET_KEY
```

The **SEMOSS_STORAGE_PROVIDER** key indicates the type of blob storage and the **RCLONE_S3_NO_CHECK_BUCKET** key tells SEMOSS to **not check** if a bucket was created already. We pass the bucket name as the value for the **S3_BUCKET** key.

For the pod to be able to write to the S3 bucket, it can make use of the **"S3_ACCESS_KEY"** and the **"S3_SECRET_KEY"** environment variables or it can use a Service Account thats linked to an IAM role.

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

Create the Service Account in the Kubernetes cluster and include the IAM Role's ARN as an `eks.amazonaws.com/role-arn` annotation.
```
apiVersion: v1
kind: ServiceAccount
metadata:
  name: SERVICE_ACCOUNT_NAME
  namespace: NAMESPACE
  annotations:
    eks.amazonaws.com/role-arn: arn:aws:iam::ACCOUNT:role/IAM_ROLE_NAME
```

Once the Service Account has been created it needs to be added to the [SEMOSS-deploy](../semoss-deployment.yml) yaml file as the value of the `serviceAccountName` property under the template's **spec** section.
```
...
  template:
    metadata:
      labels:
        app.kubernetes.io/instance: semoss
        app.kubernetes.io/name: semoss
    spec:
      serviceAccountName: SERVICE_ACCOUNT_NAME
      containers:
...
```

---
**← Back to [Main Guide](../README.md)**
