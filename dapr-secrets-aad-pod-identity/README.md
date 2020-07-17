# Access Azure KeyVault using dapr secrets and aad-pod-identity

Setup an AKS Cluster with --enabled-managed-identity

## Variables

```Shell
export SUBSCRIPTION_ID=<your subscription id>
export RESOURCE_GROUP=<your AKS resource group name>
export IDENTITY_NAME=<your managed identity name>
export KEYVAULT_NAME=<your keyvault name>
export CLUSTER_NAME=<your AKS Cluster name>
```

## Create a managed identity

```Shell
az identity create -g $RESOURCE_GROUP -n $IDENTITY_NAME --subscription $SUBSCRIPTION_ID
export IDENTITY_CLIENT_ID="$(az identity show -g $RESOURCE_GROUP -n $IDENTITY_NAME --subscription $SUBSCRIPTION_ID --query clientId -otsv)"
export IDENTITY_RESOURCE_ID="$(az identity show -g $RESOURCE_GROUP -n $IDENTITY_NAME --subscription $SUBSCRIPTION_ID --query id -otsv)"
export IDENTITY_OBJECT_ID="$(az ad sp show --id $IDENTITY_CLIENT_ID --query objectId -otsv)"
```

## Assign 'Managed Identity Operator' role to Kubernetes ServicePrincipal

Now we need to give the AKS Cluster's service principal rights to operate on the created managed identity.

If your AKS cluster is deployed with __managed identity enabled__, do the following to get your principal id:

```Shell
export AKS_CLIENT_ID=$(az aks show -n $CLUSTER_NAME -g $RESOURCE_GROUP --query identityProfile.kubeletidentity.clientId -otsv)
```

If you have an AKS Cluster deployed __without managed identity enabled__, do the following to get the principal id:

```Shell
export AKS_CLIENT_ID=$(az aks show -n $CLUSTER_NAME -g $RESOURCE_GROUP --query servicePrincipalProfile.clientId -otsv)
```

After that we can assign the *Managed Identity Operator* role to the AKS Cluster's principal for the managed identity:

```Shell
az role assignment create --assignee $AKS_CLIENT_ID --role "Managed Identity Operator" --scope /subscriptions/$SUBSCRIPTION_ID/resourcegroups/$RESOURCE_GROUP/providers/Microsoft.ManagedIdentity/userAssignedIdentities/$IDENTITY_NAME
```

**Note:**
If you have an AKS Cluster with __managed identity enabled__ we need to assign the role *"Virtual Machine Contributor"* to the AKS Cluster's service principal. For AKS cluster, the cluster resource group refers to the resource group with a MC_ prefix, which contains all of the infrastructure resources associated with the cluster like VM/VMSS.

