# Deploying SEMOSS on AWS

The kubernetes cluster can be created using [eksctl](https://eksctl.io/), the console or other IaC tools. The instructions can be found on the [AWS User Guide](https://docs.aws.amazon.com/eks/latest/userguide/create-cluster.html).

After the Kubernetes cluster has been created, make note of the "OpenID Connect provider URL" value which will be used as an Identity provider.

## Granting the SEMOSS pod access to other AWS resources

As mentioned before, the [SEMOSS-deployment](../SEMOSS-deployment/semoss-deployment.yml) can use AWS specific environment variables that allow the SEMOSS pod to interact with AWS resources.
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

The IAM role needs to use an Identity provider that will allow the Kubernetes Service Account to assume it. Please verify that one already exist for the cluster by checking if a provider that matches the EKS cluster's "OpenID Connect provider URL" has already been created in the IAM console under the "identity providers" section.
If the Provider has not been created, click on "Add provider" to create it.

## Adding an Identity provider
On the Add Identity provider page select OpenID Connect as the provider type and under Provider name 

