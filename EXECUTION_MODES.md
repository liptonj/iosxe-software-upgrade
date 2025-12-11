# Execution Modes and Failure Handling

This guide explains how the playbook handles multiple switches and what happens when upgrades fail.

## Execution Modes

### 1. Parallel Mode (Default)

**Command:**

```bash
make upgrade
```

**Behavior:**

- Upgrades up to **5 switches simultaneously** (configured in `ansible.cfg`)
- Fastest option
- All switches upgrade at the same time
- Each switch progresses independently
- One failure doesn't stop others

**When to use:**

- ✅ Lab/test environments
- ✅ Non-critical switches
- ✅ When you have console access to all switches
- ✅ When downtime window allows parallel failures

**Risks:**

- ⚠️ Multiple switches down at once
- ⚠️ If all fail, major outage
- ⚠️ Harder to troubleshoot multiple failures

### 2. Serial Mode (Recommended for Production) ⭐

**Command:**

```bash
make upgrade-serial
```

**Behavior:**

- Upgrades **ONE switch at a time**
- Waits for switch to complete before starting next
- Stops immediately on first failure (`fail_fast=true`)
- Safest option

**When to use:**

- ✅ **Production environments** (RECOMMENDED)
- ✅ Critical infrastructure
- ✅ When you want to minimize risk
- ✅ When failures need immediate attention

**Benefits:**

- ✅ Only one switch down at a time
- ✅ Easy to identify which switch failed
- ✅ Can stop and fix issues before continuing
- ✅ Predictable timeline

**Example:**

```bash
# Upgrade 10 switches one at a time
make upgrade-serial

# Expected duration: 10 switches × 40 min = ~7 hours
```

### 3. Batched Mode

**Command:**

```bash
make upgrade-batch  # 2 at a time
```

**Behavior:**

- Upgrades **2 switches at a time**
- Waits for both to complete before next batch
- Continues if <25% fail (`max_fail_pct=25`)
- Balance between speed and safety

**When to use:**

- ✅ Medium-sized deployments
- ✅ Redundant switch pairs
- ✅ When you can tolerate some concurrent downtime

**Example:**

```bash
# Upgrade 10 switches in batches of 2
make upgrade-batch

# Batches: [sw1, sw2] → [sw3, sw4] → [sw5, sw6] → ...
# Expected duration: 10 switches ÷ 2 × 40 min = ~3.5 hours
```

### 4. Custom Serial/Batch

**Override serial count:**

```bash
# Upgrade 3 at a time
ansible-playbook ansible/playbooks/upgrade_ios_xe.yml \
  -i ansible/inventory.ini \
  -e "serial_mode=3" \
  --ask-vault-pass

# Upgrade 25% at a time
ansible-playbook ansible/playbooks/upgrade_ios_xe.yml \
  -i ansible/inventory.ini \
  -e "serial_mode=25%" \
  --ask-vault-pass
```

## Failure Handling

### What Happens When a Switch Doesn't Come Back?

**Scenario:** Switch fails to reconnect after reboot

#### With Default Settings (Parallel Mode):

1. ✅ Playbook continues upgrading other switches
2. ⚠️ Failed switch shows in PLAY RECAP as `unreachable=1`
3. ⚠️ No automatic rollback
4. ℹ️ Backup available for manual recovery

**Output:**

```
PLAY RECAP
switch01: ok=25 changed=5  unreachable=0 failed=0    ← Success
switch02: ok=10 changed=3  unreachable=1 failed=0    ← Failed to reconnect
switch03: ok=25 changed=5  unreachable=0 failed=0    ← Success
```

#### With Serial Mode + Fail Fast:

```bash
make upgrade-serial  # Has fail_fast=true
```

1. ⚠️ Playbook **stops immediately** on first failure
2. ⚠️ Remaining switches are **not upgraded**
3. ℹ️ You can fix the issue and re-run
4. ℹ️ Switches already upgraded stay upgraded

**Output:**

```
switch01: Upgraded successfully ✅
switch02: Failed to reconnect ❌
ABORTING: Remaining switches NOT upgraded
```

### Failure Scenarios

#### Scenario 1: Switch Doesn't Reboot

**Symptoms:**

- `wait_for_connection` times out (10 minutes)
- Switch stuck in bootloader or rommon

**Resolution:**

```bash
# 1. Console access required
# 2. Boot manually from rommon
boot flash:packages.conf

# 3. Or rollback
install rollback
```

#### Scenario 2: Switch Reboots But SSH Doesn't Come Up

**Symptoms:**

- Switch pings but SSH fails
- Firewall or SSH config issue

**Resolution:**

```bash
# 1. Console access
# 2. Check SSH status
show ip ssh

# 3. Enable SSH if needed
conf t
ip ssh version 2
line vty 0 15
 transport input ssh
end
```

#### Scenario 3: Upgrade Fails During Install

**Symptoms:**

- Install command returns error
- Switch doesn't reboot

