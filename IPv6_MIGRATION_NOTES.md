# IPv6 Migration Attempt and Module Upgrade Notes

## Executive Summary

**Attempted:** IPv6-only EC2 instances to save ~$7-14/month on public IPv4 charges
**Result:** **REVERTED** - Not viable without AWS NAT64 support
**Successful:** Module version upgrades (ASG, Security Group, AWS Provider)

## What We Tried (October 2025)

### 1. IPv6-Only Configuration Attempt

**Modified:** `terraform/asg.tf`
- Disabled public IPv4: `associate_public_ip_address = false`
- Enabled IPv6: `ipv6_address_count = 1`
- Configured ECS agent and Docker for IPv6

**Infrastructure verified working:**
- ✅ VPC has IPv6 CIDR: `2600:1f16:78e:d400::/56`
- ✅ Subnets have IPv6 CIDRs with auto-assign enabled
- ✅ Route table: `::/0` → Internet Gateway
- ✅ DNS64 enabled on all subnets
- ✅ AWS dual-stack endpoints available:
  - `ecs.us-east-2.api.aws` → `2600:1f70:6000:c0:...`
  - `ecr.us-east-2.api.aws` → `2600:1f70:6000:80:...`
  - `logs.us-east-2.api.aws` → `2600:1f70:6000:200:...`

### Why It Failed

**Root cause:** AWS provides DNS64 but **NOT NAT64**

**What this means:**
- **DNS64** (✅ provided): Translates DNS queries from A records to AAAA records using `64:ff9b::/96` prefix
- **NAT64** (❌ NOT provided): Would translate actual IPv6 packets to IPv4 for IPv4-only services
- Result: Instances can resolve IPv4-only services to IPv6 addresses, but packets time out with no NAT64 gateway

**Services that broke:**
- ❌ AWS SSM Agent (IPv4-only): `dial tcp [64:ff9b::392:b12]:443: i/o timeout`
- ❌ ECS container health checks failed
- ❌ Any IPv4-only external dependencies

**Services that worked:**
- ✅ ECS control plane (has dual-stack endpoint)
- ✅ ECR (has dual-stack endpoint)
- ✅ CloudWatch Logs (has dual-stack endpoint)

### 2. Terraform Module Version Upgrades (SUCCESSFUL)

**Successfully Updated Modules:**

| Module | Old Version | New Version | Status |
|--------|-------------|-------------|--------|
| `terraform-aws-modules/autoscaling/aws` | ~> 6.5 | ~> 8.3 | ✅ Applied |
| `terraform-aws-modules/security-group/aws` | ~> 4.0 | ~> 5.3 | ✅ Applied |
| AWS Provider | >= 4.6 | >= 5.0 | ✅ Applied |
| `terraform-aws-modules/ecs/aws` | ~> 4.0 | ~> 4.1 | ✅ Applied (kept at v4 to avoid cluster recreation) |

**Why we didn't go further:**
- ECS v6.x: Breaking API changes (cluster recreation required)
- ASG v9.x: Breaking changes in `mixed_instances_policy` structure

**Installed Versions:**
- AWS Provider: v5.100.0
- ECS Module: v4.1.3
- Autoscaling Module: v8.3.1
- Security Group Module: v5.3.1

## Current Configuration (Post-Revert)

**Final State:**
- ✅ Instances have public IPv4 (reverted from IPv6-only)
- ✅ Instances have IPv6 addresses
- ✅ Dual-stack networking
- ✅ Module upgrades applied
- ❌ No cost savings (still paying for public IPv4)

**Configuration:**
```hcl
# terraform/asg.tf
network_interfaces = [
  {
    associate_public_ip_address = true   # Reverted to true
    ipv6_address_count          = 1      # Still have IPv6
    # ...
  }
]

# terraform/ecs.tf - user_data
# Standard ECS config, no IPv6-specific settings
```

## What Would Need to Change for IPv6-Only to Work

**Waiting for AWS to provide:**

