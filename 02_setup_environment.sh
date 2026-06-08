#!/bin/bash
# =============================================================================
# 02_setup_environment.sh
# Run this INSIDE the microcloud-demo VM.
# Sets up LXD, storage, networking, and 4 micro VMs ready for snap installs
# and microcloud init as part of a live demo.
# =============================================================================

set -e

# --- Install LXD ---
echo "==> Installing LXD..."
snap install lxd
export PATH=$PATH:/snap/bin

echo "==> Initialising LXD with minimal defaults..."
lxd init --minimal

# --- Storage ---
echo "==> Creating ZFS storage pool (100GiB)..."
lxc storage create disks zfs size=100GiB

echo "==> Setting default volume size to 10GiB..."
lxc storage set disks volume.size 10GiB

echo "==> Creating local storage volumes (one per cluster member)..."
lxc storage volume create disks local1 --type block
lxc storage volume create disks local2 --type block
lxc storage volume create disks local3 --type block
lxc storage volume create disks local4 --type block

echo "==> Creating remote storage volumes (for Ceph HA across 3 nodes)..."
lxc storage volume create disks remote1 --type block size=20GiB
lxc storage volume create disks remote2 --type block size=20GiB
lxc storage volume create disks remote3 --type block size=20GiB

# --- Networking ---
echo "==> Creating MicroCloud uplink bridge network..."
lxc network create microbr0

echo "==> Bridge network addresses (save these for microcloud init):"
echo "    IPv4: $(lxc network get microbr0 ipv4.address)"
echo "    IPv6: $(lxc network get microbr0 ipv6.address)"

# --- VMs ---
echo "==> Creating micro VMs (first one downloads the Ubuntu image, be patient)..."
lxc init ubuntu:24.04 micro1 --vm --config limits.cpu=2 --config limits.memory=2GiB
lxc init ubuntu:24.04 micro2 --vm --config limits.cpu=2 --config limits.memory=2GiB
lxc init ubuntu:24.04 micro3 --vm --config limits.cpu=2 --config limits.memory=2GiB
lxc init ubuntu:24.04 micro4 --vm --config limits.cpu=2 --config limits.memory=2GiB

echo "==> Attaching local disks..."
lxc storage volume attach disks local1 micro1
lxc storage volume attach disks local2 micro2
lxc storage volume attach disks local3 micro3
lxc storage volume attach disks local4 micro4

echo "==> Attaching remote disks to micro1, micro2, micro3..."
lxc storage volume attach disks remote1 micro1
lxc storage volume attach disks remote2 micro2
lxc storage volume attach disks remote3 micro3

echo "==> Adding MicroCloud network interface (eth1) to each VM..."
lxc config device add micro1 eth1 nic network=microbr0
lxc config device add micro2 eth1 nic network=microbr0
lxc config device add micro3 eth1 nic network=microbr0
lxc config device add micro4 eth1 nic network=microbr0

echo "==> Starting all 4 VMs..."
lxc start micro1
lxc start micro2
lxc start micro3
lxc start micro4

echo "==> Waiting for all VMs to become available..."
for vm in micro1 micro2 micro3 micro4; do
  echo "    Waiting for $vm..."
  for i in $(seq 1 24); do
    if lxc exec $vm -- true 2>/dev/null; then
      echo "    $vm is ready!"
      break
    fi
    sleep 5
  done
done

# --- Final status ---
echo ""
echo "============================================================"
echo " Environment is ready!"
echo "============================================================"
echo ""
lxc list
echo ""
echo "microbr0 addresses (needed during microcloud init):"
echo "    IPv4: $(lxc network get microbr0 ipv4.address)"
echo "    IPv6: $(lxc network get microbr0 ipv6.address)"
echo ""
echo "Next step — on each VM (micro1 through micro4), install the snaps:"
echo "    snap install microcloud --channel 2/stable"
echo "    snap install microceph --channel squid/stable"
echo "    snap install microovn --channel 24.03/stable"
echo ""
echo "Then configure netplan on each VM and run microcloud init on micro1."
