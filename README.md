# MicroCloud Demo Environment

Two scripts that provision a self-contained MicroCloud demo environment directly on your Ubuntu laptop using LXD. Four Ubuntu 24.04 VMs (`micro1`–`micro4`, 2 CPU / 2 GiB RAM each) are created in a dedicated LXD project, simulating bare metal servers ready for MicroCloud bootstrapping. Each VM is attached to a ZFS-backed block volume for local storage (4 × 10 GiB); three nodes additionally receive a remote block volume (3 × 20 GiB) for Ceph HA. All four VMs are connected to a LXD bridge (`lxdbr0`) for external connectivity and a second isolated bridge (`microbr0`) with no IP assignment for MicroCloud's internal underlay network. MicroCloud, MicroCeph, and MicroOVN snaps are pre-installed on each node. Running the script brings you to the exact point where `microcloud init` on `micro1` bootstraps the full cluster.

## Requirements

- Ubuntu laptop with LXD installed (`snap install lxd` and `lxd init --minimal` already run)
- ~50 GiB free disk space
- ~12 GiB RAM available while demo is running (zero when stopped)

## Usage

### Set up the environment

```bash
chmod +x 01_create_environment.sh
./01_create_environment.sh
```

Takes about 5–10 minutes. When complete, the script prints the microbr0 IPv4 and IPv6 addresses you will need during `microcloud init`.

### Bootstrap the cluster

```bash
lxc project switch microcloud-demo
lxc exec micro1 -- bash
microcloud init
```

Follow the interactive prompts. Use the IPv4 and IPv6 addresses printed at the end of the setup script when asked to configure the uplink network.

### Access the LXD UI

Once `microcloud init` is complete, the LXD web UI is accessible at:

```
https://<micro1-ip>:8443
```

Get micro1's IP with:

```bash
lxc list
```

### Stop the environment (frees RAM, keeps disk state)

```bash
lxc project switch microcloud-demo
lxc stop micro1 micro2 micro3 micro4
```

### Resume

```bash
lxc project switch microcloud-demo
lxc start micro1 micro2 micro3 micro4
```

### Full teardown

```bash
chmod +x 02_teardown.sh
./02_teardown.sh
```

Removes all VMs, storage, networking, and the LXD project entirely.
