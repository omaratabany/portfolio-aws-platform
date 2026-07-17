# Report 1 — Status Monitor

Written alongside the build, not after. Each entry: Context → Decision →
Alternatives considered → Consequences → Principle it demonstrates.

---

## ADR-1: Lambda, not EC2/Fargate

**Context.** The checker needs to run for a few seconds every 5 minutes.
The api needs to run for milliseconds, only when someone loads the status
page.

**Decision.** Both are AWS Lambda functions.

**Alternatives considered.** A small EC2 instance running a cron job would
work, but bills for 730 hours/month whether or not it's doing anything —
even `t4g.nano` isn't inside the always-free tier past the 12-month new
account window. Fargate is the same problem at a different price point:
you pay for reserved vCPU/memory for the task's lifetime, not per
invocation.

**Consequences.** Cold starts (low hundreds of ms, acceptable for both a
5-minute-interval background job and a status page) in exchange for
paying nothing when the function isn't running — which, at ~9,000
invocations/month of a few hundred ms each, is nearly always.

**Principle.** Match compute model to traffic shape. Bursty and
infrequent → pay-per-invocation. Constant → a server starts making sense.
This workload is the first kind.

---

## ADR-2: EventBridge, not a cron server

**Context.** Something has to trigger the checker every 5 minutes,
reliably, without anyone maintaining it.

**Decision.** An EventBridge scheduled rule (`rate(5 minutes)`) invoking
the checker Lambda directly.

**Alternatives considered.** A cron job on a server has the same idle-cost
problem as ADR-1, plus now there's an OS to patch and a single point of
failure if that one box goes down.

**Consequences.** The schedule itself becomes a Terraform resource,
version-controlled and reviewable in a diff like everything else — not a
crontab someone has to remember exists.

**Principle.** Prefer managed, declarative scheduling over anything that
requires a running process to maintain its own uptime.

---

## ADR-3: DynamoDB, provisioned (not on-demand), not RDS

**Context.** Every check needs to write one row; the status page needs to
read "current status" and "recent history" per target.

**Decision.** A single DynamoDB table, `UptimeChecks`, partition key
`target` + sort key `sk` — provisioned capacity, 1 RCU/1 WCU.

**Alternatives considered.**
- **RDS** — the access pattern here (append a row, read recent rows for
  one partition) is a textbook key-value fit; a relational engine adds
  schema migrations and a always-on instance cost for no benefit this
  workload needs.
- **DynamoDB on-demand (PAY_PER_REQUEST)** — this was the one real trap.
  On-demand looks like the "safe default" for a low-traffic project, but
  AWS's always-free 25 RCU/25 WCU allowance applies to **provisioned**
  capacity specifically. On-demand has no equivalent ongoing free
  allowance outside a new account's 12-month window. Given this account
  isn't new, on-demand mode would have quietly put this table outside the
  free tier from day one. Provisioned at 1/1 — far more than ~288
  writes/day needs — stays inside the always-free allowance regardless of
  account age.

**Consequences.** If traffic ever spiked past 1 RCU/WCU sustained,
requests would get throttled rather than silently costing more — a
safe failure mode for a project with a hard $0 ceiling, not a silent one.

**Principle.** "Free tier" isn't one thing — it has different shapes per
service and per billing mode, and the difference is exactly where an
unexamined default (on-demand feels safer, so it must be cheaper) can
quietly break a stated cost constraint. Check the specific mechanism, not
the vibe.

---

## ADR-4: Alert on state change, not on every failed check

**Context.** The checker runs every 5 minutes. During a real outage, most
of those runs will fail.

**Decision.** `checker.py` compares each result to the previous one
(stored in the `LATEST` row) and publishes to SNS only when `is_up`
flips — down→up or up→down. See `alert_on_change()` in `checker.py`.

**Alternatives considered.** Alerting on every failed check is simpler to
write, but during a 2-hour outage that's 24 emails for one incident — the
kind of monitor that trains you to stop reading its emails.

