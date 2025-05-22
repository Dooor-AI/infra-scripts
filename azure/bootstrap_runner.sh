# modules/runner/scripts/bootstrap_runner.sh
#!/usr/bin/env bash
set -eux
FLAG_DIR=/var/lib/cgpu

if [ ! -f "$FLAG_DIR/step2.done" ]; then
  cd /tmp/cgpu-onboarding-package
  bash step-3-install-gpu-tools.sh
  touch "$FLAG_DIR/step2.done"
fi

apt-get update
apt-get install -y curl git jq libicu-dev libkrb5-dev libssl-dev libffi-dev docker.io

RUNNER_HOME=/home/${ADMIN_USERNAME}/actions-runner
mkdir -p "$RUNNER_HOME" && cd "$RUNNER_HOME"
RUNNER_VERSION=$(curl -s https://api.github.com/repos/actions/runner/releases/latest | jq -r .tag_name)
curl -fsSL -o actions-runner.tar.gz \
  "https://github.com/actions/runner/releases/download/${RUNNER_VERSION}/actions-runner-linux-x64-${RUNNER_VERSION}.tar.gz"
tar xzf actions-runner.tar.gz

./config.sh --unattended \
  --url https://github.com/Dooor-AI/ml-service \
  --token "${RUNNER_TOKEN}" \
  --name "${HOSTNAME}" \
  --labels "self-hosted","gpu"
./svc.sh install
./svc.sh start
