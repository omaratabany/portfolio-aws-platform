# Report 2 — Least Privilege, Round Two

Phase 1 got the *runtime* roles right (checker vs api, ADR-6). Phase 2
turns the same lens on two things Phase 1 left alone: the CI role itself,
and how config data gets to the Lambdas in the first place.

---

## ADR-10: Scope the CI role's deploy permissions to specific ARNs

**Context.** The GitHub Actions role's deploy policy, written before this
project existed, granted `lambda:UpdateFunctionCode` and
`lambda:GetFunction` on `Resource: "*"` — every Lambda function in the
account, present or future — plus `s3:PutObject`/`GetObject`/`ListBucket`,
also on `"*"`.

**Decision.** Replaced it with a policy scoped to exactly the three
function ARNs `deploy.yml` actually deploys code to (`ingest`,
`status-checker`, `status-api`), and dropped the S3 actions entirely.

**Alternatives considered.** Leaving it as-is was the default — nobody
had to actively choose the wildcard, it was just never revisited once
this project added two more functions to deploy. That's exactly the
failure mode worth naming: permissions granted for one reason (deploy the
one function that existed at the time) silently cover everything added
later, forever, unless someone goes back and checks.

**Consequences — a real finding, not a hypothetical one.** Checking what
`deploy.yml` actually calls (a five-line grep, not a guess) showed it
never touches S3 at all. Those three S3 actions had been unused since the
policy was written. This is the kind of gap that's easy to miss precisely
because it doesn't cause anything to break — the role simply had
permissions it never used, which is invisible until someone audits it or
something exploits it.

**Principle.** A least-privilege review isn't just "did I scope the roles
I wrote today" — it's checking every role a project touches, including
ones that predate the project, for grants nothing currently uses.

---

## ADR-11: Config in SSM Parameter Store, not baked into Lambda env vars

**Context.** The list of sites to monitor (`monitor_targets`) was a
Terraform variable, JSON-encoded straight into each Lambda's environment
variables at `apply` time.

**Decision.** Moved it to a single SSM `String` parameter
(`/portfolio-platform/dev/status-monitor/targets`), read by both Lambdas
at runtime — lazily, on first invocation of a warm container, cached in
memory afterward (`get_targets()` in both `checker.py` and `api.py`), not
fetched at import time.

**Alternatives considered.**
- **Leave it in env vars** — works, but adding or removing a monitored
  site means a full `terraform apply`, redeploying Lambda code that
  didn't actually change, just to update a string.
- **Fetch SSM at module import time** instead of lazily — simpler code,
  but couples every cold start to an extra API call before the function
  can do anything, and makes unit testing awkward (mocking a call that
  fires during `import checker` requires patching `boto3` *before* the
  import happens, not after — a heavier, less obvious test setup than
  patching a function that's called explicitly).
- **Secrets Manager instead of SSM Parameter Store** — this is a
  target list, not a secret; Secrets Manager's per-secret cost and
  rotation machinery buys nothing here that a free-tier SSM `String`
  parameter doesn't already cover.

**Consequences.** Each Lambda now needs `ssm:GetParameter`, scoped to
this one parameter's ARN (added to both `checker_exec` and `api_exec` in
`iam_monitor`) — a new permission, but a narrowly-scoped one, and the
tradeoff is real: config changes no longer require a code redeploy.

**Principle.** Separate *what changes together*. Code and its genuine
runtime configuration don't always belong in the same deploy — a target
list is data an operator should be able to edit without touching Lambda
code at all.

---

## Note: what tagging turned out to already be true

Checked whether the account-wide tagging strategy (`default_tags` on the
AWS provider, set once in `main.tf`) actually reaches every resource this
project created — it does, for everything created via the `aws` provider
directly. `aws_budgets_budget` is the one exception: AWS Budgets doesn't
support the provider's `default_tags` mechanism at all (it's a
account-level billing construct, not a regional resource), so the budget
alarm from Phase 1 is untagged and that's a property of the service, not
something to work around here.
