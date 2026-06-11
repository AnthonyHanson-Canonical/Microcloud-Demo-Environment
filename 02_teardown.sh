#!/bin/bash
# =============================================================================
# 02_teardown.sh
# Run this on YOUR LAPTOP to completely remove the microcloud-demo environment.
# =============================================================================

set -e

PROJECT="microcloud-demo"

echo "==> Switching to project $PROJECT..."
lxc project switch $PROJECT 2>/dev/null || {
  echo "Project $PROJECT not found, nothing to tear down."
  exit 0
}

echo "==> Stopping all VMs..."
for vm in micro1 micro2 micro3 micro4; do
  lxc stop $vm --force 2>/dev/null && echo "    Stopped $vm" || echo "    $vm already stopped"
done

echo "==> Deleting all VMs..."
for vm in micro1 micro2 micro3 micro4; do
  lxc delete $vm 2>/dev/null && echo "    Deleted $vm" || echo "    $vm already gone"
done

echo "==> Deleting storage volumes..."
for vol in local1 local2 local3 local4 remote1 remote2 remote3; do
  lxc storage volume delete disks $vol 2>/dev/null && echo "    Deleted $vol" || echo "    $vol already gone"
done

echo "==> Deleting storage pool..."
lxc storage delete disks 2>/dev/null || echo "    Storage pool already gone"

echo "==> Deleting network..."
lxc network delete microbr0 2>/dev/null || echo "    Network already gone"

echo "==> Switching back to default project..."
lxc project switch default

echo "==> Deleting project $PROJECT..."
lxc project delete $PROJECT 2>/dev/null || echo "    Project already gone"

echo ""
echo "============================================================"
echo " Teardown complete. All microcloud-demo resources removed."
echo "============================================================"