If you need further information about needed role assignments look at the aad-pod-identity's 
[documentation](https://github.com/Azure/aad-pod-identity/blob/master/docs/readmes/README.role-assignment.md) .

```Shell
export CLUSTER_RESOURCE_GROUP=<your MC_ AKS Cluster resource group name>
az role assignment create --role "Virtual Machine Contributor" --assignee $AKS_CLIENT_ID --scope /subscriptions/$SUBSCRIPTION_ID/resourcegroups/$CLUSTER_RESOURCE_GROUP
```

## Install aad-pod-identity using helm

Now everything is prepared to setup aad-pod-identity using helm. In this demo we create a namespace for the aad-pod-identity's operator and daemon set to separate them
from our application:

Create a namspace:
```
kubectl create namespace aad-pod-identity
```

Install aad-pod-identity:
```
helm repo add aad-pod-identity https://raw.githubusercontent.com/Azure/aad-pod-identity/master/charts
helm repo update
helm install aad-pod-identity aad-pod-identity/aad-pod-identity --namespace aad-pod-identity
```

## Deploy AzureIdentity and AzureIdentityBinding

The sample application is deployed in its own namespace. To request an access token to access Azure resources from a pod, we need to deploy two Kubernetes Resources.
__AzureIdentity__ is the resource to link to an existing Azure managed identity. To specify which managed identity a Pod should use to acquire an access token a selector that specifies the binding must be added to the pod. __AzureIdentityBinding__ defines the name of the selector and the binding to an __AzureIdentity__.

Open the files [keyvault-azure-identity.yaml](./deploy/keyvault-azure-identity.yaml) and [keyvault-azure-identitybinding.yaml](./deploy/keyvault-azure-identitybinding.yaml) and replace the *$* marked values with your values.

Create a namespace for the demo application,

```Shell
kubectl create namespace dapr-secrets
```

and apply the yaml files:

```
kubectl apply -f keyvault-azure-identity.yaml -n dapr-secrets
kubectl apply keyvault-azure-identitybinding.yaml -n dapr-secrets
```

Aad-pod-identity provides a simple demo image to validate your setup. Open the file [validate-identity-pod.yaml](./deploy/validate-identity-pod.yaml),replace the *$* marked values with your values and deploy the pod.

``` Shell
kubectl apply -f validate-identity-pod.yaml -n dapr-secrets
```

Check and validate the output of the validation pod:

```Shell
kubectl logs demo -n dapr-secret
```

## Create an Azure key vault

Create an Azure key vault instance in your resource group and assign needed policies to get and list secrets on behalf-of the managed identity:

```Shell
az keyvault create --name $KEYVAULT_NAME --resource-group $RESOURCE_GROUP
az keyvault set-policy --name $KEYVAULT_NAME --resource-group $RESOURCE_GROUP --secret-permissions get list --object-id $IDENTITY_OBJECT_ID
```

Add two secrets to the key vault:

```Shell
az keyvault secret set --vault-name $KEYVAULT_NAME  --name secretone --value valueone
az keyvault secret set --vault-name $KEYVAULT_NAME  --name secrettwo --value valuetwo
```

## Install dapr

Now it's time to install dapr. We deploy the dapr runtime into its own namespace using helm.

```Shell
kubectl create namespace dapr-system
```

Add Azure Container Registry as a helm repo:

```Shell
helm repo add dapr https://daprio.azurecr.io/helm/v1/repo
helm repo update
```

Install dapr:

```Shell
helm install dapr dapr/dapr --namespace dapr-system
```

Once the chart installation is done, verify the Dapr operator pods are running in the dapr-system namespace:

```Shell
kubectl get pods --namespace dapr-system
```

## Deploy the sample application

To let dapr know which Azure key vault is used, a dapr secret component must be deployed.

```yaml
apiVersion: dapr.io/v1alpha1
kind: Component
metadata:
  name: azurekeyvault
spec:
  type: secretstores.azure.keyvault
  metadata:
  - name: vaultName
    value: $KEYVAULT_NAME
```

As we use aad-pod-identity the dapr sidecar will use the MSI endpoint to acquire a token to access the Azure key vault.
In the previous steps we have created a managed identity which has read access to the Azure key vault instance. With __AzureIdentity__ and __AzureIdentityBinding__ we can bind a deployment to a managed identity that is used to acquire a token.

```yaml
apiVersion: apps/v1
kind: Deployment
metadata:
  name: api-aspnetcore
  labels:
    app: dapr-secrets
spec:
  replicas: 1
  selector:
    matchLabels:
      app: dapr-secrets
  template:
    metadata:
      labels:
        app: dapr-secrets
        aadpodidbinding: $IDENTITY_NAME
      annotations:
        dapr.io/enabled: "true"
        dapr.io/id: "api-aspnetcore"
        dapr.io/port: "5000"
    spec:
      containers:
        - name: api-aspnetcore
          image: m009/dapr-secret-api-dotnetcore:0.1
          ports:
            - containerPort: 5000
          imagePullPolicy: Always
```

Open the [dapr-azure-keyvault-secretstore component file](./deploy/dapr-azure-keyvault-secretstore.yaml) replace the $ marked value and deploy it to your cluster:

```
kubectl apply -f dapr-azure-keyvault-secretstore component -n dapr-secrets
```

Open the [api-aspnetcore-deployment file ](./deploy/api-aspnetcore-deployment.yaml) replace the $ marked value and deploy it to your cluster:

```Shell
kubectl apply -f api-aspnetcore-deployment.yaml -n dapr-secrets
```

After that deploy the [dapr-secrets-service file](./deploy/dapr-secrets-service.yaml) and get the public ip:

```Shell
kubectl apply -f dapr-secrets-service.yaml -n dapr-secrets
kubectl get service -n dapr-secrets
```

## Test the demo application

After you have the public ip of the demo application's service, open your brwoser and naviagte http://<ip>/secret. You should see the following output:

```JSON
SecretOne: {"secretone":"valueone"} | SecretTwo: {"secrettwo":"valuetwo"}
```

## Investigate the source code

The demo application simply invokes the dapr sidecar to query one secret after the other and returns the values.
The dapr sidecar is listening on port 3500 and the secrets are read by specifying the following url:

```Text
http://localhost:{_daprPort}/v1.0/secrets/{_secretStoreName}/{_secretName}
```
The path parameter _secretStoreName is the name of the dapr secretstore that is specified in [dapr-azure-keyvault-secretstore](./deploy/dapr-azure-keyvault-secretstore.yaml). The path parameter _secretName is the name of the secret that is read from the Azure key vault instance.

```C#
    public class SecretController : ControllerBase
    {
        private static int _daprPort = 3500;
        private static string _secretsUrl = $"http://localhost:{_daprPort}/v1.0/secrets";
        private static string _secretStoreName = "azurekeyvault";
        private static string _secretOne = "secretone";
        private static string _secretTwo = "secrettwo";

        [HttpGet]
        public async Task<IActionResult> GetSecrets()
        {
            try
            {
                var client = new HttpClient();
                var result = await client.GetAsync($"{_secretsUrl}/{_secretStoreName}/{_secretOne}");

                if (!result.IsSuccessStatusCode)
                {
                    return StatusCode((int)HttpStatusCode.InternalServerError);
                }

                var secretOne = await result.Content.ReadAsStringAsync();

                result = await client.GetAsync($"{_secretsUrl}/{_secretStoreName}/{_secretTwo}");

                if (!result.IsSuccessStatusCode)
                {
                    return StatusCode((int)HttpStatusCode.InternalServerError);
                }

                var secretTwo = await result.Content.ReadAsStringAsync();

                return Ok($"SecretOne: {secretOne} | SecretTwo: {secretTwo}");
            }
            catch (Exception ex)
            {
                return Ok(ex.Message);
            }
        }
    }
```