#LOGIN TO AZURE
az login

#CREATE CONTAINER REGITRY
az acr create --resource-group <group> --name <name> --sku Basic
#OUTPUT:
{
  "adminUserEnabled": false,
  "creationDate": "2020-02-25T11:39:37.711375+00:00",
  "id": "/subscriptions/1de5a944-d61c-4d0c-a9a9-0562e8d34b01/resourceGroups/BS-Group/providers/Microsoft.ContainerRegistry/registries/palash",
  "location": "centralus",
  "loginServer": "palash.azurecr.io",
  "name": "palash",
  "networkRuleSet": null,
  "policies": {
    "quarantinePolicy": {
      "status": "disabled"
    },
    "retentionPolicy": {
      "days": 7,
      "lastUpdatedTime": "2020-02-25T11:39:38.493066+00:00",
      "status": "disabled"
    },
    "trustPolicy": {
      "status": "disabled",
      "type": "Notary"
    }
  },
  "provisioningState": "Succeeded",
  "resourceGroup": "BS-Group",
  "sku": {
    "name": "Basic",
    "tier": "Basic"
  },
  "status": null,
  "storageAccount": null,
  "tags": {},
  "type": "Microsoft.ContainerRegistry/registries"
}

#CREATE SERVICE PRINCIPAL
az ad sp create-for-rbac --skip-assignment
#OUTPUT:
{
  "appId": "1e7de83a-65ff-4965-b33d-d1c8c4648849",
  "displayName": "azure-cli-2020-02-25-11-41-03",
  "name": "http://azure-cli-2020-02-25-11-41-03",
  "password": "d80b7f00-a194-480d-8fb2-1ca061c4450d",
  "tenant": "4930e3b1-a0c5-46f8-84fe-b3b03553363e"
}
# GET ACR ID
az acr show --resource-group <group> --name <name> --query "id" --output tsv
#OUTPUT:
#/subscriptions/1de5a944-d61c-4d0c-a9a9-0562e8d34b01/resourceGroups/BS-Group/providers/Microsoft.ContainerRegistry/registries/palash

#ASSIGN 'acrpull' ROLE to SP
az role assignment create --assignee <spId> --scope <acrId> --role acrpull
#OUTPUT:
{
  "canDelegate": null,
  "id": "/subscriptions/1de5a944-d61c-4d0c-a9a9-0562e8d34b01/resourceGroups/BS-Group/providers/Microsoft.ContainerRegistry/registries/palash/providers/Microsoft.Authorization/roleAssignments/92feeab3-84dc-4f3e-9c01-b2d81f5b8b08",
  "name": "92feeab3-84dc-4f3e-9c01-b2d81f5b8b08",
  "principalId": "1719498d-89cf-49c7-809a-cb025de423b4",
  "principalType": "ServicePrincipal",
  "resourceGroup": "BS-Group",
  "roleDefinitionId": "/subscriptions/1de5a944-d61c-4d0c-a9a9-0562e8d34b01/providers/Microsoft.Authorization/roleDefinitions/7f951dda-4ed3-4680-a7ca-43fe172d538d",
  "scope": "/subscriptions/1de5a944-d61c-4d0c-a9a9-0562e8d34b01/resourceGroups/BS-Group/providers/Microsoft.ContainerRegistry/registries/palash",
  "type": "Microsoft.Authorization/roleAssignments"
}

#CREATE K8S CLUSTER
#NOTE: MANUALLY CREATE CLUSTER FROM PORTAL
#az aks create --resource-group <group> --name <name> --dns-name-prefix <dns prefix> --node-count 2 --service-principal <spId> --client-secret <client secret> --generate-ssh-keys --enable-rbac --enable-addons monitoring --location eastus --node-vm-size Standard_DS1_v2 --workspace-resource-id <subscription id>

