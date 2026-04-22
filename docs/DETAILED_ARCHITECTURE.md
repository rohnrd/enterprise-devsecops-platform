# Enterprise DevSecOps Platform — Detailed Architecture

This document explains the platform design, pipeline flow, components, responsibilities, and operational guidance. It is structured for quick navigation and practical use by platform engineers and reviewers.

## Index

- [Goal](#goal)
- [High-level flow](#high-level-flow)
- [Step-by-step explanation](#step-by-step-explanation)
- [Components and responsibilities](#components-and-responsibilities)
- [Failure modes and handling](#failure-modes-and-handling)
- [Policy-as-code approach](#policy-as-code-approach)
- [GitOps strategy (ArgoCD)](#gitops-strategy-argocd)
- [Observability and post-deploy checks](#observability-and-post-deploy-checks)

## Goal

- Provide a secure, repeatable CI/CD pipeline that shifts security left and enforces policy-as-code before deployment.
- Use GitOps (ArgoCD) for runtime deployments so clusters accept only reviewed, policy-validated manifests.

## High-level flow

Code Commit → Pipeline Trigger → SAST Scan → SCA Scan → Build Artifact → Container Build → Container Scan → IaC Scan → Policy Check → Approval Gate → Deploy via ArgoCD

For a rendered diagram see `architecture/devsecops-flow.mmd` (Mermaid source). You can export it to SVG/PNG with `mmdc` (instructions below).

## Step-by-step explanation

### Code commit

- Developers push changes to feature branches or open pull requests (PRs).
- Keep PRs small and focused — they are easier to review and secure.

### Pipeline trigger

- The CI system (Azure DevOps or GitHub Actions) triggers on push/PR events.
- Recommended pattern: run quick checks on PRs (lint, unit tests, fast SAST) and full scans on merges to `main`.

### SAST scan

- Static Application Security Testing analyzes source code for security issues (SQLi, XSS, injection, etc.).
- Recommended tools: Semgrep, CodeQL, SonarQube.
- Practical tip: tune rules to your codebase to avoid noise; fail on clear high-severity findings.

### SCA scan

- Software Composition Analysis detects vulnerable third-party dependencies.
- Recommended tools: Dependabot, Snyk, Trivy (for dependency scanning), OWASP Dependency-Check.
- Policy: block on critical/known-exploitable CVEs; track and remediate medium/low severity findings.

### Build artifact

- Build and package the application artifact (jar, wheel, npm package, etc.).
- Store artifacts in a secure repository (Azure Artifacts, GitHub Packages, Nexus).

### Container build

- Build container images using multi-stage Dockerfiles and pinned base images.
- Tag images with immutable identifiers (CI build ID, SHA) and push to a private registry.

### Container scan

- Scan images for CVEs and misconfigurations.
- Recommended tools: Trivy, Clair, Aqua, Prisma Cloud.
- Block deployment on critical image vulnerabilities; create issues for lower-severity findings.

### IaC scan

- Scan Terraform/ARM/Bicep for insecure patterns (open ports, missing encryption, excessive privileges).
- Recommended tools: Checkov, tfsec, terrascan.
- Run these checks on PRs that modify infrastructure.

### Policy check (policy-as-code)

- Evaluate OPA (Rego) or Azure Policy rules against manifests and artifacts.
- Store policies in `policies/` and include clear remediation messages.
- On policy violations, block promotion and surface the failing rule and remediation advice.

### Approval gate

- Require manual approval for production deployments; lower environments can use automated gates.
- Record approver identity, timestamp, and comments for auditability.

### Deploy via ArgoCD (GitOps)

- Push validated manifests to the GitOps repo; ArgoCD reconciles the desired state with the cluster.
- Configure ArgoCD with RBAC, health checks, and sync waves for ordered deployments.

## Components and responsibilities

- **Developer** — write, test locally, and open PRs.
- **Source repo** — holds application code, pipeline definitions, and GitOps manifests.
- **CI/CD** — builds, runs scanners, and publishes artifacts.
- **Security tools** — SAST, SCA, container, and IaC scanners.
- **Policy engine** — OPA/Azure Policy enforcing governance rules.
- **Approvers** — gate production releases.
- **ArgoCD** — deploys and reconciles cluster state.
- **Kubernetes** — runtime environment.
- **Observability** — Prometheus/Grafana/Loki/ELK for metrics, dashboards, and logs.

## Failure modes and handling

- **Scan failures** — block the pipeline; attach scanner output and create tracking issues.
- **Policy failures** — block promotion and provide the failing rule and remediation steps.
- **Flaky tests** — isolate and fix; do not bypass security gates because of flaky tests.

## Policy-as-code approach

- Keep policies in `policies/` as Rego modules; version them and test in CI.
- Include explanatory comments and suggested fixes in policy output.

## GitOps strategy (ArgoCD)

- Prefer a separate GitOps repository for manifests.
- ArgoCD continuously watches the repo and syncs to clusters.
- Consider image automation tools with manual approval for production images.

## Observability and post-deploy checks

- Use readiness/liveness probes and configure alerts for abnormal behavior.
- Export metrics to Prometheus and create Grafana dashboards.
- Aggregate logs with Loki/ELK and configure security/availability alerts.

## Author's note

I, Rajamohan Rajendranb, prepared and reviewed this document to capture the intended DevSecOps platform design and operational guidance. Please review and update any environment-specific details (registry names, CI variables, contact lists) before publishing.

## Author

Rajamohan Rajendranb

