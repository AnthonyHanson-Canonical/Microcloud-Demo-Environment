#!/bin/bash
# =============================================================================
# 01_create_environment.sh
# Run this on YOUR LAPTOP.
# Creates a dedicated LXD project and provisions 4 micro VMs directly on your
# machine, ready for snap installs and microcloud init.
# =============================================================================

set -e

export PATH=$PATH:/snap/bin

PROJECT="microcloud-demo"

echo "==> Creating LXD project: $PROJECT..."
lxc project create $PROJECT -c features.images=false -c features.profiles=false

echo "==> Switching to project $PROJECT..."
lxc project switch $PROJECT

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
lxc network create microbr0 --project $PROJECT

IPV4=$(lxc network get microbr0 ipv4.address --project $PROJECT)
IPV6=$(lxc network get microbr0 ipv6.address --project $PROJECT)

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
    if [ $i -eq 24 ]; then
      echo "    WARNING: $vm may not be ready, check manually before continuing"
    fi
    sleep 5
  done
done

# --- Configure netplan on each VM ---
echo "==> Configuring MicroCloud network interface on each VM..."

for vm in micro1 micro2 micro3 micro4; do
  echo "    Configuring netplan on $vm..."
  lxc exec $vm -- bash -c "cat > /etc/netplan/99-microcloud.yaml << 'NETPLAN'
network:
    version: 2
    ethernets:
        enp6s0:
            accept-ra: false
            dhcp4: false
            link-local: []
NETPLAN
chmod 0600 /etc/netplan/99-microcloud.yaml
netplan apply"
done

# --- Install snaps on each VM ---
# MicroCloud needs LXD installed and running but NOT initialized.
# Do NOT run lxd init here — microcloud init handles that.
echo "==> Installing MicroCloud snaps on all 4 VMs (runs in parallel)..."

for vm in micro1 micro2 micro3 micro4; do
  echo "    Installing snaps on $vm..."
  lxc exec $vm -- bash -c "
    snap install microcloud --channel 2/stable
    snap install microceph --channel squid/stable
    snap install microovn --channel 24.03/stable
  " &
done

echo "==> Waiting for snap installs to complete (this takes a few minutes)..."
wait
echo "==> Snaps installed on all VMs!"

# --- Wait for LXD daemon to be ready on each VM ---
# snap install returns before the LXD daemon is ready.
# Poll until it responds so microcloud init doesn't timeout.
echo "==> Waiting for LXD daemon to be ready on each VM..."

for vm in micro1 micro2 micro3 micro4; do
  echo "    Waiting for LXD on $vm..."
  for i in $(seq 1 24); do
    if lxc exec $vm -- lxc list > /dev/null 2>&1; then
      echo "    LXD ready on $vm!"
      break
    fi
    if [ $i -eq 24 ]; then
      echo "    WARNING: LXD on $vm may not be ready, check manually before continuing"
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
echo "microbr0 network addresses:"
echo "    IPv4: $IPV4"
echo "    IPv6: $IPV6"
echo ""
echo "You will need these during microcloud init when asked to"
echo "configure the uplink network. Note them down now."
echo ""
echo "Next step — shell into micro1 and bootstrap the cluster:"
echo "    lxc exec micro1 -- bash"
echo "    microcloud init"
echo ""
echo "The LXD UI will be accessible at:"
echo "    https://$(echo $IPV4 | cut -d'/' -f1 | sed 's/\.1$/.116/'):8443"
echo "    (exact IP may vary — check lxc list for micro1's address)"
echo "============================================================"
