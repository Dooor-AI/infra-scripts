# /azure/install_driver.sh
#!/usr/bin/env bash
set -eux
FLAG_DIR=/var/lib/cgpu

if [ ! -f "$FLAG_DIR/step1.done" ]; then
  cd /tmp/cgpu-onboarding-package
  bash step-1-install-gpu-driver.sh
  touch "$FLAG_DIR/step1.done"
  reboot
  exit 0
fi
