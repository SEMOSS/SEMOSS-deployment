# Gateway files

To deploy a Gateway that only has an HTTP listener, please use the [semoss-http-gateway.yaml](../gateway/semoss-http-gateway.yaml) file. This will create a LoadBalancer that accepts HTTP traffic on port 80 by default.

In case you already have a certificate for your domain and will enable only HTTPS traffic, you can deploy a Gateway that redirects HTTP traffic to HTTPS with the [semoss-https-gateway.yaml](../gateway/semoss-https-gateway.yaml) file.
> **Note:** The certificate needs to be added as a [Kubernetes TLS secret](https://kubernetes.io/docs/reference/kubectl/generated/kubectl_create/kubectl_create_secret_tls/) so it can be used by the Istio Gateway pod to terminate TLS connections. The certificate can be a self-signed one.

Additionally, the Gateway resource may use different annotations depending on the cloud environment where the Kubernetes cluster was created.
For example, in AWS the resource can use annotations that make use of the [AWS Load Balancer Controller](https://docs.aws.amazon.com/eks/latest/userguide/aws-load-balancer-controller.html) to add the Security Groups to the loadbalancer.
```
apiVersion: gateway.networking.k8s.io/v1
kind: Gateway
metadata:
  name: semoss-gateway
  namespace: semoss
spec:
  infrastructure:
    annotations:
      service.beta.kubernetes.io/aws-load-balancer-type: "nlb"
      # creating an internal NLB
      service.beta.kubernetes.io/aws-load-balancer-internal: "false"
      # adding SG
      service.beta.kubernetes.io/aws-load-balancer-security-groups: "sg-xxxxx, sg-yyyy"
      # istio is the default gatewayclassName and requires Istio to be installed with Gateway API support
  gatewayClassName: istio
```