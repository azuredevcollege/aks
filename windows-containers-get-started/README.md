# Get started with Windows Containers on AKS

This repository shows you how you get started running Windows Containers on AKS.
The Azure Dcoumentation [here](https://docs.microsoft.com/azure/aks/windows-container-cli) is a good starting point.

## Default node pool
There is always one default node ppol deployed. The default node pool can not be delete. The default node pool is based on linux.

## What you learn will learn with this repository

With this repository you will learn how you create a AKS Cluster with an additional node pool based on OS type Windows.
First we will deploy a simple ASP.NET Core API on the Windows node pool and use NGINX as an Ingress Contoller.
After that we will deploy a ASP.NET WebApplication on the Windows node pool and use NGINX as an Ingress Controller.

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




