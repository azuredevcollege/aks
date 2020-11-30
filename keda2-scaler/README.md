# Run the sample

## Install KEDA 2.0

Helm: https://keda.sh/docs/2.0/deploy/#helm

## Add an Azure Storage Queue

https://docs.microsoft.com/en-us/azure/storage/queues/storage-queues-introduction

## Run a Azure Storage Queue Consumer

Add a secret for storing the Storage Queue connection string:

```zsh
kubectl create secret generic consumersecrets --from-literal=QCONNECTION=<YOUR_STORAGE_ACCOUNT_CONNECTION_STRING>
```

Deploy the consumer:

```yaml
apiVersion: apps/v1
kind: Deployment
metadata:
  name: kedaconsumer-deploy
  labels:
    application: kedaconsumer
spec:
  replicas: 1
  selector:
    matchLabels:
      application: kedaconsumer
  template:
    metadata:
      labels:
        application: kedaconsumer
    spec:
      containers:
        - name: application
          resources:
            requests:
              memory: "64Mi"
              cpu: "100m"
            limits:
              memory: "256Mi"
              cpu: "500m"
          image: csaocpger/queueconsumer:1.0
          env:
            - name: QCONNECTION
              valueFrom:
                secretKeyRef:
                  name: consumersecrets
                  key: QCONNECTION
          imagePullPolicy: IfNotPresent
```

Add the Scaler Object:

```yaml
apiVersion: keda.sh/v1alpha1
kind: ScaledObject
metadata:
  name: azure-queue-scaledobject
  namespace: default
spec:
  scaleTargetRef:
    name: kedaconsumer-deploy
  triggers:
    - type: azure-queue
      metadata:
        queueName: keda
        connectionFromEnv: QCONNECTION
        queueLength: "5"
```

Now add messages to the queue (a running consumer will pick one message every 5 seconds) and see KEDA in action.
