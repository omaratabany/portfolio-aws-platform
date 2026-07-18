# Report 4 — Observability

Phase 4's original scope (`INFRA_PROJECT_PLAN.md`) had two parts: CloudWatch
alarms on the two status-monitor Lambdas, and an optional stretch goal —
pointing the homelab's self-hosted Grafana at CloudWatch as a read-only data
source, so AWS metrics and homelab metrics sit side by side. Only the first
part is in this PR. The second is blocked on a real, physical fact, not a
design decision — see the note at the end.

---

## ADR-15: Alarms live inside each Lambda's own module, not the shared `observability` module

**Context.** The pre-existing `observability` module (used by the ingest
Lambda since Phase 0) bundles a CloudWatch log group plus two alarms
(Errors, Duration) into one reusable unit. `checker` and `api` already got
their own explicit log groups in Phase 3, to fix the unbounded-retention gap
found by inspection (`reports/03-cicd-hardening.md`).

**Decision.** Add the alarms directly inside `modules/lambda_checker` and
`modules/lambda_api`, next to the log groups already there, instead of
calling the shared `observability` module.

**Alternatives considered.** Reusing `observability` here would mean either
(a) letting it create a second, conflicting log group for functions that
already have one from Phase 3, or (b) splitting `observability` into
separate "log group" and "alarms" sub-modules so only the alarm half gets
reused. Option (a) is a straight bug. Option (b) is real modularity, but for
two Lambdas out of three, it means one Lambda's full observability story
lives in one module and the other two are split across two modules for no
reason a reader could infer — more confusing than the small duplication of
just writing the alarm blocks twice.

**Consequences.** The alarm resource blocks in `lambda_checker/main.tf` and
`lambda_api/main.tf` are near-duplicates of each other and of
`observability`'s. Three near-identical CloudWatch alarm pairs across three
modules, not one.

**Principle.** A shared module is worth it when reuse is free. Here reuse
would have cost either a duplicate resource or a refactor of a module
Phase 0 already shipped, for a project at a scale where three alarms
duplicated by hand is genuinely easier to read than the abstraction that
avoids it.

---

## ADR-16: Reusing the existing SNS topic instead of a second one

**Context.** `sns_alerts` (Phase 1) already exists and already has Omar's
email subscribed and confirmed — it's what `checker`'s status-flip alerts
(site up/down) publish to.

**Decision.** The new `checker_errors`/`checker_duration`/`api_errors`/
`api_duration` alarms all use `var.sns_topic_arn`, the same topic.

**Alternatives considered.** A second, dedicated "infrastructure alarms"
topic would separate "the site you're monitoring went down" from "the thing
monitoring it broke" at the notification level. Rejected for this project:
one recipient, one inbox, and a second topic means a second SNS email
subscription to manually confirm for no operational gain at this scale —
Omar reads every alert email regardless of which topic sent it.

**Consequences.** All four alert types (site down/up, checker error, checker
slow, api error, api slow) arrive from the same address with only the
subject line to distinguish them. Acceptable for a single-recipient
project; would be the first thing to revisit if this ever needed routing
(e.g., PagerDuty for infra alarms, email for site-status alerts).

**Principle.** Don't add a second notification channel until there's a
second audience or a routing need. One person, one topic, until that
changes.

---

## ADR-17: Threshold choices — `Errors >= 1`, `Duration` at ~two-thirds of timeout

**Context.** Both Lambdas needed an Errors alarm and a Duration alarm.
Thresholds needed picking for both.

**Decision.** `Errors >= 1` (any failure at all triggers it) on both
functions. `Duration`: `checker` at 10,000 ms (timeout is 15,000 ms),
`api` at 8,000 ms (timeout is 10,000 ms) — roughly two-thirds of each
function's actual timeout.

**Alternatives considered.** A higher Errors threshold (e.g., 3+ in a
period) would tolerate transient blips before alerting. Rejected: these are
low-invocation-volume functions (`checker` runs on a schedule, `api` only on
page loads), so a single error is already a meaningful signal, not noise —
unlike a high-traffic service where 1 error in 10,000 requests is
expected background rate.

**Consequences.** Slightly more alert-prone than a tolerant threshold would
be, which is the intended trade for a project at this traffic level.

**Principle.** Alarm thresholds should track expected invocation volume, not
a generic "wait for N failures" default — the right sensitivity for a
service handling thousands of requests a minute is wrong for one handling a
few an hour.

---

## ADR-18: Three gaps found by automated review, all fixed in this PR

**Context.** An automated reviewer (Codex, same as `reports/03-cicd-hardening.md`
ADR-14) left three comments on the alarms added above, before merge.

**Findings and fixes:**

1. **`api_errors` can't see application-level 500s.** `functions/api.py`
   catches every exception and returns a well-formed
   `{"statusCode": 500, ...}` proxy response — that's a *successful*
   Lambda invocation from AWS's point of view, so `AWS/Lambda Errors`
   never increments even when DynamoDB or SSM is actually failing
   underneath. Fixed by adding `api_5xx` in `modules/apigateway_monitor`,
   watching `AWS/ApiGateway`'s `5xx` metric instead — that metric counts
   the response actually sent to the caller, regardless of whether it
   came from a Lambda crash or a caught exception. HTTP APIs emit this
   automatically, no access logging setup required.
