# AWS Secrets Manager Driver setup

install the Secrets Store CSI Driver and the AWS Secrets and Configuration Provider (ASCP) on EKS cluster. This setup enables Kubernetes Pods to securely retrieve secrets from AWS Secrets Manager and AWS Systems Manager Parameter Store, using EKS Pod Identity for authentication without storing any credentials inside the cluster.

**Architecture Diagram**

![Alt text](https://github.com/nawaz-ch/aws-secrets-manager-demo/blob/450594cb110216d017411fc37316954541967fcd/aws-secrets-manager.png)

**Add Helm Repositories**
Add both the Kubernetes CSI Driver and AWS Secrets Provider repositories.

```bash
# Add Helm Repositories
helm repo add secrets-store-csi-driver https://kubernetes-sigs.github.io/secrets-store-csi-driver/charts
helm repo add aws-secrets-manager https://aws.github.io/secrets-store-csi-driver-provider-aws
helm repo update

# List Helm Repos
helm repo list

```
Expected:

```bash
NAME                    URL
secrets-store-csi-driver https://kubernetes-sigs.github.io/secrets-store-csi-driver/charts
aws-secrets-manager      https://aws.github.io/secrets-store-csi-driver-provider-aws

```

# Install the Secrets Store CSI Driver
Install the core driver that enables Kubernetes to mount external secrets.

```bash
# Install the Secrets Store CSI Driver in the kube-system namespace:
helm install csi-secrets-store \
  secrets-store-csi-driver/secrets-store-csi-driver \
  --namespace kube-system \
  --set tokenRequests[0].audience="pods.eks.amazonaws.com"

# List all Helm releases across namespaces:
helm list --all-namespaces

# List releases only in the kube-system namespace:
helm list -n kube-system

# Verify installation status, pods, and resources created by the release:
helm status csi-secrets-store -n kube-system


# Verify pods:
kubectl get pods -n kube-system -l app=secrets-store-csi-driver

```

## Note:
The --set tokenRequests[0].audience="pods.eks.amazonaws.com" flag is required when installing the CSI driver separately (as we do here). It tells the CSI driver to request service account tokens with the EKS Pod Identity audience so pods can authenticate to AWS. Without this flag, pods using Pod Identity will fail with the error serviceAccount.tokens not provided. We only configure the pods.eks.amazonaws.com audience because this course uses EKS Pod Identity (not IRSA).


# Install the AWS Secrets and Configuration Provider (ASCP)

Next, install the AWS-specific provider that connects the CSI driver to AWS Secrets Manager and Parameter Store.

This component is called AWS Secrets and Configuration Provider (ASCP).

why `--set secrets-store-csi-driver.install=false`?

The AWS Provider Helm chart includes the CSI driver as a dependency by default. Since we already installed it in previous step, we must disable that dependency to prevent Helm ownership conflicts.

---
# install the aws provider
```bash
# Install the AWS Secrets Manager CSI Driver Provider in the kube-system namespace.
helm install secrets-provider-aws \
  aws-secrets-manager/secrets-store-csi-driver-provider-aws \
  --namespace kube-system \
  --set secrets-store-csi-driver.install=false

# List installed Helm Releases
helm list -n kube-system

# Inspect the AWS provider Helm release:
helm status secrets-provider-aws -n kube-system

```

✅ This command installs only the AWS provider (ASCP) components and reuses the CSI driver already installed.

**Verify Installation**
After ~30 seconds, check that all pods are running:

```bash
# CSI driver pods
kubectl get pods -n kube-system -l app=secrets-store-csi-driver

# AWS provider (ASCP) pods
kubectl get pods -n kube-system -l app=secrets-store-csi-driver-provider-aws

```

**Verify DaemonSets**

```bash
kubectl get daemonset -n kube-system | grep secrets-store

```

**Troubleshooting**
If you don’t see the AWS provider pods (csi-secrets-store-provider-aws):
```bash
kubectl describe daemonset secrets-provider-aws-secrets-store-csi-driver-provider-aws -n kube-system
kubectl logs -n kube-system -l app=secrets-store-csi-driver-provider-aws

```

# Create IAM Role, Policy and EKS Pod Identity Association

**Export Environment Variables**

```bash
# Replace the placeholders below with your actual values
export AWS_REGION="us-east-1"
export EKS_CLUSTER_NAME="retail-dev-eksdemo1"
export AWS_ACCOUNT_ID=$(aws sts get-caller-identity --query Account --output text)

# Confirm values
echo $AWS_REGION
echo $EKS_CLUSTER_NAME
echo $AWS_ACCOUNT_ID

```

**Create IAM Policy**
This policy grants permission to read one secret — catalog-db-secret — from AWS Secrets Manager.

VERY VERY IMPORTANT NOTE: We’re scoping access to only one secret (catalog-db-secret*) — least-privilege best practice.


```bash
# Create Catalog DB Secret Policy JSON file
cat <<EOF > catalog-db-secret-policy.json
{
  "Version": "2012-10-17",
  "Statement": [
    {
      "Effect": "Allow",
      "Action": [
        "secretsmanager:GetSecretValue",
        "secretsmanager:DescribeSecret"
      ],
      "Resource": "arn:aws:secretsmanager:${AWS_REGION}:${AWS_ACCOUNT_ID}:secret:catalog-db-secret*"
    }
  ]
}
EOF

```

**create the policy**
```bash
# Create IAM Policy
aws iam create-policy \
  --policy-name catalog-db-secret-policy \
  --policy-document file://catalog-db-secret-policy.json

```

**Create IAM Role for Pod Identity**
```bash
cat <<EOF > trust-policy.json
{
  "Version": "2012-10-17",
  "Statement": [
    {
      "Effect": "Allow",
      "Principal": {
        "Service": "pods.eks.amazonaws.com"
      },
      "Action": [
        "sts:AssumeRole",
        "sts:TagSession"
      ]
    }
  ]
}
EOF

```

**create the role**
```bash
# Create IAM Role
aws iam create-role \
  --role-name catalog-db-secrets-role \
  --assume-role-policy-document file://trust-policy.json

```

**Attach the policy to the role**
```bash
# Attach the IAM policy to IAM Role
aws iam attach-role-policy \
  --role-name catalog-db-secrets-role \
  --policy-arn arn:aws:iam::${AWS_ACCOUNT_ID}:policy/catalog-db-secret-policy

```

**Create Pod Identity Association**

```bash
aws eks list-addons --cluster-name ${EKS_CLUSTER_NAME}

## Sample Output
{
    "addons": [
        "eks-pod-identity-agent"
    ]
}

# Create Pod Identity Association
aws eks create-pod-identity-association \
  --cluster-name ${EKS_CLUSTER_NAME} \
  --namespace default \
  --service-account catalog-mysql-sa \
  --role-arn arn:aws:iam::${AWS_ACCOUNT_ID}:role/catalog-db-secrets-role

```

**Verify Pod Identity Association**

Check that your Kubernetes ServiceAccount exists and is ready for binding:

```bash
kubectl get sa catalog-mysql-sa
```


# Integrate AWS Secrets Manager with Catalog Microservice (EKS Pod Identity)

mount secrets directly from AWS Secrets Manager into our Catalog microservice with Secrets Store CSI Driver and AWS Secrets Provider (ASCP).

**Architecture overview**
```bash
+------------------------------------+
| AWS Secrets Manager                |
| Secret: catalog-db-secret-1        |
| {                                  |
|   "MYSQL_USER":"catalog",          |
|   "MYSQL_PASSWORD":"MyS3cr3tPwd"   |
| }                                  |
+----------------+-------------------+
                 |
                 | (via EKS Pod Identity)
                 v
+-------------------------------------------+
| Amazon EKS Cluster                        |
|  - Pod Identity Agent                     |
|  - AWS Secrets & Config Provider (ASCP)   |
|  - catalog-mysql-sa (ServiceAccount)      |
|  - SecretProviderClass: catalog-db-secrets|
|                                           |
|  /mnt/secrets-store/MYSQL_USER            |
|  /mnt/secrets-store/MYSQL_PASSWORD        |
+-------------------------------------------+

```

# Create AWS Secret in Secrets Manager
```bash

# Replace <REGION> with your AWS Region (e.g., us-east-1)
export AWS_REGION="us-east-1"

# Create Secret 
aws secretsmanager create-secret \
  --name catalog-db-secret-1 \
  --region $AWS_REGION \
  --description "MySQL credentials for Catalog microservice" \
  --secret-string '{
      "MYSQL_USER": "mydbadmin",
      "MYSQL_PASSWORD": "nawazdb101"
  }'

# List all secrets in your account (filtered by name)
aws secretsmanager list-secrets --region $AWS_REGION --query "SecretList[?contains(Name, 'catalog-db-secret-1')].[Name,ARN]" --output table


# Describe the Secret for Details
aws secretsmanager describe-secret \
  --secret-id catalog-db-secret-1 \
  --region $AWS_REGION

# Retrieve Secret Value (for testing only)
aws secretsmanager get-secret-value \
  --secret-id catalog-db-secret-1 \
  --region $AWS_REGION \
  --query SecretString --output text

```

# Create the SecretProviderClass
---
This tells ASCP which AWS secret to fetch and how to make it available to the container.

```bash
apiVersion: secrets-store.csi.x-k8s.io/v1
kind: SecretProviderClass
metadata:
  name: catalog-db-secrets
spec:
  provider: aws
  parameters:
    objects: |
      - objectName: "catalog-db-secret-1"
        objectType: "secretsmanager"
        jmesPath:
          - path: "MYSQL_USER"
            objectAlias: "MYSQL_USER"
          - path: "MYSQL_PASSWORD"
            objectAlias: "MYSQL_PASSWORD"
    usePodIdentity: "true"
```

✅ This configuration:
1.Fetches catalog-db-secret-1 from AWS Secrets Manager.
2.Extracts MYSQL_USER and MYSQL_PASSWORD into two files under /mnt/secrets-store.
3.Uses Pod Identity for authentication (no IRSA or node IAM role required).
4.Does not create any native Kubernetes Secret — best-security mode.


# Create the ServiceAccount
---
The ServiceAccount (catalog-mysql-sa) is already associated with an IAM Role via Pod Identity, allowing Pods using this SA to authenticate to AWS.

```bash
apiVersion: v1
kind: ServiceAccount
metadata:
  name: catalog-mysql-sa
  labels:
    app.kubernetes.io/name: catalog
    app.kubernetes.io/instance: catalog
    app.kubernetes.io/component: service
    app.kubernetes.io/owner: retail-store-sample

```

# Update the MySQL StatefulSet

```bash
apiVersion: apps/v1
kind: StatefulSet
metadata:
  name: catalog-mysql
  labels:
    app.kubernetes.io/name: catalog
    app.kubernetes.io/instance: catalog
    app.kubernetes.io/component: mysql
    app.kubernetes.io/owner: retail-store-sample
spec:
  replicas: 1
  serviceName: catalog-mysql
  selector:
    matchLabels:
      app.kubernetes.io/name: catalog
      app.kubernetes.io/instance: catalog
      app.kubernetes.io/component: mysql
      app.kubernetes.io/owner: retail-store-sample
  template:
    metadata:
      labels:
        app.kubernetes.io/name: catalog
        app.kubernetes.io/instance: catalog
        app.kubernetes.io/component: mysql
        app.kubernetes.io/owner: retail-store-sample
    spec:
      serviceAccount: catalog-mysql-sa
      containers:
        - name: mysql
          image: "public.ecr.aws/docker/library/mysql:8.0"
          imagePullPolicy: IfNotPresent
          ports:
            - name: mysql
              containerPort: 3306
              protocol: TCP
          env:
            - name: MYSQL_ROOT_PASSWORD
              value: my-secret-pw
            - name: MYSQL_DATABASE
              value: catalogdb
          command: ["/bin/bash", "-c"]
          args:
            - |
              export MYSQL_USER=$(cat /mnt/secrets-store/MYSQL_USER);
              export MYSQL_PASSWORD=$(cat /mnt/secrets-store/MYSQL_PASSWORD);
              echo "Loaded secrets from AWS Secrets Manager. Starting MySQL with user=$MYSQL_USER";
              exec docker-entrypoint.sh mysqld
          volumeMounts:
            - name: data
              mountPath: /var/lib/mysql
            - name: aws-secrets
              mountPath: /mnt/secrets-store
              readOnly: true
      volumes:
        - name: data
          emptyDir: {}
        - name: aws-secrets
          csi:
            driver: secrets-store.csi.k8s.io
            readOnly: true
            volumeAttributes:
              secretProviderClass: "catalog-db-secrets"

```

✅ Behavior:
1.Reads credentials directly from AWS Secrets Manager.
2.Credentials are never stored in Kubernetes.
3.Safe even if etcd or the cluster is compromised.

# Apply All Kubernetes Manifests

```bash
# First: Deploy Secret Provider Class
kubectl apply -f 01_secretproviderclass

# Second: Deploy all our Catalog k8s Manifests
kubectl apply -f 02_catalog_k8s_manifests

```

# Verify if Secrets mounted in pods or not
```bash
# MySQL Pod
kubectl exec -it <mysql-pod-name> -- ls /mnt/secrets-store
kubectl exec -it <mysql-pod-name> -- cat /mnt/secrets-store/MYSQL_USER
kubectl exec -it <mysql-pod-name> -- cat /mnt/secrets-store/MYSQL_PASSWORD


# Catalog Pod
kubectl exec -it <catalog-pod-name> -- ls /mnt/secrets-store
kubectl exec -it <catalog-pod-name> -- cat /mnt/secrets-store/MYSQL_USER
kubectl exec -it <catalog-pod-name> -- cat /mnt/secrets-store/MYSQL_PASSWORD

```

# Verify Catalog Microservice Application
```bash
# List Pods
kubectl get pods

# Port-forward
kubectl port-forward svc/catalog-service 7080:8080

# Acess Catalog Endpoints
http://localhost:7080/topology
http://localhost:7080/health
http://localhost:7080/catalog/products
http://localhost:7080/catalog/size
http://localhost:7080/catalog/tags

```


# Connect to MySQL Database and Verify
```bash
# Connect to MySQL Database using MySQL Client Pod
kubectl run mysql-client --rm -it \
  --image=mysql:8.0 \
  --restart=Never \
  -- mysql -h catalog-mysql -u mydbadmin -p

When prompted for password, enter: nawazdb101

```

# Run SQL Commands
```bash

SHOW DATABASES;
USE catalogdb;
SHOW TABLES;
SELECT * FROM products;
SELECT * FROM tags;
SELECT * FROM product_tags;
EXIT;

```







