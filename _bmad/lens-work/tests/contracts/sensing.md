# Contract Test: Cross-Initiative Sensing

**Skill Under Test:** sensing
**Purpose:** Verify overlap detection produces correct conflict classification.

---

## Overlap Classification

### Same-Feature (High Conflict)

| Current Initiative | Other Branch | Expected Level |
|-------------------|-------------|---------------|
| `payments-auth-oauth` | `payments-auth-oauth-refresh-small` | 🔴 High |

### Same-Service (Medium Conflict)

| Current Initiative | Other Branch | Expected Level |
|-------------------|-------------|---------------|
| `payments-auth-oauth` | `payments-auth-cache-small` | 🟡 Medium |

### Same-Domain (Low Conflict)

| Current Initiative | Other Branch | Expected Level |
|-------------------|-------------|---------------|
| `payments-auth-oauth` | `payments-billing-invoices-small` | 🟢 Low |

### No Overlap

| Current Initiative | Other Branch | Expected |
|-------------------|-------------|----------|
| `payments-auth-oauth` | `shipping-tracking-realtime-small` | Not reported |

## Branch Parsing for Sensing

| Branch Name | Parsed Domain | Parsed Service | Parsed Feature |
|-------------|--------------|----------------|----------------|
| `payments-auth-oauth-small-techplan` | `payments` | `auth` | `oauth` |
| `payments-auth-small` | `payments` | `auth` | null |
| `payments-billing-invoices-medium` | `payments` | `billing` | `invoices` |
| `test-worker-small-preplan` | `test` | `worker` | null |

## Deduplication

Given branches:
```
payments-auth-cache-small
payments-auth-cache-small-preplan
payments-auth-cache-medium
```

Expected: ONE unique initiative (`payments-auth-cache`), not three.

## Empty State

| Scenario | Expected Output |
|----------|----------------|
| No other initiative branches | `No overlapping initiatives detected ✅` |
| Only non-initiative branches (main, develop) | `No overlapping initiatives detected ✅` |

## Constitution Gate Mode

| Constitution Setting | Overlap Found | Expected Gate |
|---------------------|--------------|---------------|
| `sensing_gate_mode: informational` | Yes | Advisory — include in PR, don't block |
| `sensing_gate_mode: hard` | Yes | Block promotion — require conflict review |
| `sensing_gate_mode: hard` | No | Pass — no block needed |
| Not specified | Yes | Default to informational |

## Verification Method

Create test branches matching the patterns above, invoke `sensing` → `scan-initiatives`, and validate the output report matches expected conflict levels and deduplication.
