# Nexus Artifact Repository Setup

## Purpose

I added Nexus Repository Manager to this DevSecOps showcase to demonstrate how build artifacts are stored and managed in an enterprise-style artifact repository.

In real projects, build artifacts should not be stored directly in Git because Git is meant for source code, not binary packages. Tools like Nexus, JFrog Artifactory, or Azure Artifacts are used to store, version, secure, and retrieve build outputs.

For this project, I used Nexus OSS to store the packaged `.tgz` artifact generated from the sample Node.js application.

## Why Nexus Was Added

The pipeline already builds a Docker image and pushes it to GitHub Container Registry. However, Docker images are only one type of artifact.

A proper DevSecOps platform should also handle build artifacts separately.

Examples of build artifacts:

- `.tgz`
- `.zip`
- `.jar`
- `.war`
- npm packages
- release bundles

## Nexus Container Setup

```bash
docker run -d   --name nexus   -p 8081:8081   -v nexus-data:/nexus-data   sonatype/nexus3
```

## Verify Nexus

```bash
docker ps --filter name=nexus
```

## Get Admin Password

```bash
docker exec -it nexus cat /nexus-data/admin.password
```

## Create Repository

- Type: raw (hosted)
- Name: devsecops-artifacts
- Deployment policy: Allow redeploy

## Create Artifact

```bash
mkdir -p artifact && tar   --exclude='node_modules'   --exclude='npm-debug.log'   -czf artifact/enterprise-devsecops-platform-local.tgz   -C sample-app .
```

## Upload Artifact

```bash
curl -u admin:<password>   --upload-file artifact/enterprise-devsecops-platform-local.tgz   http://localhost:8081/repository/devsecops-artifacts/builds/enterprise-devsecops-platform-local.tgz
```

## Summary

- Nexus setup completed
- Artifact repository created
- Artifact successfully uploaded
- Ready for CI/CD integration