2. **No `Throttles` alarm.** A throttled invocation never runs user code,
   so it doesn't count as a Lambda "Error" — it's a separate metric.
   Given this account's Lambda concurrency limit in `eu-central-1` is
   only 10 and fully unreserved (`reports/03-cicd-hardening.md`), a burst
   of concurrent invocations is a real, already-documented failure mode,
   not a hypothetical one. Fixed by adding `checker_throttles` and
   `api_throttles` alongside each function's Errors alarm.
3. **Duration alarms used `Average`, not `Maximum`.** A 5-minute average
   lets one genuinely slow invocation get diluted by several fast ones
   and never cross the threshold — e.g. one 9-second `/status` call
   plus a handful of fast ones keeps the average under 8s. Fixed by
   switching both Duration alarms to `Maximum`.

**Consequences.** Five alarms per Lambda-facing surface now, not two:
Errors, Throttles, Duration (checker/api) plus the shared API Gateway 5xx
alarm — still $0 (well inside the 10-free-alarms allowance: 3 ingest +
4 checker/api + 1 API-level = 8 total).

**Principle.** Same as ADR-14: a second pair of eyes — automated or
human — catching a real gap before merge is the review process working,
not something to wave off because "CI is green." All three here were
fixed in this same PR rather than filed away as future work, since each
was low-effort and the resulting alarms would otherwise have silently
under-covered exactly the failure modes this project already knows about.

---

## Note: the Grafana/homelab bridge is deferred, not designed around

The stretch goal — pointing the homelab's self-hosted Grafana at CloudWatch
as a data source — needs this machine to reach the homelab's `192.168.0.x`
subnet. It currently doesn't: `ping` to both Talos nodes timed out, and
`route get`/`netstat -rn` confirmed there's no route from this Mac's
current subnet (`192.168.1.x`) to `192.168.0.0/24` — it falls through to a
default gateway that can't reach a separate private LAN. That's a physical/
network fact, not something to route around with a VPN or tunnel set up
unprompted. This half of Phase 4 is parked until a session where this
machine is actually on that network; the CloudWatch-side alarms above don't
depend on it and are complete on their own.

---

## ADR-23: the Grafana bridge — read-only IAM user, key generated out-of-band, both instances wired

**Context.** A later session had this Mac on the homelab's `192.168.0.x`
subnet via VPN. Omar confirmed and asked to complete the deferred half of
Phase 4. Investigation found **two** Grafana instances, not one: a Docker
container on Unraid (`192.168.0.113:3101`, paired with its own Loki/
Promtail/Prometheus, mostly watching the media-server stack) and a fuller
`kube-prometheus-stack` deployment on the Talos K8s cluster (Prometheus,
Alertmanager, Falco, Loki — exposed via ingress at `grafana.homelab`,
reachable from this Mac via `kubectl port-forward` without any DNS/hosts
changes). Asked Omar which to wire up and how to handle the AWS
credential; he chose both instances, and a new IAM user with the key
generated and entered by this session rather than handed to him to paste
in himself.

**Decision.** New `iam_grafana_reader` module: one IAM **user** (not a
role — there's no AWS compute for an on-prem Grafana to assume a role
from) with an inline policy scoped to `cloudwatch:GetMetricData/
GetMetricStatistics/ListMetrics/DescribeAlarms/ListDashboards/
GetDashboard` plus `ec2:DescribeRegions`/`tag:GetResources` (the two
non-CloudWatch permissions Grafana's CloudWatch plugin documents needing,
for its region picker and tag-based dimension filters — not an
over-broad grant). The access key itself is created via
`aws iam create-access-key` directly, **not** an `aws_iam_access_key`
Terraform resource — so the secret is never written into Terraform
state, which (unlike this repo's own source) isn't something under
version control review.

**Alternatives considered.** A single shared data source config pushed to
both Grafana instances was considered and rejected — the two instances
don't share a provisioning/config-as-code layer (one's a bare Docker
container, the other's a Helm-deployed K8s app with its own
`grafana.ini`/provisioning conventions), so "shared config" would mean
building a synchronization mechanism neither instance currently has, for
two data source entries that take a minute each to add by hand.

**Consequences.** Two independent CloudWatch data source configs to keep
in sync manually if the credential is ever rotated. One new long-lived
AWS credential exists that didn't before — scoped read-only, but still a
standing key outside this AWS account's IAM boundary, on infrastructure
this project doesn't manage. Worth revisiting if the homelab side ever
grows its own secrets-management story.

**Principle.** A cross-boundary integration (AWS account ↔ on-prem
infra) is exactly the case where "role instead of key" — the pattern
used everywhere else in this project — isn't available, because roles
require an AWS identity provider on the other end. Naming that
constraint explicitly, rather than reaching for a role out of habit,
is the same discipline as ADR-9's plain-HTTP-vs-CloudFront call: pick
the mechanism the actual constraints allow, not the one that's usually
preferred.
