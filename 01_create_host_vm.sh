#!/bin/bash
# =============================================================================
# 01_create_host_vm.sh
# Run this on YOUR LAPTOP to create the microcloud-demo host VM.
# =============================================================================

set -e

echo "==> Creating microcloud-demo VM..."
lxc init ubuntu:24.04 microcloud-demo --vm \
  --config limits.cpu=4 \
  --config limits.memory=10GiB

echo "==> Resizing root disk to 200GiB..."
lxc config device override microcloud-demo root size=200GiB

echo "==> Starting VM..."
lxc start microcloud-demo

echo "==> Waiting for VM agent to become available..."
for i in $(seq 1 24); do
  if lxc exec microcloud-demo -- true 2>/dev/null; then
    echo "==> VM is ready!"
    break
  fi
  echo "    ...waiting (${i}/24)"
  sleep 5
done

echo ""
echo "==> Host VM is up. Next steps:"
echo ""
echo "    1. Copy the setup script into the VM:"
echo "       lxc file push 02_setup_environment.sh microcloud-demo/root/02_setup_environment.sh"
echo ""
echo "    2. Run it inside the VM:"
echo "       lxc exec microcloud-demo -- bash /root/02_setup_environment.sh"
