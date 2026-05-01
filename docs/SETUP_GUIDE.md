# Enterprise DevSecOps Platform — Complete Setup Guide

This guide walks you through every step needed to run this showcase project from scratch — including Azure account creation, SonarQube, Nexus, GitHub configuration, infrastructure provisioning, and triggering the pipeline. Follow steps in order.

## Table of contents

- [Prerequisites overview](#prerequisites-overview)
- [Step 1 — Create a free Azure account](#step-1--create-a-free-azure-account)
- [Step 2 — Install required tools locally](#step-2--install-required-tools-locally)
- [Step 3 — Fork and clone this repository](#step-3--fork-and-clone-this-repository)
- [Step 4 — Set up SonarQube](#step-4--set-up-sonarqube)
- [Step 5 — Set up Nexus artifact repository](#step-5--set-up-nexus-artifact-repository)
- [Step 6 — Provision Azure infrastructure with Terraform](#step-6--provision-azure-infrastructure-with-terraform)
- [Step 7 — Configure GitHub repository secrets and variables](#step-7--configure-github-repository-secrets-and-variables)
  - [Create the GHCR\_TOKEN (GitHub Personal Access Token)](#create-the-ghcr_token-github-personal-access-token)
- [Step 8 — Configure branch protection rules](#step-8--configure-branch-protection-rules)
- [Step 9 — Run the pipeline and observe output](#step-9--run-the-pipeline-and-observe-output)
- [Step 10 — Verify ArgoCD deployment](#step-10--verify-argocd-deployment)
- [Step 11 — Validate locally (without cloud)](#step-11--validate-locally-without-cloud)
- [Expected outputs at each stage](#expected-outputs-at-each-stage)
- [Troubleshooting common errors](#troubleshooting-common-errors)
- [Author](#author)

---

## Prerequisites overview

Before starting, you will need the following accounts and tools. Each is set up in the steps below.

| Requirement | Used for | Free tier available |
|---|---|---|
| Azure account | Infra deployment (VMs, Container Apps, Key Vault) | Yes — $200 credit for 30 days |
| GitHub account | Source control, Actions CI/CD | Yes |
| Docker Desktop | Running SonarQube and Nexus locally | Yes |
| Node.js 18+ | Building the sample app locally | Yes |
| Terraform 1.6+ | Provisioning Azure infrastructure | Yes |
| Git | Cloning and committing | Yes |

---

## Step 1 — Create a free Azure account

1. Open your browser and go to <https://azure.microsoft.com/free>
2. Click **Start free** and sign in with a Microsoft account (or create one).
3. Complete the identity verification (phone number required).
4. Enter a credit card for identity only — you will not be charged during the free trial period.
5. Once signed in, you should land on the Azure Portal at <https://portal.azure.com>

**Note the following values — you will need them later:**

- Subscription ID — find it at: Portal → Subscriptions → copy the Subscription ID
- Tenant ID — find it at: Portal → Azure Active Directory → Overview → Tenant ID

### Create an Azure service principal for Terraform and OIDC

Run these commands in a terminal where the Azure CLI is installed (install from <https://learn.microsoft.com/cli/azure/install-azure-cli>):

```bash
# Login
az login

# Create a service principal with Contributor role on your subscription
az ad sp create-for-rbac \
  --name "devsecops-github-oidc" \
  --role Contributor \
  --scopes /subscriptions/<YOUR_SUBSCRIPTION_ID> \
  --sdk-auth
```

Save the JSON output — it contains `clientId`, `clientSecret`, `tenantId`, and `subscriptionId`.

### Add federated credentials for OIDC (passwordless GitHub Actions login)

```bash
# Get the service principal App ID (clientId from the JSON above)
CLIENT_ID="<clientId from output>"
TENANT_ID="<tenantId from output>"
SUBSCRIPTION_ID="<subscriptionId from output>"

# Add federated credential for main branch
az ad app federated-credential create \
  --id "$CLIENT_ID" \
  --parameters '{
    "name": "github-main",
    "issuer": "https://token.actions.githubusercontent.com",
    "subject": "repo:<YOUR_GITHUB_USERNAME>/enterprise-devsecops-platform:ref:refs/heads/main",
    "audiences": ["api://AzureADTokenExchange"]
  }'

# Add federated credential for develop branch
az ad app federated-credential create \
  --id "$CLIENT_ID" \
  --parameters '{
    "name": "github-develop",
    "issuer": "https://token.actions.githubusercontent.com",
    "subject": "repo:<YOUR_GITHUB_USERNAME>/enterprise-devsecops-platform:ref:refs/heads/develop",
    "audiences": ["api://AzureADTokenExchange"]
  }'
```

These credentials are used in the pipeline for the `azure-auth` job — no client secret stored in GitHub.

---

## Step 2 — Install required tools locally

Run each install command on your Mac or Linux machine.

### Azure CLI

```bash
brew install azure-cli
az version
```

### Terraform

```bash
brew tap hashicorp/tap
brew install hashicorp/tap/terraform
terraform version
```

### Node.js 18

```bash
brew install node@18
node --version
npm --version
```

### Docker Desktop

Download and install from <https://www.docker.com/products/docker-desktop/>

Then verify:

```bash
docker version
```

### Git

```bash
brew install git
git --version
```

---

## Step 3 — Fork and clone this repository

1. Go to <https://github.com/rohnrd/enterprise-devsecops-platform>
2. Click **Fork** (top right) → select your own GitHub account.
3. Clone your fork locally:

```bash
git clone https://github.com/<YOUR_GITHUB_USERNAME>/enterprise-devsecops-platform.git
cd enterprise-devsecops-platform
```

4. Create the `develop` branch:

```bash
git checkout -b develop
git push origin develop
```

---

## Step 4 — Set up SonarQube

SonarQube performs SAST (Static Application Security Testing) on the source code. You can run it locally with Docker.

### Start SonarQube locally

```bash
docker run -d \
  --name sonarqube \
  -p 9000:9000 \
  sonarqube:community
```

Wait about 60 seconds, then open <http://localhost:9000> in your browser.

Default credentials:
- Username: `admin`
- Password: `admin`

You will be prompted to change the password on first login. Choose a secure password.

### Create a SonarQube project

1. Click **Create Project** → **Manually**
2. Set **Project display name**: `Enterprise DevSecOps Platform`
3. Set **Project key**: `enterprise-devsecops-platform` (must match the value in `sonar-project.properties`)
4. Set **Main branch name**: `main`
5. Click **Set up**
6. On the next screen choose **With GitHub Actions**
7. Under **Configure Analysis** → choose **Other (for JS, TS, Go, Python, PHP, ...)**
8. On the token step, click **Generate a token**
9. Name it `github-actions`, leave type as **Global Analysis Token**, expiry as **No expiration** (or 365 days), click **Generate**
10. A token is shown **once only** — copy it immediately. It looks like `sqp_xxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxx`

This token is your `SONAR_TOKEN` secret. Save it somewhere safe before closing the modal.

### Get the SonarQube host URL

If running locally, the URL is `http://host.docker.internal:9000` (accessible from inside Docker) or `http://localhost:9000` from your machine.

For the pipeline to reach SonarQube from GitHub Actions (which runs on GitHub's cloud), you need to expose it externally using one of:

- **Option A — ngrok (easiest for showcase/demo):**

```bash
brew install ngrok
ngrok http 9000
```

ngrok will give you a public URL like `https://abc123.ngrok.io`. Use that as `SONAR_HOST_URL`.

- **Option B — Azure VM (production):** Deploy SonarQube on the runner VM or a separate VM in Azure. For a showcase, ngrok is sufficient.

---

## Step 5 — Set up Nexus artifact repository

Nexus stores the compiled application artifact (.tgz) separate from the container image.

### Start Nexus locally

```bash
docker run -d \
  --name nexus \
  -p 8081:8081 \
  -v nexus-data:/nexus-data \
  sonatype/nexus3
```

Wait 1-2 minutes for startup, then open <http://localhost:8081>

### Get the admin password

```bash
docker exec nexus cat /nexus-data/admin.password
```

Login with `admin` and the password above, then set a new password when prompted.

### Create the artifact repository

1. Go to **Settings** (gear icon) → **Repositories** → **Create repository**
2. Choose **raw (hosted)**
3. Set name: `devsecops-artifacts`
4. Deployment policy: `Allow redeploy`
5. Click **Create repository**

### Test upload manually (optional)

```bash
# From the repo root
mkdir -p artifact
tar --exclude='node_modules' --exclude='npm-debug.log' \
    -czf artifact/enterprise-devsecops-platform-local.tgz \
    -C sample-app .

curl -u admin:<YOUR_NEXUS_PASSWORD> \
  --upload-file artifact/enterprise-devsecops-platform-local.tgz \
  http://localhost:8081/repository/devsecops-artifacts/builds/enterprise-devsecops-platform-local.tgz
```

A `201 Created` response confirms it worked.

---

## Step 6 — Provision Azure infrastructure with Terraform

This creates the VNet, subnets, Nexus VM, GitHub runner VM, Container Apps environment, and Log Analytics workspace.

### Prepare your SSH key

```bash
# If you don't have one yet
ssh-keygen -t rsa -b 4096 -f ~/.ssh/id_rsa
cat ~/.ssh/id_rsa.pub   # Copy this — Terraform will use it to set up VM access
```

### Find your public IP for SSH access

```bash
curl -s https://api.ipify.org
```

This will be the value of `allowed_source_ip` (add `/32` at the end, e.g. `203.0.113.55/32`).

### Create a Terraform variables file

```bash
cat > terraform/terraform.tfvars <<EOF
allowed_source_ip    = "<YOUR_PUBLIC_IP>/32"
github_runner_token  = "<RUNNER_REGISTRATION_TOKEN>"
EOF
```

**Get the GitHub runner registration token:**

1. Go to your fork on GitHub → Settings → Actions → Runners → New self-hosted runner
2. Copy the token shown in the `--token` line (looks like `AXXXXXXXXX...`)

### Run Terraform

```bash
cd terraform

# Login to Azure
az login

# Initialise Terraform
terraform init

# Preview what will be created
terraform plan

# Apply — this creates all Azure resources (takes about 5 minutes)
terraform apply -auto-approve
```

Outputs you will see:

```
nexus_private_url     = "http://10.20.1.10:8081"
runner_public_ip      = "xx.xx.xx.xx"
runner_ssh_command    = "ssh azureuser@xx.xx.xx.xx"
container_app_url     = "ca-devsecops-sample-app.<region>.azurecontainerapps.io"
```

Save these values.

---

## Step 7 — Configure GitHub repository secrets and variables

In your GitHub fork, go to **Settings → Secrets and variables → Actions**.

### Create the GHCR_TOKEN (GitHub Personal Access Token)

The pipeline needs a token to push Docker images to GitHub Container Registry (GHCR).

1. Go to <https://github.com/settings/tokens> — click **Generate new token (classic)**
2. Give it a name: `devsecops-ghcr-push`
3. Set **Expiration**: choose `90 days` or `No expiration` for a permanent showcase token
4. Under **Select scopes**, tick the following:
   - `write:packages` — push images to GHCR
   - `read:packages` — pull images
   - `delete:packages` — optional, allows cleanup
5. Click **Generate token** at the bottom of the page
6. The token is shown **once only** — copy it immediately. It looks like `ghp_xxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxx`

This token is your `GHCR_TOKEN` secret.

### Secrets (sensitive — never visible after saving)

| Secret name | Value | Where to get it |
|---|---|---|
| `SONAR_TOKEN` | Your SonarQube analysis token | Step 4 — token starting with `sqp_` |
| `SONAR_HOST_URL` | Your SonarQube URL | Step 4 — ngrok or VM URL, no trailing slash |
| `GHCR_TOKEN` | GitHub personal access token | Section above — token starting with `ghp_` |

### Variables (visible — non-sensitive)

| Variable name | Value | Where to get it |
|---|---|---|
| `AZURE_CLIENT_ID` | Service principal client ID | Step 1 — from `az ad sp create-for-rbac` output |
| `AZURE_TENANT_ID` | Azure tenant ID | Step 1 — from portal or CLI output |
| `AZURE_SUBSCRIPTION_ID` | Azure subscription ID | Step 1 — from portal → Subscriptions |

### How to add a secret

1. Go to your repo → **Settings** → **Secrets and variables** → **Actions**
2. Click the **Secrets** tab → click **New repository secret**
3. Enter the name exactly as shown in the table (e.g. `SONAR_TOKEN`) — names are case-sensitive
4. Paste the token value
5. Click **Add secret**

Repeat for each of the three secrets.

### How to add a variable

1. Stay on the same page → click the **Variables** tab
2. Click **New repository variable**
3. Enter the name exactly as shown (e.g. `AZURE_CLIENT_ID`)
4. Paste the value
5. Click **Add variable**

Repeat for all three variables.

### Verify all secrets and variables are set

After adding everything, your **Secrets** tab should show:

```
GHCR_TOKEN        Updated just now
SONAR_HOST_URL    Updated just now
SONAR_TOKEN       Updated just now
```

And your **Variables** tab should show:

```
AZURE_CLIENT_ID        Updated just now
AZURE_SUBSCRIPTION_ID  Updated just now
AZURE_TENANT_ID        Updated just now
```

If any are missing, the corresponding pipeline job will fail with an authentication error.

---

## Step 8 — Configure branch protection rules

Protect `main` and `develop` to ensure the pipeline must pass before merging.

1. Go to your repo → **Settings** → **Branches**
2. Click **Add rule** next to `main`
3. Enable:
   - Require status checks to pass before merging
   - Require branches to be up to date
   - Select the CI jobs from the pipeline as required checks
4. Repeat for `develop`

---

## Step 9 — Run the pipeline and observe output

### Trigger the pipeline

Push any change to `main` or `develop`:

```bash
# From the repo root
echo "# trigger" >> README.md
git add README.md
git commit -m "Trigger DevSecOps pipeline"
git push origin main
```

Go to your GitHub repo → **Actions** tab.

You should see a new run called **DevSecOps CI/CD Pipeline** start immediately.

### What you should see at each job

**Job 1 — Build, Version, SAST and Artifact**

```
✓ Checkout
✓ Generate Build Version        → version = 1.x or 1.x-beta
✓ SonarQube Scan                → posts code analysis to SonarQube
✓ Build Node.js app             → npm install in sample-app/
✓ Package artifact as .tgz      → artifact/enterprise-devsecops-platform-1.x.tgz
✓ Create build metadata         → artifact/build-info.txt
✓ Upload artifact               → stored in GitHub Actions run artifacts
```

After this job finishes, go to SonarQube at your URL → you should see the project with analysis results and a quality gate result.

**Job 2 — SCA, Docker Build, GHCR Push and Image Scan**

```
✓ Checkout
✓ Install Trivy
✓ Trivy filesystem scan         → scans dependencies; fails on HIGH/CRITICAL CVEs
✓ Build Docker image            → ghcr.io/<user>/enterprise-devsecops-platform:1.x
✓ Login to GHCR
✓ Push Docker image             → image pushed to GitHub Container Registry
✓ Trivy image scan              → scans pushed image; fails on HIGH/CRITICAL CVEs
```

To view the pushed image: go to your GitHub profile → **Packages** → `enterprise-devsecops-platform`.

**Job 3 — Azure OIDC Login**

```
✓ Azure Login using OIDC        → logs in without a stored client secret
✓ Verify Azure Login            → shows account info
```

**Job 4 — GitOps Manifest Update**

```
✓ Checkout repo
✓ Update deployment image       → replaces image tag in gitops/manifests/deployment.yaml
✓ Commit and push GitOps change → commits directly to main with the new image tag
```

After this step, check `gitops/manifests/deployment.yaml` in your repo — the `image:` line should have the new version tag.

### View artifacts

In the Actions run → scroll down to **Artifacts** section. You will find:

- `enterprise-devsecops-platform-1.x` — the `.tgz` build artifact and `build-info.txt`

---

## Step 10 — Verify ArgoCD deployment

If you are running ArgoCD on a Kubernetes cluster (AKS, local kind, or minikube):

### Apply the ArgoCD Application manifest

```bash
kubectl apply -f gitops/argocd/application.yaml
```

### Check ArgoCD sync status

```bash
kubectl get application -n argocd enterprise-devsecops-platform
```

Expected output:

```
NAME                             SYNC STATUS   HEALTH STATUS
enterprise-devsecops-platform    Synced        Healthy
```

### Access the deployed app

```bash
kubectl port-forward svc/devsecops-app-service 8080:80 -n devsecops-platform
```

Open <http://localhost:8080> — you should see:

```json
{
  "message": "Enterprise DevSecOps Platform Running",
  "author": "Rajamohan",
  "status": "healthy"
}
```

Check health endpoint: <http://localhost:8080/health>

```json
{"status": "UP", "service": "DevSecOps Sample App"}
```

### If using Azure Container Apps (Terraform-provisioned)

After `terraform apply`, the app is deployed at the URL shown in `container_app_url` output:

```bash
curl https://<container_app_url>/health
```

---

## Step 11 — Validate locally (without cloud)

Use this to verify the sample app and OPA policies work before pushing to GitHub.

### Run the sample app locally

```bash
cd sample-app
npm install
npm start
```

Expected output:

```
🚀 App started by Rajamohan
Listening on port 3000
```

Test endpoints:

```bash
curl http://localhost:3000/
curl http://localhost:3000/health
curl http://localhost:3000/info
```

### Build and test the Docker image locally

```bash
cd sample-app
docker build -t devsecops-sample-app:local .
docker run -p 3000:3000 devsecops-sample-app:local
curl http://localhost:3000/health
```

### Run OPA policy tests locally

```bash
# Install OPA
brew install opa

# Run policy unit tests
opa test policies/ -v
```

Expected output:

```
data.devsecops.test_valid_deployment_no_deny: PASS
data.devsecops.test_latest_tag_denied: PASS
data.devsecops.test_no_limits_denied: PASS
data.devsecops.test_priv_escalation_denied: PASS

4 tests, 0 failures
```

### Run IaC scan locally (Checkov)

```bash
pip install checkov
checkov -d terraform/ --compact
```

### Run Trivy locally

```bash
brew install trivy

# Filesystem scan
trivy fs --scanners vuln --severity HIGH,CRITICAL .

# Image scan (after building locally)
trivy image devsecops-sample-app:local
```

### Run markdownlint

```bash
npx markdownlint README.md docs/*.md --config .markdownlint.json
```

---

## Expected outputs at each stage

| Stage | What you should see |
|---|---|
| SonarQube | Project analysis with code quality score and security issues (if any) at `http://localhost:9000` |
| Nexus | Artifact at `http://localhost:8081/repository/devsecops-artifacts/builds/` |
| GitHub Actions | Green pipeline run with all jobs passing under the Actions tab |
| GHCR | Container image listed under your GitHub account → Packages |
| GitOps repo | `gitops/manifests/deployment.yaml` updated with the new image tag |
| Kubernetes / Container Apps | App responding on `/`, `/health`, `/info` endpoints |

---

## Troubleshooting common errors

**SonarQube scan fails with "connection refused"**

The GitHub Actions runner cannot reach your local SonarQube. Use ngrok (`ngrok http 9000`) to expose it and update the `SONAR_HOST_URL` secret to the ngrok URL.

**Trivy fails with HIGH/CRITICAL CVEs**

Run `npm audit fix` in `sample-app/` to update vulnerable dependencies, then push again.

**Docker push to GHCR fails with "401 Unauthorized"**

Check that `GHCR_TOKEN` secret is set and the token has `write:packages` scope. Also ensure the token is not expired.

**Terraform fails with "authorization required"**

Run `az login` again in your terminal and retry `terraform apply`.

**`git push` in GitOps step fails with "permission denied"**

The workflow needs `contents: write` permission (already set in the pipeline) and the default `GITHUB_TOKEN` must have write access. Check repo Settings → Actions → General → Workflow permissions → set to "Read and write permissions".

**OPA test fails locally**

Ensure OPA is installed with `brew install opa` and you are running `opa test policies/ -v` from the repository root.

---

## Author

Rajamohan Rajendran — DevSecOps Architect | Platform Engineering | Cloud Security
