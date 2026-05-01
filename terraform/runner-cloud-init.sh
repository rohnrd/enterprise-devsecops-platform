#!/bin/bash
set -e

RUNNER_USER="githubrunner"
RUNNER_VERSION="2.328.0"
RUNNER_DIR="/home/${RUNNER_USER}/actions-runner"

apt-get update -y
apt-get install -y curl tar unzip git jq ca-certificates docker.io

systemctl enable docker
systemctl start docker

useradd -m -s /bin/bash ${RUNNER_USER}
usermod -aG docker ${RUNNER_USER}

mkdir -p ${RUNNER_DIR}
chown -R ${RUNNER_USER}:${RUNNER_USER} /home/${RUNNER_USER}

cd ${RUNNER_DIR}

curl -o actions-runner-linux-x64.tar.gz -L \
  https://github.com/actions/runner/releases/download/v${RUNNER_VERSION}/actions-runner-linux-x64-${RUNNER_VERSION}.tar.gz

tar xzf actions-runner-linux-x64.tar.gz
chown -R ${RUNNER_USER}:${RUNNER_USER} ${RUNNER_DIR}

sudo -u ${RUNNER_USER} ./config.sh \
  --url "${github_repo_url}" \
  --token "${github_runner_token}" \
  --name "azure-vnet-runner-rajamohan" \
  --labels "self-hosted,linux,azure,vnet,nexus" \
  --unattended \
  --replace

./svc.sh install ${RUNNER_USER}
./svc.sh start