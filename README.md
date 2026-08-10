# ZeroTier GitHub Action


ZeroTier is an SDN platform that allows users to create virtual
networks that can span multiple devices, locations, and cloud
providers. ZeroTier creates an encrypted peer-to-peer mesh overlay
network that handles NAT traversal and authentication to network
resources.

The ZeroTier Github Action allows users to easily integrate
ZeroTier into their CI/CD workflows by temporarily joining and
authorizing runners onto private ZeroTier networks.

```yaml
- name: ZeroTier
  uses: zalfafa/zt-action@v1.0.5
  with:
    network_id: ${{ secrets.ZEROTIER_NETWORK_ID }}
    auth_token: ${{ secrets.ZEROTIER_CENTRAL_TOKEN }}
```

`ZEROTIER_CENTRAL_TOKEN` can be provisioned from `Account` section in the [ZeroTier Central](https://my.zerotier.com) admin panel.

This Action works on Ubuntu, MacOS, and Windows runners.

----

This action installs ZeroTier on the runner node and generates a unique ZeroTier identity.  
It then uses the supplied `auth_token` to authorize the runner onto the network.

```yaml
- name: ZeroTier
  uses: zalfafa/zt-action@v1.0.5
  with:
    network_id: ${{ secrets.ZEROTIER_NETWORK_ID }}
    auth_token: ${{ secrets.ZEROTIER_CENTRAL_TOKEN }}
    
- name: ping host
  shell: bash
  run: |
    count=10
    while ! ping -c 1 ${{ secrets.ZEROTIER_HOST_IP }} ; do
      echo "waiting..." ;
      sleep 1 ;
      let count=count-1
    done
    echo "ping success"
```

After the workflow has completed, a `post` step automatically cleans
up by removing the runner from the network.

## Assigning a fixed IP to the runner

By default the runner gets an IP auto-assigned from the network pool. To pin the runner to one or more fixed IPs, pass them as a comma-separated list to `ip_assignments`:

```yaml
- name: ZeroTier
  uses: zalfafa/zt-action@v1.0.5
  with:
    network_id: ${{ secrets.ZEROTIER_NETWORK_ID }}
    auth_token: ${{ secrets.ZEROTIER_CENTRAL_TOKEN }}
    ip_assignments: "10.0.0.5,10.0.0.6"
```

The IPs must be inside the network's `ipAssignmentPools`. When set, the runner is exempted from auto-assignment (`noAutoAssignIps`) so the pool won't overwrite the manual IPs.

## Inputs

| Input | Required | Default | Description |
|-------|----------|---------|-------------|
| `network_id` | ✅ | — | The ZeroTier network ID to connect to |
| `auth_token` | ✅ | — | ZeroTier Central API access token |
| `api_url` | ❌ | `https://api.zerotier.com/api/v1` | ZeroTier Central API URL |
| `ip_assignments` | ❌ | *(empty)* | Comma-separated IPs to assign to the runner (e.g. `10.0.0.5`). Empty = auto-assign from the pool |
