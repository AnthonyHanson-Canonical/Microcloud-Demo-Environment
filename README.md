# MicroCloud Demo Environment Setup

Two scripts that provision a self-contained MicroCloud demo environment on a single Ubuntu laptop using nested LXD virtualization. Creates a host VM (`microcloud-demo`, 4 CPU / 10 GiB RAM) inside which four Ubuntu 24.04 VMs (`micro1`–`micro4`, 2 CPU / 2 GiB RAM each) are provisioned to simulate bare metal servers. Each VM is attached to a dedicated ZFS-backed block volume for local storage (4 × 10 GiB); three nodes additionally receive a remote block volume (3 × 20 GiB) for Ceph HA. All four VMs are connected to a LXD bridge (`lxdbr0`) for external connectivity and a second isolated bridge (`microbr0`) with no IP assignment for MicroCloud's internal underlay network. The scripts bring you to the point where snap installation and `microcloud init` can be performed live as part of the demo.

## Requirements

- Ubuntu laptop with LXD installed (`snap install lxd`)
- ~50 GiB free disk space
- ~12 GiB RAM available while demo is running (zero when stopped)

## Usage

### Step 1 — On your laptop

```bash
chmod +x 01_create_host_vm.sh
./01_create_host_vm.sh
```

### Step 2 — Push the setup script into the VM

```bash
lxc file push 02_setup_environment.sh microcloud-demo/root/02_setup_environment.sh
```

### Step 3 — Inside the VM

```bash
lxc exec microcloud-demo -- bash /root/02_setup_environment.sh
```

Takes about 5–10 minutes. When it finishes, micro1–4 are running and ready for the demo.

### Step 4 — Live demo starts here

Shell into each VM and install the snaps:

```bash
lxc exec microcloud-demo -- lxc exec micro1 -- bash
snap install microcloud --channel 2/stable
snap install microceph --channel squid/stable
snap install microovn --channel 24.03/stable
```

Repeat for micro2, micro3, micro4. Then configure netplan on each and run:

```bash
microcloud init
```

## Stopping and resuming

```bash
# Free all RAM, keep disk state
lxc stop microcloud-demo

# Resume later
lxc start microcloud-demo
```

## Full teardown

```bash
lxc stop microcloud-demo
lxc delete microcloud-demo
```