**Resolution:**

```bash
# Check install status
show install summary

# Remove failed packages
install remove inactive

# Retry or rollback
install rollback
```

## Timeout Configuration

### Default Timeouts

```yaml
install_timeout: 1200 # 20 minutes for install command
reboot_wait_timeout: 300 # 5 minutes before checking connectivity
wait_for_connection: 600 # 10 minutes to reconnect
```

### Adjust for Slow Networks

If switches take longer to reboot:

```yaml
# In group_vars/switches.yml or command line
-e "reboot_wait_timeout=600"      # Wait 10 min before connecting
-e "wait_for_connection_timeout=900"  # Wait 15 min for connection
```

## Monitoring Upgrades

### Watch Progress in Real-Time

```bash
# Terminal 1: Run upgrade
make upgrade-serial

# Terminal 2: Monitor logs
tail -f ansible.log

# Terminal 3: Ping switches
watch -n 5 'ansible switches -i ansible/inventory.ini -m ping -o'
```

### Check Status During Upgrade

```bash
# List switches currently being upgraded
ps aux | grep ansible-playbook

# Check which switches have been upgraded
make check-version
```

## Recovery Procedures

### If a Switch Fails During Upgrade

**Step 1: Identify the failure**

```
PLAY RECAP
switch02: unreachable=1  ← This switch failed
```

**Step 2: Console access**

- Connect via console cable
- Check boot status
- Review error messages

**Step 3: Recovery options**

**Option A: Complete the upgrade manually**

```bash
# On console
install add file flash:cat9k_iosxe.17.15.04.SPA.bin activate commit
```

**Option B: Rollback**

```bash
# On console
install rollback
reload
```

**Option C: Restore from backup**

```bash
# Copy backup to switch
copy ftp://server/backups/switch02_running-config_TIMESTAMP.cfg running-config
```

### If Multiple Switches Fail

**With Parallel Mode:**

- All failures reported in PLAY RECAP
- Handle each switch individually
- Others continue upgrading

**With Serial Mode:**

- Only first failure reported
- All subsequent switches skipped
- Fix the failed switch
- Re-run playbook with `--limit` to continue

**Re-run after fixing:**

```bash
# Skip already-upgraded switches (playbook detects version)
make upgrade-serial

# Or manually specify remaining switches
make upgrade-serial LIMIT="switch03,switch04,switch05"
```

## Best Practices

### For Production Environments

1. **Always use serial mode:**

   ```bash
   make upgrade-serial
   ```

2. **Test with dry-run first:**

   ```bash
   make upgrade-dry-run
   ```

3. **Backup before starting:**

   ```bash
   make backup
   ```

4. **Have console access ready**

5. **Upgrade during maintenance window**

6. **Monitor actively** - don't walk away

### For Lab Environments

1. **Parallel mode is fine:**

   ```bash
   make upgrade
   ```

2. **Still backup first:**

   ```bash
   make backup
   ```

3. **Accept that some may fail**

## Execution Comparison

| Mode          | Switches at Once | Stop on Failure | Duration (10 switches) | Risk Level |
| ------------- | ---------------- | --------------- | ---------------------- | ---------- |
| **Parallel**  | 5                | No              | ~40 min                | ⚠️ High    |
| **Batch (2)** | 2                | At 25%          | ~3.5 hours             | ⚠️ Medium  |
| **Serial**    | 1                | Yes             | ~7 hours               | ✅ Low     |
| **Dry-Run**   | N/A              | N/A             | ~5 min                 | ✅ None    |

## Advanced: Custom Strategies

### Upgrade Core Switches Separately

```ini
# inventory.ini
[core_switches]
core-01 ansible_host=10.1.1.1
core-02 ansible_host=10.1.1.2

[edge_switches]
edge-01 ansible_host=10.2.1.1
edge-02 ansible_host=10.2.1.2
# ... more edge switches
```

```bash
# Upgrade edge in parallel (lower risk)
make upgrade LIMIT=edge_switches

# Upgrade core serially (high risk)
make upgrade-serial LIMIT=core_switches
```

### Progressive Rollout

```bash
# Week 1: One switch to test
make upgrade-serial LIMIT=test-switch-01

# Week 2: One site
make upgrade-serial LIMIT=site_a_switches

# Week 3: All remaining
make upgrade-batch
```

## Rollback Strategy

### If Upgrade Goes Wrong

**Immediate Actions:**

1. Stop the playbook (`Ctrl+C`)
2. Console access to failed switches
3. Check status: `show install summary`
4. Rollback: `install rollback`

**For Switches Already Upgraded:**

- They stay on new version (no automatic rollback)
- Manual rollback required if needed
- Use backup configs if necessary

### Controlled Rollback

```bash
# Check which switches upgraded
make check-version

# Manually rollback specific switches via console
# (No automated rollback - by design for safety)
```

---

**Remember**: Serial mode is SAFEST for production! One switch at a time = one problem at a time. 🛡️
