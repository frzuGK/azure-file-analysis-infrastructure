# Azure File Analysis Infrastructure

Event-driven file analysis system on Azure using Container Apps, Storage, Event Grid, and Azure OpenAI.

## Architecture

```
User uploads file → Storage Blob → Event Grid → Queue → Container App Job →
Downloads file → Analyzes with AI → Saves result → Job terminates
```

## Components

- **Azure Storage Account**: File storage (upload/results) and event queue
- **Event Grid**: Automatic file upload detection
- **Azure Container Registry**: Private Docker image repository
- **Container Apps Job**: Serverless, event-driven analysis workload
- **Azure OpenAI**: AI-powered file analysis
- **Log Analytics**: Centralized logging and monitoring

## Infrastructure as Code

This repository contains Terraform configurations to deploy the entire infrastructure.

### Prerequisites

1. Azure subscription with permissions to create resources
2. Terraform >= 1.5 installed
3. Azure CLI installed and authenticated

### Local Deployment

```bash
cd terraform
cp terraform.tfvars.example terraform.tfvars
# Edit terraform.tfvars with your values

terraform init
terraform plan
terraform apply
```

### GitHub Actions Deployment

1. **Set up Terraform state storage** (one-time):

```bash
az group create -n tfstate-rg -l westeurope
STORAGE_NAME="tfstate$(openssl rand -hex 4)"
az storage account create -n $STORAGE_NAME -g tfstate-rg -l westeurope --sku Standard_LRS
az storage container create -n tfstate --account-name $STORAGE_NAME
```

2. **Configure GitHub Secrets**:

Add these secrets to your repository (Settings → Secrets and variables → Actions):

- `AZURE_CLIENT_ID` - Service principal client ID
- `AZURE_TENANT_ID` - Azure tenant ID
- `AZURE_SUBSCRIPTION_ID` - Azure subscription ID
- `TF_STATE_RG` - Resource group name for Terraform state (e.g., `tfstate-rg`)
- `TF_STATE_SA` - Storage account name for Terraform state

3. **Create Azure Service Principal with OIDC**:

```bash
az ad sp create-for-rbac \
  --name "github-actions-terraform" \
  --role Contributor \
  --scopes /subscriptions/<subscription-id> \
  --sdk-auth
```

4. **Deploy**: Push to main branch or manually trigger the workflow

## Usage

1. Upload a file to the `binaries-drop` container in the storage account
2. Event Grid detects the upload and adds a message to the queue
3. Container Apps Job automatically spins up
4. Your analysis container processes the file
5. Results are saved to the `analysis-results` container
6. Job terminates (zero cost when idle)

## Monitoring

View logs in Azure Portal:
- Navigate to the Log Analytics workspace
- Run KQL queries to analyze job executions
- Monitor costs, performance, and failures

## Security Features

- ✅ Managed identity for ACR authentication
- ✅ Private container registry
- ✅ Secrets stored encrypted in Container Apps
- ✅ No public blob access
- ✅ Infrastructure as Code for audit trail

## Cost Optimization

- **Scale to zero**: No cost when no files are being processed
- **Per-second billing**: Only pay for actual execution time
- **Basic tier resources**: ACR and Storage use cost-effective tiers
- **Automatic cleanup**: Jobs terminate after processing

## License

MIT