1. **Native NAT64 Service**
   - Similar to NAT Gateway but for IPv6→IPv4 translation
   - Would allow IPv6-only instances to reach IPv4-only services
   - **This is the blocker - AWS doesn't offer this**

2. **Alternative: All services support dual-stack**
   - Every AWS service with IPv6 endpoints
   - Particularly: SSM, EC2 Messages, SSM Messages
   - Currently only ECS, ECR, CloudWatch Logs, S3 support dual-stack

**Self-managed workarounds we rejected:**

1. **Deploy NAT64 on EC2** (Jool/Tayga software)
   - Cost: ~$3-5/month + maintenance burden
   - Complexity: High (setup, monitoring, SPOF)
   - Not worth $7-14/month savings

2. **VPC Endpoints for IPv4-only services**
   - Cost: ~$7-10/month
   - Would eliminate savings
   - Previous testing showed higher cost than benefit

3. **Disable SSM entirely**
   - Lose remote management capability
   - Not acceptable for production

## Lessons Learned

### What We Discovered

1. **DNS64 ≠ NAT64**
   - DNS64 only translates DNS queries, not actual traffic
   - Need both DNS64 + NAT64 for IPv6-only to work
   - AWS provides DNS64 but not NAT64

2. **Docker IPv6 Configuration Issues**
   - Enabling Docker IPv6 (`"ipv6": true`) broke dual-stack networking
   - Caused container health check failures
   - Required instance refresh to fix

3. **AWS Service IPv6 Support is Inconsistent**
   - Some services have dual-stack: ECS, ECR, CloudWatch, S3
   - Some services are IPv4-only: SSM, EC2 Messages
   - Use `.api.aws` suffix for dual-stack endpoints when available

4. **Cost-Benefit Analysis**
   - Potential savings: ~$7-14/month (public IPv4 charges)
   - VPC endpoint costs: ~$7-10/month (negates savings)
   - Self-managed NAT64: High complexity for minimal savings
   - **Conclusion:** Not worth the effort at this scale

### Technical Details Documented

**VPC IPv6 Configuration:**
- VPC CIDR: `2600:1f16:78e:d400::/56`
- Subnets: `2600:1f16:78e:d400::/64`, `d401::/64`, `d402::/64`
- DNS64 prefix: `64:ff9b::/96`
- Route: `::/0` → `igw-e39ab08a`

**Error signatures to watch for:**
```
dial tcp [64:ff9b::xxx:xxx]:443: i/o timeout
```
This indicates DNS64 translation without NAT64 gateway.

## Future Retry Conditions

**Only attempt IPv6-only again when ONE of these is true:**

1. ✅ **AWS launches managed NAT64 service**
   - Monitor AWS announcements for VPC NAT64 Gateway
   - Similar to existing NAT Gateway but for IPv6→IPv4

2. ✅ **All required AWS services support dual-stack**
   - Specifically need: SSM, EC2 Messages, SSM Messages with IPv6
   - Check: https://docs.aws.amazon.com/general/latest/gr/aws-ipv6-support.html

3. ✅ **Public IPv4 costs exceed $20-30/month**
   - At current scale (2-4 instances), savings too small
   - If scale increases significantly, complexity might be worth it

4. ✅ **VPC Endpoint costs drop significantly**
   - If AWS reduces endpoint pricing below ~$3/month per endpoint
   - Would make endpoint solution viable

**How to check service IPv6 support:**
```bash
dig service-name.region.api.aws AAAA +short
# If returns IPv6 address, service supports dual-stack
```

## Rollback Summary

**What we reverted:**
1. Changed `associate_public_ip_address` back to `true`
2. Removed IPv6-specific ECS agent configuration
3. Removed Docker IPv6 configuration
4. Triggered instance refresh to replace broken instances

**What we kept:**
- IPv6 addressing (instances have both IPv4 and IPv6)
- Module version upgrades
- Updated security group module

**Recovery time:** ~5 minutes for instance refresh to complete
