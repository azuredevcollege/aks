# Containerized DNS Forwarder

This project provides a containerized DNS server that forwards queries to Azure's internal DNS servers so that hostnames in the virtual network can be resolved from outside the network. This is helpful, for example, when you need to resolve Private Link enabled resources from your on-premises networks connected via Side-to-Side VPN or ExpressRoute.

Now, with General Availability (GA) of Azure Private Link many customers are moving their Azure resource and service endpoints into a private virtual network. Doing so, increases security but also creates some further issues that need to be addressed. One, for example, is how to access the Azure resources from outside Azure (like on-premises). 

## DNS resolution with Private Link

When you're connecting to a private link resource using a fully qualified domain name (FQDN) as part of the connection string, it's important to correctly configure your DNS settings to resolve to the allocated private IP address. Existing Microsoft Azure services might already have a DNS configuration to use when connecting over a public endpoint. This configuration needs to be overridden to connect using your private endpoint.

This is done by creating a private DNS Zone and overwriting the existing public endpoints using the private endpoint IP as described below:

![Private Link DNS](https://docs.microsoft.com/en-us/azure/private-link/media/private-endpoint-dns/single-vnet-azure-dns.png)

More details are available [here](https://docs.microsoft.com/en-us/azure/private-link/private-endpoint-dns). 

## DNS resolution outside Azure

If you like to correctly resolve the private endpoints from outside the Azure virtual network (like a Side-to-Side VPN or ExpressRoute) you need to make sure to forward all related DNS entries to the Azure provided DNS service. Unfortunately, this can't be done directly because the service only offers context-based filtered name resolution to only provide resolution for authorized Azure resources. More details on this are available [here](https://docs.microsoft.com/en-us/azure/virtual-network/what-is-ip-address-168-63-129-16).

To be able to make private DNS entries available you will need to deploy a DNS Forwarder virtual machine which is available [here](https://github.com/Azure/azure-quickstart-templates/tree/master/301-dns-forwarder/). This virtual machine can then be used to forward on-premises DNS requests to.

![DNS Forwarder](https://docs.microsoft.com/en-us/azure/private-link/media/private-endpoint-dns/hybrid-scenario.png)

## The project

In a cloud-native environment the above unmanaged, not high available virtual machine does not fit very well. That is why this project was created. It was inspired by the DNS Forwarder VM but implemented the functionality within a single container. 

The container is fast, scalable and can be deployed into a Azure Kubernetes Cluster to allow high-availability and load balancing. It is also possible to deploy the container with a serverless approach in Azure Container instances.

More details are available on [https://github.com/whiteducksoftware/az-dns-forwarder](https://github.com/whiteducksoftware/az-dns-forwarder).

### Get started on Kubernetes

You need make sure that all needed private Azure DNS zones are linked to the virtual network used for AKS. Without this the DNS forwarder will not be able to resolve them.

```
kubectl apply -f https://raw.githubusercontent.com/whiteducksoftware/az-dns-forwarder/master/deploy.yaml
```

This will deploy the Azure DNS Forwarder container as Deployment with 3 replicas. It also creates an LoadBalancer services using an internal Azure Loadbalancer to expose the DNS forwarder internally.

### Run it serverless with ACI

You can also run the DNS Forwarder as a serverless instance with ACI. Once again, you will need to make sure to expose ACI internally and make sure that all needed Azure private DNS zones are linked to the used virtual network.

```
az container create \
  --resource-group <your-rg> \
  --name dns-forwarder \
  --image docker.pkg.github.com/whiteducksoftware/az-dns-forwarder/az-dns-forwarder:latest \
  --cpu 1 \
  --memory 0.5 \
  --restart-policy always \
  --vnet <your-vnet> \
  --subnet <your-subnet> \
  --ip-address private \
  --location <your-location> \
  --os-type Linux \
  --port 53 \
  --protocol UDP
```
