# modules/runner/scripts/install_cgpu.sh
#!/usr/bin/env bash
set -eux
FLAG_DIR=/var/lib/cgpu
mkdir -p "$FLAG_DIR"

if [ ! -f "$FLAG_DIR/step0.done" ]; then
  cd /tmp
  wget https://github.com/Azure/az-cgpu-onboarding/releases/download/V3.2.2/cgpu-onboarding-package.tar.gz
  tar -xzf cgpu-onboarding-package.tar.gz
  cd cgpu-onboarding-package
  bash step-0-prepare-kernel.sh
  touch "$FLAG_DIR/step0.done"
  reboot
  exit 0
fi