#TRY ACCESSING DASHBOARD
az aks get-credentials -g <resource group> -n <name>
az aks browse -g <resource group> -n <name>
#WILL SHOW ERROR IN DASHBOARD, NOW APPLY DASHBOARD ACCESS PERMISSION TO FIX IT
kubectl apply -f .\kube-dashboard-access.yaml

#CONGRATULATION YOU HAVE SUCCESSFULLY SETUP A K8S CLUSTER! TRY BELOW TO INSTALL DEMO APPS TO SEE THEM IN ACTIONS WITH SSL

#WALK THROUGH LINK: https://docs.microsoft.com/en-us/azure/aks/ingress-tls
#INSTALL HELM V3, ADD OFFICIAL HELM STABLE CHARTS
helm repo add stable https://kubernetes-charts.storage.googleapis.com/
helm repo update

#CRATE NAMESPACE ingress-basic
kubectl create ns app-dev
#OUTPUT:
#namespace/ingress-basic created

#INSTALL nginx INGRESS CONTROLLER. IT WILL INSTALL TWO INGRESS SERVICEs & ONE DEFAULT BACK-END WHICH RETURNS 'default 404'
helm install stable/nginx-ingress --set controller.replicaCount=2 --set controller.nodeSelector."beta\.kubernetes\.io/os"=linux --set defaultBackend.nodeSelector."beta\.kubernetes\.io/os"=linux --namespace kube-system --generate-name
#OUTPUT:
#NAME: nginx-ingress-1578724556
#LAST DEPLOYED: Sat Jan 11 12:35:59 2020
#NAMESPACE: ingress-basic
#STATUS: deployed
#REVISION: 1
#...
#...
#type: kubernetes.io/tls

#TO SEE THE INSTALLED RESOURCES
kubectl get service -l app=nginx-ingress --namespace kube-system
helm list -n kube-system

#GET EXTERNAL IP
kubectl get service -l app=nginx-ingress --namespace kube-system
$IP='<external ip from above command>'
$DNSNAME='sufian'
$PUBLICIPID=$(az network public-ip list --query "[?ipAddress!=null]|[?contains(ipAddress, '$IP')].[id]" --output tsv)
#ASSIGN DNS
az network public-ip update --ids $PUBLICIPID --dns-name $DNSNAME

#INSTALL AZURE SAMPLES
helm repo add azure-samples https://azure-samples.github.io/helm-charts/
helm repo update

#INSTALL FIRST SERVICE
helm install azure-samples/aks-helloworld --namespace ingress-basic --generate-name
#INSTALL 2ND SERVICE
helm install azure-samples/aks-helloworld --namespace ingress-basic  --generate-name --set title="AKS Ingress Demo" --set serviceName="ingress-demo"

#ADD INGRESS
kubectl apply -f .\cluster-ingress.yaml

#INSTALL CERTIFICATE: https://docs.cert-manager.io/en/latest/getting-started/install/kubernetes.html
# CREATE A NAMESPACE TO RUN CERT-MANAGER IN
kubectl create namespace cert-manager
kubectl apply -f https://github.com/jetstack/cert-manager/releases/download/v0.11.0/cert-manager.yaml --validate=false

#SEE CLUSTER ISSUER STATUS
kubectl get all -n cert-manager

#SETUP CLUSTER ISSUER, https://docs.cert-manager.io/en/latest/tasks/issuers/setup-acme/index.html
kubectl apply -f .\cluster-issuer.yaml
kubectl get all -n cert-manager

#CREATE CERTIFICATE
kubectl apply -f .\certificates.yaml

# SEE CERTIFICATE DETAILS
kubectl get certificates -n ingress-basic
kubectl get secret -n ingress-basic

#UPDATE INGRESS TO USE CERTIFICATE
kubectl apply -f .\cluster-ingress.yaml


#########################################
#########################################
#CLEAN UP
#########################################
#########################################
kubectl delete namespace ingress-basic
kubectl delete namespace cert-manager
#DELETE THE CLUSTER
az aks delete --name <name> --resource-group <group>
