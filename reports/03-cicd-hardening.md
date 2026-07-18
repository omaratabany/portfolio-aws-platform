# Report 3 — CI/CD Hardening

The original plan for this phase (`INFRA_PROJECT_PLAN.md`) sketched
"lint → test → terraform plan (posted to the PR) → manual approval →
terraform apply" as the pipeline shape. What actually got built is
narrower than that, on purpose — see ADR-12. The rest of this report is
what a real security scanner found against already-deployed
infrastructure, and an honest account of what got fixed versus
deliberately left alone.

---

## ADR-12: No `terraform plan`/`apply` in CI, deliberately

**Context.** The original Phase 3 sketch wanted `terraform plan` running
on every PR, visible as a comment, with `apply` gated behind manual
approval.

**Decision.** CI runs tests, `terraform fmt`/`validate` (both
`-backend=false`, no AWS credentials involved), and a Checkov scan.
Nothing in CI touches live AWS state. `apply` stays exactly what it's
been since Phase 1: a deliberate, human-run action via CloudShell, plan
reviewed in the terminal before it executes.

**Alternatives considered.** A real `terraform plan` against live state
needs a CI role with read access across every service this project
touches — IAM, DynamoDB, S3, SNS, EventBridge, API Gateway, Budgets,
Lambda. That's a large permission grant for a role that, as of Phase 2,
is deliberately scoped to exactly three `lambda:UpdateFunctionCode`
calls. Widening it back out to satisfy a "nice to have" PR comment would
directly undo the least-privilege work Phase 2 just did, for a personal
project where the actual `apply` step already gets reviewed by the one
person who'd be reading that PR comment anyway.

**Consequences.** No automatic drift detection between PRs and live
state. For a single-maintainer project where every `apply` so far has
been run by hand within minutes of merge, this is an acceptable gap, not
an oversight — worth revisiting if this project ever has more than one
contributor, at which point a scoped, read-only plan role becomes
worth the added surface area.

**Principle.** Match pipeline ambition to the account's actual
permission posture, not to a generic "what a real pipeline looks like"
template. A plan sketched before Phases 1–2 existed doesn't know what
those phases established.

---

## ADR-13: Checkov, `soft_fail: true`, first run against real infrastructure

**Context.** This is the first time any static scanner has run against
this Terraform. It's also the first time it's running against
infrastructure that's already live in a real account, not a fresh
`init`.

**Decision.** `soft_fail: true` — findings are visible in every PR's
job log, but don't block merges.

**Alternatives considered.** Hard-enforcing from commit one would have
turned every future PR red on day one over findings nobody had
triaged yet (see the findings table below — 45 on the first run). That
teaches the same lesson as an alert that fires on every failed health
check (ADR-4): people stop reading red CI, they don't fix it faster.

**Consequences.** This is genuinely a phase, not a permanent state —
`soft_fail` should flip to hard enforcement once the findings below are
either fixed or explicitly suppressed with a documented reason, not left
soft indefinitely as a way to avoid ever dealing with them.

**Principle.** Rolling out a new gate against an existing system is a
different problem from enforcing a gate on a system built with it from
the start. Visibility first, enforcement once there's a clean baseline
to enforce against.

---

## ADR-14: Scoping `GITHUB_TOKEN` — `contents: read`, `persist-credentials: false`

**Context.** Neither CI job writes anything back to the repository. Both
execute code or config that comes from the PR branch itself — `pytest`
runs the PR's Python, Checkov scans the PR's Terraform.

**Decision.** `permissions: contents: read` at the workflow level, plus
`persist-credentials: false` on every checkout, so no token is even left
on disk for a later step to pick up.

**Alternatives considered.** Leaving the default token scope (which can
include write access depending on repo settings) costs nothing to avoid
and buys real protection against a specific, concrete risk: a step that
runs PR-supplied code with a live, writable repo token sitting in local
git config is exactly the shape of a supply-chain problem, not a
hypothetical one.

**Consequences.** None — this workflow was never using write access, so
there's no behavior change, only a removed capability nothing needed.

**Attribution.** Found by an automated reviewer (Codex, already
installed on this repo) on this PR, not written into the workflow from
the start. Worth naming directly: a second pair of eyes — human or
automated — catching something the first pass missed is the system
working, not a gap to gloss over.

**Principle.** The credential the CI *system* runs with is as much a
least-privilege surface as the AWS IAM roles it deploys — same lens as
`reports/02-least-privilege.md`, aimed at a different token.

---

## Findings, run against real deployed infrastructure

First Checkov run: **130 passed, 45 failed**, across 25 distinct checks.
Triaged into three categories, not fixed uniformly and not ignored
uniformly:

### Fixed (real, $0, low effort)

