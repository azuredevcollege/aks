# Azure Service Operator - manage your Azure resources with Kubernetes

Before I introduce you to [Azure Service Operator](https://github.com/Azure/azure-service-operator) and how it helps you to manage your Azure resources with Kubernetes let me briefly start with why you should use it and where it can help. Let me give you two examples:

Think of a common cloud-native application. Some microservices running on Kubernetes, using Redis for caching and a database to persist state. In such a scenario a common practice is to store and manage the application and its dependencies together. Until now you might have packed your microservices into a Helm chart for easier deployment and also created some Terraform code to deploy and manage the Redis and database. But those are still not linked together and are also deployed via two different continuous delivery pipelines. You could now argue that for example, the Terraform Helm provider could fix this issue by combining your application and infrastructure. But do you like your developers to learn and use another tool - mainly used for infrastructure management? Wouldn't it be better to just manage the application dependencies together with the application itself in a Helm chart? This is where Azure Service Operator can help!

Another example would be [GitOps](https://www.weave.works/technologies/gitops/). With GitOps, Git is the single source of truth. Applications and infrastructure are defined in a declarative manner, stored in Git, and automatically updated and managed by Kubernetes (to be more precise by [Kubernetes Controllers](https://kubernetes.io/docs/concepts/architecture/controller/)). With Azure Service Operator in combination with, for example, [FluxCD](https://fluxcd.io/) Kubernetes can also manage Azure resources using the GitOps approach.

## What Azure Service Operator is and how it works

So now that we know how the Azure Service Operator project can help us, we should talk about what it is exactly and how it works.

[Azure Service Operator](https://github.com/Azure/azure-service-operator) is an open-source project by the Microsoft Azure. It is a pretty new project that got [announced](https://cloudblogs.microsoft.com/opensource/2020/06/25/announcing-azure-service-operator-kubernetes/) last week. The whole project, as well as the roadmap, is available on [GitHub](https://github.com/Azure/azure-service-operator).

The Azure Service Operator consists of:
* Custom Resource Definitions (CRDs) for each of the Azure services. [CRDs](https://kubernetes.io/docs/concepts/extend-kubernetes/api-extension/custom-resources/) are Kubernetes API extensions. This enables us to create Kubernetes resources of kind *RedisCache* or *SQLServer*.
* A Kubernetes controller that watches for changes of the CRDs and then acting (creates, update, delete the Azure resources) on them.

Beside these Azure Service Operator also depends on:
* [Cert-manager](https://github.com/jetstack/cert-manager) to manage internal certificates. Cert-manager is a Kubernetes add-on to automate the management and issuance of TLS certificates from various issuing sources. Cert-manager is not part of the Azure Service Operator and needs to be installed upfront.
* [Azure AD (AAD) Pod Identity](Azure AD (AAD) Pod Identity) is used to manage authentication against Azure when managed identities are used. AAD Pod Identity is part of the Azure Service Operator and is provided as a Helm subchart.

With this abstraction, Azure Service Operator is not limited to be used with Azure Kubernetes Service, but can also be used with any Kubernetes cluster — regardless of whether it runs in a public or private cloud.

Further technical details on how Azure Service Operator works can be found [here](https://github.com/Azure/azure-service-operator/blob/master/docs/design/controlflow.md).

So far Azure Service Operator supports the following Azure resources:
* Resource Group
* Event Hubs
* Azure SQL
* Azure Database for PostgreSQL
* Azure Database for MySQL
* Azure Key Vault
* Azure Cache for Redis
* Storage Account
* Blob Storage
* Virtual Network
* Application Insights
* API Management
* Cosmos DB
* Virtual Machine
* Virtual Machine Scale Set

## Get started with Azure Service Operator

Below you will find all the steps necessary to get started with Azure Service Operator. A more detailed guide is available [here](https://github.com/Azure/azure-service-operator).

First of all, we need to install Cert-Manager:

``` bash
kubectl create namespace cert-manager
kubectl label namespace cert-manager cert-manager.io/disable-validation=true
helm repo add jetstack https://charts.jetstack.io
helm repo update
helm install \
  cert-manager jetstack/cert-manager \
  --namespace cert-manager \
  --set installCRDs=true
```

Before we can install the Azure Service Operator, we need to create a service principal that is used for authentication against Azure. We will then assign it contributor access on a subscription level (as mentioned above, it is also possible to use managed identities, which requires AAD Pod identity and AKS):

``` bash
NAME=aso-sp
AZURE_TENANT_ID=$(az account show --query '[tenantId]' -o tsv)
AZURE_SUBSCRIPTION_ID=$(az account show --query '[id]' -o tsv)
AZURE_CLIENT_SECRET=$(az ad sp create-for-rbac -n $NAME --role contributor --year 99 --query '[password]' -o tsv)
AZURE_CLIENT_ID=$(az ad sp list --display-name $NAME --query '[].appId' -o tsv)
```

Now we are ready to install Azure Service Operator using Helm:

``` bash
export HELM_EXPERIMENTAL_OCI=1
helm chart pull mcr.microsoft.com/k8s/asohelmchart:latest
helm chart export mcr.microsoft.com/k8s/asohelmchart:latest --destination .
helm install aso -n azureoperator-system --create-namespace \
  --set azureSubscriptionID=$AZURE_SUBSCRIPTION_ID \
  --set azureTenantID=$AZURE_TENANT_ID \
  --set azureClientID=$AZURE_CLIENT_ID \
  --set azureClientSecret=$AZURE_CLIENT_SECRET \
  --set createNamespace=true \
  --set image.repository="mcr.microsoft.com/k8s/azureserviceoperator:latest" \
  ./azure-service-operator
```

At this point we are ready to test our installation by creating a first resource group:

``` bash
cat <<EOF | kubectl apply -f -
apiVersion: azure.microsoft.com/v1alpha1
kind: ResourceGroup
metadata:
  name: aso-test-rg
spec:
  location: "westeurope"
EOF
```

The output of `kubectl get resourcegroups aso-test-rg` will give us details about the status of resource creation. Once we see *successfully provisioned* the resource is available.

``` bash
kubectl get resourcegroups
NAME           PROVISIONED   MESSAGE
aso-test-rg    true          successfully provisioned
``` 

## Bundle your application with its infrastructure dependencies

As we now know how Azure Service Operator works, we are going to look at how we can use it to bundle our application together with our infrastructure. We will use the [Azure voting app](https://github.com/Azure-Samples/azure-voting-app-redis) as an example. It consists of a Python microservice provided as a deployment, a LoadBalancer service to publish it externally, and Azure Cache for Redis to persist the state. Let’s take a look at the manifest:

``` yaml
apiVersion: azure.microsoft.com/v1alpha1
kind: ResourceGroup
metadata:
  name: azure-vote-rg
spec:
  location: westeurope
---
apiVersion: azure.microsoft.com/v1alpha1
kind: RedisCache
metadata:
  name: azure-vote-redis
spec:
  location: westeurope
  resourceGroup: azure-vote
  properties:
    sku:
      name: Basic
      family: C
      capacity: 1
    enableNonSslPort: true
---
apiVersion: apps/v1
kind: Deployment
metadata:
  name: azure-vote-front
spec:
  replicas: 1
  selector:
    matchLabels:
      app: azure-vote-front
  template:
    metadata:
      labels:
        app: azure-vote-front
    spec:
      nodeSelector:
        "beta.kubernetes.io/os": linux
      containers:
      - name: azure-vote-front
        image: microsoft/azure-vote-front:v1
        resources:
          requests:
            cpu: 100m
            memory: 128Mi
          limits:
            cpu: 250m
            memory: 256Mi
        ports:
        - containerPort: 80
        env:
        - name: REDIS_NAME
          valueFrom:
            secretKeyRef:
              name: azure-redis
              key: redisCacheName
        - name: REDIS
          value: $(REDIS_NAME).redis.cache.windows.net
        - name: REDIS_PWD
          valueFrom:
            secretKeyRef:
              name: azure-redis
              key: primaryKey
---
apiVersion: v1
kind: Service
metadata:
  name: azure-vote-front
spec:
  type: LoadBalancer
  ports:
  - port: 80
  selector:
    app: azure-vote-front
```

We will now take a closer look at the above definitions. In the first step, we declare a resource group as before. Next, we declare an Azure Cache for Redis by specifying a name, a location, a resource group, and several Redis-related parameters. If we take a closer look at the deployment itself, we may notice the following:

``` yaml
        env:
        - name: REDIS_NAME
          valueFrom:
            secretKeyRef:
              name: azure-redis
              key: redisCacheName
        - name: REDIS
          value: $(REDIS_NAME).redis.cache.windows.net
        - name: REDIS_PWD
          valueFrom:
            secretKeyRef:
              name: azure-redis
              key: primaryKey
```

Azure Service Operator will not only provide the resources for us but will also ensure that we can discover the secret and the name by putting them into a Kubernetes secret (you can also use Azure Keyvault for that). In this way, we can now easily inject them into our containers.

## Manage your Azure resources with a GitOps approach

Now that everything above is in place, we are ready to talk about using Azure Service Operator in a GitOps approach. In the following example, we will use [FluxCD](https://fluxcd.io/) to achieve this.

First of all, you need to install the [fluxctl CLI](https://docs.fluxcd.io/en/1.19.0/references/fluxctl/). Afterward, we install FluxCD and provide our Git repository containing our manifests (you can reuse [my repository](https://github.com/nmeisenzahl/aso-fluxcd-sample) by forking it):

``` bash
helm repo add fluxcd https://charts.fluxcd.io
helm repo update
helm upgrade -i flux fluxcd/flux \
  --set git.url=git@github.com:nmeisenzahl/aso-fluxcd-sample.git \
  --set git-path=workloads \
  --namespace flux
```

After the installation is complete, we have to give FluxCD access to our repository. This is done with an SSH key, which you can get with `fluxctl`:

``` bash
fluxctl identity --k8s-fwd-ns flux
```

Once you add the SSH key to your profile, FluxCD will immediately start to create your resources based on the manifests. FluxCD will now ensure that all changes are applied.
