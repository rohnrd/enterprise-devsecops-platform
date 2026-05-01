# Enterprise DevSecOps Platform

GitHub Actions + OIDC + Azure Key Vault + Nexus + Azure Container Apps + ArgoCD

This document describes a production-oriented DevSecOps platform design, the CI/CD pipeline, security controls, infrastructure layout, and operational guidance. It is intended for platform engineers, security reviewers, and SREs who will implement or operate the platform.

## Table of contents

- [Goal](#goal)
- [Scope](#scope)
- [High-level flow](#high-level-flow)
- [Detailed step-by-step pipeline](#detailed-step-by-step-pipeline)
- [Components and responsibilities](#components-and-responsibilities)
- [Azure infrastructure and networking](#azure-infrastructure-and-networking)
- [Security controls and policy-as-code](#security-controls-and-policy-as-code)
- [Artifact lifecycle and repositories](#artifact-lifecycle-and-repositories)
- [GitOps and ArgoCD deployment model](#gitops-and-argocd-deployment-model)
- [Observability and post-deploy validation](#observability-and-post-deploy-validation)
- [Release strategy and versioning](#release-strategy-and-versioning)
- [Operational runbook snippets](#operational-runbook-snippets)
- [How to render diagrams and validate docs locally](#how-to-render-diagrams-and-validate-docs-locally)
- [Files of interest in this repo](#files-of-interest-in-this-repo)
- [Author and sign-off](#author-and-sign-off)

## Goal

- Provide a secure, repeatable CI/CD pipeline that shifts security left and enforces policy-as-code prior to any deployment.
- Use GitOps for runtime delivery so clusters are reconciled only from a reviewed Git source of truth.

## Scope

This document covers the CI pipeline, security scanning stages, artifact management, GitOps deployment, and the Azure-based infrastructure to host build runners, artifact storage, and runtime.

It does not prescribe specific application code changes; instead it focuses on platform-level patterns and operational guidance.

## High-level flow

Developer → GitHub repo → CI (GitHub Actions) → SAST / SCA / IaC scans → Artifact storage (Nexus / GHCR) → Policy validation (OPA) → Approval gate → GitOps manifest update → ArgoCD sync → Azure Container Apps → Observability

## Detailed step-by-step pipeline

Each stage below describes intent, recommended tools, expected outputs, and failure handling.

### 1. Source control (developer actions)

- Developers work in feature branches and open PRs for review.
- Keep changes small and include clear descriptions and test notes in PRs.

Expected artifacts:
- PR with changes, unit tests, and pipeline configuration.

### 2. CI trigger and quick feedback

- On PR: run fast checks (lint, unit tests, lightweight SAST rules) to give early feedback.
- On merge to `develop`/`main`: run the full pipeline including heavy SAST, SCA, and IaC scans.

Recommended actions:
- Use required status checks in branch protection rules to enforce passing checks before merge.

### 3. Static Application Security Testing (SAST)

- Purpose: detect code-level vulnerabilities in the application.
- Tools: Semgrep for targeted rules, CodeQL for deep analysis, SonarQube for combined quality/security.
- Output: SARIF or HTML reports; fail the job on high-severity findings.

Failure handling:
- Block the pipeline on critical results; create a ticket for medium severity.

### 4. Software Composition Analysis (SCA)

- Purpose: detect vulnerable dependencies and transitive risks.
- Tools: Dependabot (automated PRs), Snyk, Trivy (vuln scanner), OWASP Dependency-Check.
- Output: Advisory report with CVE details and remediation guidance.

Policy:
- Block on critical/known-exploitable CVEs; allow tracked remediation for lower severities.

### 5. Build and artifact storage

- Build the artifact (jar, wheel, npm package) and store it in Nexus or a secured artifacts repository.
- Sign and checksum artifacts where feasible to provide traceability.

Outputs:
- Versioned artifact uploaded to Nexus (e.g., .tgz or package format).

### 6. Container image build and scan

- Build images using reproducible, multi-stage Dockerfiles. Pin base images and avoid untrusted `latest` tags.
- Tag images with immutable identifiers (CI build SHA).
- Push images to GHCR or another private registry.
- Scan images with Trivy (or a commercial scanner) and fail on critical CVEs.

### 7. Infrastructure-as-Code (IaC) scanning

- Scan Terraform/ARM/Bicep with Checkov, tfsec, or terrascan.
- Focus checks on networking, IAM, storage encryption, and resource exposure.

### 8. Policy-as-code validation

- Store Rego policies in `policies/` and run policy evaluation in CI (OPA).
- Block promotion when policies indicate non-compliance; include explicit remediation text in the output.

### 9. Approval gate

- For production deploys, require one or more human approvers via GitHub Environments or an external approval workflow.
- Record approver identity, timestamp, and reason for auditability.

### 10. GitOps manifest update and ArgoCD deploy

- After approvals, update the GitOps repo (or a path within this repo) with the new image tag and manifests.
- ArgoCD will detect the change and reconcile the cluster state.

Failure handling:
- ArgoCD health checks prevent unhealthy resources from being marked successful; monitor sync failures.

## Components and responsibilities

- Developers: author code, open PRs, respond to scan findings.
- Platform CI: orchestrates scans, builds, and artifact publishing.
- Security team: tune SAST/SCA rules, maintain policy-as-code.
- Platform SRE: operate Nexus, runners, ArgoCD, and monitoring.

## Azure infrastructure and networking

- VNet: `vnet-devsecops-platform` with isolated subnets for Nexus, runners, and container apps.
- Nexus: hosted on a VM with private IP and restricted access.
- Self-hosted runners: optional; run inside the VNet to access private Nexus and Key Vault.
- Azure Key Vault: store registry credentials and sensitive pipeline secrets; use OIDC where possible.

Network controls:
- NSGs to limit inbound/outbound traffic; private endpoints for Key Vault and container registry where supported.

## Security controls and policy-as-code

- No long-lived secrets in GitHub; use OIDC + Key Vault or short-lived tokens.
- Enforce branch protections, required checks, and signed commits for sensitive branches.
- Rego policies enforce resource constraints, labels, and security posture.

## Artifact lifecycle and repositories

- Nexus stores raw artifacts and packages; GHCR stores container images.
- Promote artifacts through environments by tagging and updating GitOps manifests.

## GitOps and ArgoCD deployment model

- Keep GitOps manifests in a dedicated repo or folder.
- Use automated image updates with manual approvals for production.
- Configure ArgoCD with RBAC and health checks; use ArgoCD ApplicationSets for multi-cluster.

## Observability and post-deploy validation

- Instrument apps with Prometheus metrics, Grafana dashboards, and Loki/ELK logs.
- Implement automated smoke tests and readiness probes as part of post-deploy validation.

## Release strategy and versioning

- `main` → stable releases (1.x). `develop` → pre-release / beta.
- Use semantic versioning and include CI build metadata in image tags.

## Operational runbook snippets

- Rollback: update GitOps manifest to previous image tag and let ArgoCD reconcile.
- Emergency patch: create a hotfix branch, run full pipeline, push manifest update to GitOps repo.
- Incident: collect artifacts (SARIF, Trivy report, Checkov output) and attach to incident ticket.

## How to render diagrams and validate docs locally

Run `markdownlint` locally:

```bash
npx markdownlint README.md docs/*.md --config .markdownlint.json
```

Render Mermaid diagrams (Mermaid CLI):

```bash
npm install -g @mermaid-js/mermaid-cli
mmdc -i architecture/devsecops-flow.mmd -o architecture/devsecops-flow.svg
```

## Files of interest in this repo

- `pipelines/github-actions.yml` — example CI pipeline
- `architecture/devsecops-flow.mmd` — Mermaid source for flow diagram
- `policies/` — policy-as-code (Rego) directory

## Author and sign-off

Author: Rajamohan Rajendran

Date: 2026-05-01

Notes: Review and localize registry names, Key Vault references, and environment-specific details before applying these patterns to production.

