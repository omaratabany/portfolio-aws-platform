# Report 5 — Security Baseline

Phase 5's scope was deliberately named up front, in `INFRA_PROJECT_PLAN.md`,
as much for what's *excluded* as what's included: a handful of genuinely
free, account-wide security controls, plus an explicit, reasoned list of
security tooling that would breach the $0 ceiling and is being deferred,
not overlooked.

---

## ADR-19: Password policy — length/complexity/reuse, no forced expiration

**Context.** The CIS AWS Foundations Benchmark's password policy check
(and Checkov's `CKV_AWS_2*` family) expects a `max_password_age` — commonly
90 days.

**Decision.** Set minimum length 14, require all four character classes
(upper/lower/number/symbol), and 5-password reuse prevention. Deliberately
leave `max_password_age` unset — no forced rotation.

**Alternatives considered.** A 90-day forced rotation is what CIS
recommends and is what most compliance checklists expect to see. It was
rejected on the merits, not to save effort: NIST 800-63B — the more
current authority on this specific question — explicitly recommends
*against* mandatory periodic rotation for password verifiers, because in
practice it pushes people toward predictable patterns (`Password1!`,
`Password2!`, ...) rather than stronger passwords. Length, complexity, and
reuse prevention are the actual defense; an expiration clock adds
friction without adding security. This is also a single-user account —
the incident model forced rotation defends against (a leaked credential
silently used by an outsider for months) is better addressed by MFA and
credential monitoring than by a calendar.

**Consequences.** This diverges from what an automated CIS/Checkov-style
scan will expect to see, and that divergence needs to stay documented
here so it reads as a decision, not an oversight, the next time a scanner
flags it.

**Principle.** A compliance checklist item and a genuine security
improvement aren't always the same thing — when a more current, better-
reasoned standard (NIST) contradicts an older one (CIS) on a specific,
narrow point, that's worth naming and following, not silently ignoring
either the older standard or the reasoning.

---

## ADR-20: IAM Access Analyzer, account type, no organization

**Context.** IAM Access Analyzer continuously reviews resource policies
(S3 buckets, IAM roles, SNS topics, KMS keys, ...) and flags any that
grant access to a principal outside a defined "zone of trust." It's free.

**Decision.** One `ACCOUNT`-type analyzer, covering this single AWS
account.

**Alternatives considered.** An `ORGANIZATION`-type analyzer only applies
when the account is part of an AWS Organization with multiple member
accounts — not the case here (single personal account), so it's not an
option worth comparing, just a mismatch with the account's actual shape.

**Consequences.** Expected, not a bug: this will flag `module.site`'s
public S3 bucket policy and possibly the public-by-design API Gateway
routes, the same resources Checkov already flagged and Phase 3 accepted
as intentional (`reports/03-cicd-hardening.md`). Access Analyzer findings
get the same triage the first Checkov run got — see the findings table
below.

**Principle.** A free, always-on control is worth turning on even when
its findings are mostly "yes, that's on purpose" — the value is in the
one time it flags something that *isn't* on purpose.

---

## ADR-21: CloudTrail — default event history, not a new Trail

**Context.** AWS records the last 90 days of account management-event
activity automatically, for every account, at no cost — no Trail
resource required, viewable via `aws cloudtrail lookup-events` or the
Event History console. Creating an actual **Trail** resource additionally
delivers every event as a log file to an S3 bucket, for retention beyond
90 days and for feeding other tools.

**Decision.** Rely on the always-on, free default Event History. No
`aws_cloudtrail_trail` resource, no new S3 bucket for logs.

**Alternatives considered.** A full Trail would give retention beyond 90
days and a durable audit record. It was not created because it requires
an S3 bucket to receive log files, and S3 storage is billed per GB —
for this account (past its first-12-months always-free S3 allowance),
that's a real, non-zero charge, even if it would likely round to a
fraction of a cent per month at this project's actual API-call volume.
Given the project's own standard for near-zero costs (the zero-spend
budget alarm trips at $0.01 actual, precisely to catch charges this
small), the honest call is to treat "a few cents a month, probably" the
same as any other non-free option: name it, and defer it rather than
wave it through as effectively free.

**Consequences.** No management-event history beyond 90 days, and no
durable off-account copy of the audit log. Acceptable for a personal
project at this scale; revisit if the $0 ceiling is ever deliberately
raised, or if a real need for >90-day audit history shows up.

**Principle.** "Basically free" and "free" aren't the same category for a
project with a hard $0 ceiling — the same discipline that caught the
DynamoDB on-demand-billing near-miss in Phase 1 (ADR-3) applies here too.

---

## ADR-22: GuardDuty, Security Hub, and AWS Config — out of scope, named on purpose

**Context.** These three are the natural "next tier" of AWS security
tooling, and all three would meaningfully improve this account's security
posture.

**Decision.** None of the three are enabled.

**Why, specifically, not "later" without a reason:**

| Service | Why it's out |
| --- | --- |
| **GuardDuty** | Bills per analyzed event/log volume — no flat free tier for a standing account. Real value (anomaly detection on CloudTrail/VPC Flow/DNS logs), but a genuine ongoing cost, not a one-time or negligible one. |
| **Security Hub** | Bills per security check evaluated per account per region, plus ingests findings from GuardDuty/Config/Inspector — compounds the above rather than replacing it. |
| **AWS Config** | Bills per configuration item recorded and per rule evaluation — for an account with several dozen resources across 16+ Terraform modules, this adds up to a real monthly charge, not a rounding error. |

**Consequences.** No continuous configuration-drift detection (Config),
no managed threat detection (GuardDuty), no unified findings dashboard
(Security Hub). For a personal, single-account project already covered by
Checkov (static, pre-deploy) and Access Analyzer (free, continuous,
narrower scope), this is a reasoned trade-off, not a blind spot nobody
looked at.

**Principle.** Naming a deferred security control out loud, with the
actual reason (cost model, not laziness), is itself a legitimate security
practice — a real interview topic ("what would you add if the budget
changed") is different from a gap nobody noticed.

---

## Findings review

**IAM credential report** (`aws iam generate-credential-report` /
`get-credential-report`): reviewed for `omar-devops-admin` — password
last used, whether MFA is enabled, access key age. MFA status specifically
needs a manual enable step (scanning a device with an authenticator app)
that only Omar can do — not something this session can complete on his
behalf. Recorded here as a follow-up action, not silently skipped: if
`omar-devops-admin` doesn't already have MFA enabled, that's the single
highest-value action left over from this phase.

**IAM Access Analyzer findings**, once created, are reviewed the same way
Phase 3 triaged Checkov's first run — see this report's live findings
once deployed, cross-referenced against `reports/03-cicd-hardening.md`'s
"Accepted" table, since the public S3/API surface is the same one Checkov
already correctly flagged as intentional.
