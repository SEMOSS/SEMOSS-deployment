# Ingress service

> **⚠️ Ingress NGINX Retirement**
>
>What You Need to Know about [Ingress NGINX Retirement](https://github.com/kubernetes/ingress-nginx#ingress-nginx-retirement):
>
>- Best-effort maintenance will continue until March 2026.
>- Afterward, there will be no further releases, no bugfixes, and no updates to resolve any security vulnerabilities that may be discovered.
>- Existing deployments of Ingress NGINX will not be broken.
>- Existing project artifacts such as Helm charts and container images will remain available.

> **Quick Navigation:** [Ingress service](#ingress-service) | [Creating the Ingress service](#creating-the-Ingress-service) | [HTTP ingress-nginx](#hTTP-ingress-nginx) | [HTTPS ingress-nginx](#hTTPS-ingress-nginx) | [Additional information](#additional-information)

We use a load balancer to expose the SEMOSS application, and a way to control the load balancer creation in a cloud environment is by using [Ingress Controllers](https://kubernetes.io/docs/concepts/services-networking/ingress-controllers/). The [Ingress-NGINX](https://github.com/kubernetes/ingress-nginx) Ingress controller is recommended to externally expose the SEMOSS service.

The Ingress-Nginx can launch a load balancer and manage it using [annotations](https://kubernetes.github.io/ingress-nginx/user-guide/nginx-configuration/annotations/). The instructions on how to deploy the Ingress controller in the cloud environment can be found in the project's [guide](https://kubernetes.github.io/ingress-nginx/deploy/) page.

## Creating the Ingress service

Use the SEMOSS-ingress YAML file (either for [HTTP](./http-deployment/manifests/semoss-ingress.yml) or [HTTPS](./https-deployment/manifests/semoss-ingress.yml)) to create the ingress resource and define the rules for routing traffic to the backend SEMOSS service.

## HTTP ingress-nginx

If you are testing the HTTP traffic, you can apply the http [semoss-ingress](./http-deployment/manifests/semoss-ingress.yml) yaml file.

⚠️ If you deployed the ingress resource with the HTTP manifest and are ready to move to a the HTTPS manifest you can follow the next steps to have the object updated without having to destroy and create a new Load Balancer.

## HTTPS ingress-nginx

The ingress-nginx resource can be configured to have externally-reachable URLs and terminate SSL / TLS. Please see the Kubernetes [documentation](https://kubernetes.io/docs/concepts/services-networking/ingress/) for more information.

Please see the below instructions on how to create a TLS certificate and update the [semoss-ingress](./https-deployment/manifests/semoss-ingress.yml) manifest.

<details>
  <summary>Example of the SEMOSS-ingress resource that uses SSL certificates:</summary>

Create a kubernetes TLS secret using your cert and keypair:

```bash
kubectl -n semoss create secret tls semoss-tls-secret --cert=path/to/tls.crt --key=path/to/tls.key    
```

If the certifificate includes the cert and the encrypted RSA key in the same file (the cert will show *-----BEGIN RSA PRIVATE KEY-----* and *Proc-Type: 4,ENCRYPTED*), obtain the key by running `openssl rsa -in encrypted.key -out tls.key`

After the secret has been created use the secret name and update the [Ingress resource manifest](./https-deployment/manifests/semoss-ingress.yml):

```yaml
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
      - demo.semoss.org # Change this value to match your URL
    secretName: semoss-tls-secret
  rules:
    - host: demo.semoss.org # Change this value to match your URL
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

After the ingress resource has been created get the Load balancer's Address.

```bash
kubectl -n semoss get ingress -o wide
```

Take note of the `ADDRESS` value:

```bash
NAME             CLASS    HOSTS             ADDRESS                      PORTS   AGE
semoss-ingress   <none>   demo.semoss.org   ID.elb.REGION.amazonaws.com   80      87d
```

The `ADDRESS` value will be used to replace the INGRESS_DNS placeholder mentioned in the **REDIRECT** key value of the [semoss-deployment](../SEMOSS-deployment/semoss-deployment.yml) yaml file.

## Additional information

The Ingress-NGINX controller can use annotations from a cloud provider's controller, such as the [AWS Load Balancer Controller](https://github.com/kubernetes-sigs/aws-load-balancer-controller). Please see the documentation for your cloud provider for more information and the Ingress-NGINX documentation for compatibility and usage information.

Additional information on deploying the ingress-nginx controller in AWS can be found in this [document](../docs/aws_semoss-deployment.md)

---
**← Back to [Main Guide](../README.md)**