**Consequences.** One email when something breaks, one when it recovers.
The tradeoff: a flapping service (up, down, up, down every few minutes)
generates one email per flip, which is arguably still correct — it *is*
unstable and that's worth knowing — but is a known edge case worth
watching for once this runs for real.

**Principle.** Alert on state transitions, not on individual failed
observations. This is the same debounce logic that separates a useful
monitor from a noisy one at any scale.

---

## ADR-5: HTTP API, not REST API, on API Gateway

**Context.** The status API needs two GET routes, proxying straight to
one Lambda.

**Decision.** `aws_apigatewayv2_api` (HTTP API), matching what the ingest
pipeline already uses.

**Alternatives considered.** REST API (API Gateway v1) supports things
this project doesn't need — request/response transformation templates,
usage plans, API keys. HTTP API is cheaper per request and simpler to
configure for a plain Lambda-proxy integration.

**Consequences.** If this project later needs an API-key-gated route or
request validation beyond what the Lambda does itself, that's a real
reason to reconsider — not before.

**Principle.** Pick the tool that covers the actual requirement, not the
one with more features sitting unused.

---

## ADR-6: Two IAM roles, not one shared role

**Context.** `checker` writes to DynamoDB and publishes to SNS. `api`
only ever reads from DynamoDB.

**Decision.** Separate execution roles (`iam_monitor` module):
`checker_exec` (DynamoDB `PutItem`/`GetItem` + SNS `Publish`) and
`api_exec` (DynamoDB `GetItem`/`Query` only).

**Alternatives considered.** One shared role scoped to "whatever either
function needs" is less code, but it means a bug or injected input in the
read-only `api` function would still technically be permitted to write
data or send alerts — a wider blast radius than the function's actual job
requires.

**Consequences.** Slightly more Terraform (two roles instead of one), in
exchange for each function only being able to do what it actually does.

**Principle.** Least privilege per function, not per project. "The
project needs write access somewhere" is not the same claim as "this
specific function needs write access."

---

## ADR-7: A separate API Gateway, not new routes on the ingest one

**Context.** The ingest pipeline already has an HTTP API
(`POST /ingest`). The status monitor needs its own routes.

**Decision.** A second, independent `aws_apigatewayv2_api` in the
`apigateway_monitor` module.

**Alternatives considered.** Adding `GET /status` and `GET /history/{target}`
as new routes on the existing ingest API would save one resource, but
couples two unrelated concerns — internal event ingestion and a public
status page — onto shared throttling limits, a shared CORS policy, and a
shared blast radius if one needs to change.

**Consequences.** One more API Gateway resource (still free tier at this
volume) in exchange for being able to change either pipeline's API
independently later.

**Principle.** Group infrastructure by what changes together, not by what
happens to share a resource type.

---

## ADR-8: Account-wide zero-spend budget, applied independently

**Context.** This project's hard constraint is $0/month, reiterated
explicitly given real financial pressure right now — not a soft
preference.

**Decision.** An `aws_budgets_budget` (`budget` module) with a $0.01
actual-spend threshold and a $1 forecasted threshold, notifying by email
— scoped to the whole AWS account, not just this project's resources, and
wired into `main.tf` independently of everything else (it has no
dependency on the monitor's other modules).

**Alternatives considered.** Relying on "everything here is free-tier
sized, so it'll be fine" with no alarm is exactly the kind of assumption
that turns into an unpleasant bill when something elsewhere in the
account (unrelated to this project) drifts. A budget scoped only to this
project's tagged resources would miss that.

**Consequences.** One extra module, applied first, that has nothing to do
with the status monitor's actual function — its only job is catching a
mistake before it becomes a real charge.

**Principle.** Cost controls belong at the account level, not bolted onto
individual projects — a project-scoped safeguard only catches problems
inside that project.
