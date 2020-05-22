# Get started with Windows Containers on AKS

This repository shows you how you get started running Windows Containers on AKS.
The Azure Dcoumentation [here](https://docs.microsoft.com/azure/aks/windows-container-cli) is a good starting point.

## Default node pool
There is always one default node ppol deployed. The default node pool can not be delete. The default node pool is based on linux.

## Overview

In this repository you will see how you create an AKS Cluster with an additional node pool based on OS type Windows.
First we will deploy a simple ASP.NET Core API on the Windows node pool and use NGINX as an Ingress Contoller.
After that we will deploy an ASP.NET WebApplication on the Windows node pool and use NGINX as an Ingress Controller.

### Create a Resource Group

```Shell
az group create --resource-group myRG --location eastus2
```

### Create an AKS Cluster

An AKS Cluster supports node pool for Windows only, if the [Azure CNI](https://docs.microsoft.com/azure/aks/concepts-network#azure-cni-advanced-networking) network policy is active. Of course you can integrate your Cluster in your VNET, but to keep it simple for the moment we don't integrate the Cluster into your network.

#### Azure CLI
Before we create the cluster, make sure you have the latest Azure CLI intsalled on your system. [Here](https://docs.microsoft.com/cli/azure/install-azure-cli?view=azure-cli-latest) you can find the installation guides.
If you have already installed the aks-preview Azure CLI extension, update or remove it.

Update:
```Shell
az extension update -n aks-preview
```

Remove:
```Shell
az extension remove aks-preview
```

#### Create the Cluster
Now we can create the Cluster:

```Shell
az aks create \
    --resource-group myRG \ 
    --name akswin \
    --node-count 2 \
    --network-plugin azure
```

#### Add a Windows Server node pool

An AKS Cluster is already created with a default node pool that can run Linux Containers. 
Now we add a node pool that can run Windows Containers:

```Shell
az aks nodepool add \
    --resource-group myRG \
    --cluster-name akswin \
    --os-type Windows \
    --name windowspool 
```

#### Connect to the cluster

In order to manage an AKS Cluster, we use [kubectl](https://kubernetes.io/docs/user-guide/kubectl/), the Kuberentes command-line client.
To install kubectl locally on your machine, do the following:

```Shell
az aks install-cli
```

To configure kubectl to connect to your Cluster, we need to download the credentials and configure kubectl to use them.
We can do this as follow:

```Shell
az aks get-credentials --resource-group myRG --name akswin
```

Now you can list the nodes of your cluster:

```Shell
kubectl get nodes
```

### Windows Server Version and the right base image for your Windows Containers

To run Windows Containers on the Windows node pool we need to check the Windows Server version to choose the right base image for our Windows Containers.
Run the following command to check the Windows Server version:

```Shell
kubectl get node -o wide

NAME                                STATUS   ROLES   AGE     VERSION    INTERNAL-IP   EXTERNAL-IP   OS-IMAGE                         KERNEL-VERSION      CONTAINER-RUNTIME
aks-nodepool1-22764340-vmss000000   Ready    agent   7h48m   v1.15.10   10.240.0.4    <none>        Ubuntu 16.04.6 LTS               4.15.0-1077-azure   docker://3.0.10+azure
aksnpwin000000                      Ready    agent   6h51m   v1.15.10   10.240.0.35   <none>        Windows Server 2019 Datacenter   10.0.17763.1158     docker://19.3.5
```

In the column __OS-IMAGE__ you see the current Windows Server Release and in the column __KERNEL_VERSION__ you see the OS Build version.
[Here](https://docs.microsoft.com/windows-server/get-started/windows-server-release-info) you can find a mapping from the OS Build version to the Windows Server version. In th above output you see the OS Build version 17763.1158 that matches to the Windows Server version 1809.

## Deploy the ASP.NET Core Demo to your cluster

Now we are ready to deploy the Sample API to your cluster. The ASP.NET Core Sample API uses runtime version 3.1. The Windows base image we use is __mcr.microsoft.com/dotnet/core/aspnet:3.1-nanoserver-1809__ and can be found [here](https://hub.docker.com/_/microsoft-dotnet-core-aspnet/). As you see, we use the base Image __nanoserver-1809__ which is the right version to use for our Windows Server's Kernel Version. 
You don't need to build the image, the image is already available on Docker Hub -> m009/win-aspnetcore-echo-api:01.

### Run the ASP.NET Core Demo API

To deploy the sample on the Windows node pool we, need to specify a NodeSelector for our pod. In this example the node label __beta.kubernetes.io/os=windows__ is used to schedule our pod on nodes of OS type Windows.
To get a list of all node labels, execute the following kubectl command:

```Shell
kubectl get nodes --show-labels
```

Before we deploy our sample API we create a new Kubernetes namespace:

```
kubectl create namespace aspnetcore-demo-api
```

Now we can use the kubectl apply command to deploy the sample API. The deployment yaml file can be found [here](./deploy/win-aspnetcore-echo-api-deployment.yaml).

```yaml
apiVersion: apps/v1
kind: Deployment
metadata: 
  name: win-aspnet-core-echo-api
  labels:
    app: win-aspnet-core-echo-api
spec:
  replicas: 2
  selector: 
    matchLabels:
      app: win-aspnet-core-echo-api
  template:
    metadata:
      labels:
        app: win-aspnet-core-echo-api
    spec:
      containers:
        - name: win-aspnet-core-echo-api
          image: m009/win-aspnet-core-echo-api:0.1
          imagePullPolicy: Always
          ports:
            - containerPort: 5000
      nodeSelector:
        beta.kubernetes.io/os: windows
```

```Shell
kubectl apply -f ./win-aspnetcore-echo-api-deployment.yaml -n aspnetcore-demo-api
```

Use the following command to check the state of your pods:

```
k get pod -n aspnetcore-demo-api -o wide
```

You see that the pods are running on a Windows node.

### Create a service for the ASP.NET Core Demo API

After the pods are up and running we can create a service for our deployment and use kubectl's port-forward to access the API from our local machine. 
First deploy the service which yaml file can be found [here](./deploy/win-aspnetcore-echo-api-service.yaml)

```Shell
kubectl apply -f ./win-aspnetcore-echo-api-service.yaml -n aspnetcore-demo-api
```

Now we can use port-forward command:

```
kubectl port-forward -n aspnetcore-demo-api service/win-aspnetcore-echo-api 8082:80
```

Open your browser, navigate to http://localhost:8082 and test the API.

### Deploy NGINX Ingress Controller

To create the ingress controller, we use Helm to install nginx-ingress. The ingress controller needs to be scheduled on a Linux node.
The node selector is specified using the *--set nodeSelector* parameter.

``` Shell
# Add the official stable repository
helm repo add stable https://kubernetes-charts.storage.googleapis.com/

# Use Helm to deploy an NGINX ingress controller
helm install nginx-ingress stable/nginx-ingress \
    --namespace aspnetcore-demo-api \
    --set rbac.create=true \
    --set controller.replicaCount=2 \
    --set controller.nodeSelector."beta\.kubernetes\.io/os"=linux \
    --set controller.service.externalTrafficPolicy=Local \
    --set controller.scope.enabled=true \
    --set controller.scope.namespace=aspnetcore-demo-api \
    --set defaultBackend.nodeSelector."beta\.kubernetes\.io/os"=linux
```

Deploy the Ingress definition which can be found [here](./deploy/win-aspnetcore-echo-api-ingress.yaml):

```Shell
kubectl apply -f ./win-aspnetcore-echo-api-ingress.yaml -n aspnetcore-demo-api
```

Get the IP of the NGINX ingress controller service:

```Shell
kubectl get service -n aspnetcore-demo-api
```

Open your browser, paste the IP address and test the API.


## Deploy the ASP.NET MVC Demo Application to your cluster

In this part of the repository we deploy an ASP.NET MVC application to our cluster. The application uses .NET Framewrok 4.8.
To have a good demo scenario, we deploy multiple instances of the application into one Kubernetes namespace. Each instance represents a customer of our application. To route traffic to the right instance we use NGINX ingress controller and a unique hostname per customer. 
You can either use your own Azure DNS Zone, if you have one or you can create a free [noip](https://noip.com) account to manage your hostnames.

### Install NGNIX Ingress Controller

As in the previous part of this repository we create a Kubernetes namespace an install NGINX ingress using helm.

```Shell
# create namespace
kubectl create namespace aspnet-application
# Add the official stable repository
helm repo add stable https://kubernetes-charts.storage.googleapis.com/

# Use Helm to deploy an NGINX ingress controller
helm install nginx-ingress-aspnet stable/nginx-ingress \
    --namespace aspnet-application \
    --set rbac.create=true \
    --set controller.replicaCount=2 \
    --set controller.nodeSelector."beta\.kubernetes\.io/os"=linux \
    --set controller.service.externalTrafficPolicy=Local \
    --set controller.scope.enabled=true \
    --set controller.scope.namespace=aspnetapplication \
    --set defaultBackend.nodeSelector."beta\.kubernetes\.io/os"=linux
```

### Deploy an instance of the ASP.NET Application per customer

The Docker image for the ASP.NET Application is already built. Is uses the __mcr.microsoft.com/dotnet/framewrok/aspnet:4.8-windowsservercore-ltsc2019__ base image where an IIS is already installed and prepared. Take a look at the Docker file [here](./apps/AspnetWebApplication/AspnetWebApplication/Dockerfile) to see how it is built. 

The [deployment folder](./deploy) contains already all needed yaml files to deploy two instances of the application.
All you have to do is to replace your customer's domain name for each ingress definition ([customer1](./deploy/win-aspnet-application-customer1-ingress.yaml), [customer2](./deploy/win-aspnet-application-customer2-ingress.yaml)). The placeholder is __<CUSTOMER_DOMAIN>__, please replace it with your dns names.

```Shell
# Deploy the instances
kubectl apply -f ./win-aspnet-application-customer1-deployment.yaml -n aspnet-application \ 
kubectl apply -f ./win-aspnet-application-customer2-deployment.yaml -n aspnet-application \
kubectl apply -f ./win-aspnet-application-customer1-service.yaml -n aspnet-application \
kubectl apply -f ./win-aspnet-application-customer2-service.yaml -n aspnet-application \
kubectl apply -f ./win-aspnet-application-customer1-ingress.yaml -n aspnet-application \
kubectl apply -f ./win-aspnet-application-customer2-ingress.yaml -n aspnet-application 
```