| Check | What | Why fixed |
| --- | --- | --- |
| `CKV2_AWS_34` | SSM parameter should be encrypted | Switched to `SecureString` — AWS-managed key, no CMK cost. Required adding `kms:Decrypt` (scoped via `kms:ViaService`, not a hardcoded key ARN) and `WithDecryption=True` in both Lambdas' `get_parameter` calls. |
| `CKV_AWS_50` | X-Ray tracing enabled for Lambda | Within the always-free tier (100k traces/month; this runs ~9,000/month across all three functions). Real observability value at $0. |
| *(not flagged by Checkov, found by inspection)* | `checker` and `api` had **no** explicit CloudWatch log group | Lambda auto-creates one on first invocation with **no expiration** — unbounded log storage cost accruing forever. Added explicit groups, 14-day retention, matching `ingest`'s existing pattern. |

### Deferred — would cost real money

| Check | What | Why deferred |
| --- | --- | --- |
| `CKV_AWS_115` | Lambda reserved concurrency limit | Free in principle, but this account's total Lambda concurrency limit in `eu-central-1` is only 10 (not AWS's usual default of 1000) and is currently fully unreserved — AWS requires >=10 unreserved at all times, so reserving any amount for any function fails outright without a service quota increase first. Attempted at 5 per function, reverted after `terraform apply` failed with `InvalidParameterValueException`. Revisit if/when a quota increase is requested. |
| `CKV_AWS_119`, `CKV_AWS_145`, `CKV_AWS_158`, `CKV_AWS_337` | KMS CMK encryption (DynamoDB, S3, CloudWatch Logs, SSM) | Each needs a **customer-managed** KMS key — $1/month per key, four keys, directly against the $0 ceiling. Default encryption (AWS-owned keys) already applies at no cost; a CMK buys key-rotation control this project doesn't need yet. |
| `CKV_AWS_28` | DynamoDB point-in-time recovery | Real, ongoing storage cost proportional to table size/change rate — not free-tier covered. |
| `CKV_AWS_117` | Lambda inside a VPC | Would need a NAT Gateway for internet egress (the checker calls external URLs) — NAT Gateway is explicitly the most common AWS bill-shock item, already named as a non-goal in `INFRA_PROJECT_PLAN.md`. |
| `CKV_AWS_116` | Lambda Dead Letter Queue | SQS itself is free-tier eligible; genuinely the closest "deferred" item to being worth doing. Held back this round to keep Phase 3's scope to what the CI/CD work actually required — a reasonable Phase 5 candidate, not a $0 excuse. |

### Accepted — findings that are correct about the code, wrong about the intent

| Check | What | Why it's not a bug |
| --- | --- | --- |
| `CKV_AWS_54`, `CKV_AWS_56`, `CKV_AWS_70`, `CKV2_AWS_6` | S3 public access / public policy / any-principal | `module.site`'s entire purpose is a public status page (ADR-7, ADR-9). These checks are correctly describing what the bucket does, not catching a mistake. |
| `CKV_AWS_309` (on `apigateway_monitor` routes) | API Gateway routes should specify an authorization type | Same story — `GET /status` and `GET /history/{target}` are meant to be public. |
| `CKV2_AWS_16` | DynamoDB auto-scaling | Capacity is fixed at 1/1 on purpose (ADR-3) — specifically to stay inside the always-free provisioned allowance regardless of traffic. Auto-scaling would let it drift out of that allowance under load, which is the opposite of what this table needs. |

### Not yet triaged / lower priority

`CKV_AWS_18` (S3 access logging), `CKV_AWS_21` (site bucket versioning),
`CKV_AWS_144` (cross-region replication), `CKV2_AWS_61`/`CKV2_AWS_62`
(S3 lifecycle/event notifications), `CKV_AWS_76` (API Gateway access
logging), `CKV_AWS_272` (Lambda code-signing), `CKV_AWS_338` (log
retention ≥ 1 year — deliberately kept at 14 days for this project;
see the comment in `modules/lambda_checker/main.tf`), and the
pre-existing `CKV_AWS_309`/`CKV_AWS_76` findings on the **ingest**
API (already on the README's own "What I Would Add Next" list before
this project touched the repo). Real gaps, genuinely lower value or
higher effort than what's above — left for a future pass rather than
padding this list with fixes chosen for check-count optics.

**Result after the fixes above:** 144 passed, 43 failed. The count barely
moved — new resources (the two log groups) bring their own new checks,
some of which also fail (`CKV_AWS_158`, `CKV_AWS_338` again, on the new
groups). The real signal isn't the aggregate number, it's that the
specific checks in the "Fixed" table above are gone from the failing
list, and the ones in "Deferred"/"Accepted" are still there for a
documented reason, not by accident.
