---
layout: post
date: 2026-07-10
---
# Site Reliability Engineering: A Field Primer

Notes from the Google SRE book, my own work experience and various resources online.

## Contents

1. What SRE Actually Is
2. Core Vocabulary
3. The Observability Triad
4. Monitoring & Alerting Philosophy
5. Incident Management
6. Change Management & Deployment Safety
7. Distributed Systems Fundamentals
8. Data & State Management
9. Networking Reality Checks
10. Capacity Planning & Performance
11. The Toolchain Landscape
12. Chaos Engineering
13. Security-Adjacent Concerns
14. Org Patterns & Team Models
15. Career Progression
16. Essential Reading
17. Week 1 Checklist
18. Common Junior SRE Mistakes

---

## 1. What SRE Actually Is

Origin: Google, ~2003, when Ben Treynor Sloss founded the team on a specific premise — put software engineers in charge of operations, and they'll solve operational problems the way engineers solve problems: by writing software that eliminates the problem, not by doing the manual task better by hand. That premise is still the core of the discipline.

- **The compact version:** reliability is treated as a product feature with a measurable target, not an unbounded goal you throw infinite effort at. Once you have a number (the SLO), "how reliable should this be" stops being a religious argument and becomes an engineering tradeoff.
- **SRE vs. sysadmin:** traditional ops is reactive and manual — tickets, runbooks executed by hand, "keep the lights on." SRE's mandate is to automate itself out of that work.
- **SRE vs. DevOps:** DevOps is a cultural philosophy (break down the dev/ops silo, "you build it, you run it," shift left). SRE is one concrete, prescriptive implementation of that philosophy, with specific mechanisms — error budgets, SLOs, blameless postmortems — that turn the philosophy into decisions you can actually make.
- **SRE vs. Platform Engineering:** platform engineering focuses on building internal self-service infrastructure ("golden paths") so product teams don't need deep infra expertise. Heavy overlap with SRE in practice; sometimes a rebrand, sometimes a genuinely distinct function more focused on developer experience than production reliability specifically.
- **The permanent tension SRE exists to manage:** feature velocity vs. system stability. Every org wants both; they trade off against each other. The error budget is the mechanism that turns that philosophical tension into a number.
- **Expect real code, not just scripts.** The "engineering" in the name isn't decorative — writing tools and automation (commonly Python, Go, Bash) is core to the job, not an occasional nice-to-have.

## 2. Core Vocabulary

| Term | Meaning |
|---|---|
| **SLI** | Service Level Indicator — an actual measured metric, e.g. "% of requests completing in <300ms" |
| **SLO** | Service Level Objective — your internal target for an SLI over a time window, e.g. "99.9% over 30 days" |
| **SLA** | Service Level Agreement — external, contractual, usually looser than your SLO, with financial/legal consequences if breached |
| **Error budget** | 1 − SLO. Budget remaining → ship features. Budget exhausted → freeze feature work, fix reliability |
| **Toil** | Manual, repetitive, automatable work with no lasting engineering value. Google's rule of thumb: keep it under 50% of an SRE's time |
| **MTTD / MTTA / MTTR / MTBF** | Mean time to detect / acknowledge / resolve / between failures |
| **Blast radius** | How much breaks if this one thing fails |
| **Runbook** | Step-by-step instructions for a known, specific situation |
| **Playbook** | A broader decision framework for a class of situations — less prescriptive than a runbook |
| **Blameless postmortem** | An incident retro focused on systemic and process causes, not individual fault |
| **Canary** | A small-percentage rollout used to catch regressions before a full deploy |
| **Circuit breaker** | A pattern that stops calling a failing dependency to prevent cascading failure |
| **Bulkhead** | Isolating resource pools per-dependency so one slow dependency can't starve the rest |

**Availability, the "nines"** (30-day month convention):

| Availability | Downtime / year | Downtime / month | Downtime / day |
|---|---|---|---|
| 99% | 3.65 days | 7.2 hours | 14.4 min |
| 99.9% | 8.76 hours | 43.2 min | 1.44 min |
| 99.95% | 4.38 hours | 21.6 min | 43.2 sec |
| 99.99% | 52.6 min | 4.32 min | 8.64 sec |
| 99.999% | 5.26 min | 25.9 sec | 0.86 sec |
| 99.9999% | 31.5 sec | 2.59 sec | 86.4 ms |

Six nines gets cited for telecom/network backbone occasionally; treat it as a curiosity, not a realistic target for application software.

## 3. The Observability Triad

- **Metrics** — numeric time series. Cheap at scale, best for trends/aggregates/dashboards/alerting. Types: counters (monotonic, e.g. request count), gauges (point-in-time, e.g. memory usage), histograms (distributions, e.g. latency buckets for percentiles). Main operational hazard: **cardinality** — every unique label combination is a new time series, and an unbounded label (like a raw user ID) can blow up your metrics backend.
- **Logs** — discrete, timestamped events. Richest detail, most expensive at scale. Structured logging (JSON/key-value) beats free text for querying, every time. At real volume you can't afford to log everything, so sampling strategy is a real design decision, not an afterthought.
- **Traces** — a single request's journey across service boundaries. Composed of spans, requires context propagation (a trace ID threaded through headers across every hop). Becomes essential the moment you have more than a couple of services, because the symptom and the root cause frequently live in different services entirely. OpenTelemetry is the emerging vendor-neutral standard unifying instrumentation across all three signals.
- **Combining them — three mental models worth memorizing:**
  - **RED** (Rate, Errors, Duration) — request-oriented, for services.
  - **USE** (Utilization, Saturation, Errors) — resource-oriented, for hosts/hardware/queues.
  - **Four Golden Signals** (Latency, Traffic, Errors, Saturation) — Google's version, essentially RED plus saturation.

## 4. Monitoring & Alerting Philosophy

- **Alert on symptoms, not causes.** A symptom-based alert ("error rate > X%") catches many possible causes. A cause-based alert ("disk queue depth > Y") catches exactly one cause and pages you for things that never actually hurt a user.
- **Alert fatigue is the central disease of bad on-call.** Noisy pages get ignored or silenced, and then the real incident gets missed inside the noise. The fix isn't "pay closer attention" — it's redesigning what's allowed to page a human at all.
- **The test for every page: does a human need to act right now?** If not, it's a dashboard entry or a low-urgency notification, not a page.
- **SLO-based / burn-rate alerting.** Instead of static thresholds ("CPU > 90%"), alert on how fast you're consuming your error budget. Multi-window, multi-burn-rate alerting (checking both a short window and a long window at once) catches fast severe outages and slow creeping degradations without drowning you in noise from either.

## 5. Incident Management

- **Severity taxonomy** (naming varies — SEV1–5, P1–P4, whatever) exists to give the org a shared vocabulary for urgency, so response scales appropriately instead of every incident getting either over- or under-reacted to.
- **Roles in a major incident:** Incident Commander (coordinates; often doesn't personally touch the fix), Operations Lead (drives technical mitigation), Communications Lead (updates stakeholders/status page), Scribe (keeps the timeline of record). Juniors usually start as an ops-lead contributor, not IC.
- **The single highest-leverage lesson for a junior engineer: mitigate first, root-cause later.** Roll back, fail over, or scale up now. Save "why did this actually happen" for after users stop being affected. New engineers instinctively want to understand before acting — during a live incident, that instinct is backwards.
- **Blameless postmortems exist for a mechanical reason, not a nice one:** punishing individuals for mistakes causes people to hide the information you need to prevent recurrence. A good postmortem has a factual timeline with timestamps, quantified customer impact, root cause(s) — rarely singular; "5 whys" helps you dig past the first, superficial answer — and action items with named owners and deadlines. An action item with no owner never happens.
- **On-call structure:** rotation length (weekly is common), escalation policy (who gets paged if the primary doesn't ack within N minutes), and load. Google explicitly tracks and caps incidents-per-shift as a health signal for unsustainable operational load — high on-call load is a bug to fix, not a badge of honor.

## 6. Change Management & Deployment Safety

- Empirically, most production incidents trace back to a recent change — a deploy, a config push, a flag flip — rather than to "organic" failure like hardware dying on its own. That's why deployment safety mechanisms are disproportionately high-leverage for reliability.
- **Canary releases:** ship to a small percentage of traffic/instances first, watch the key metrics, then widen progressively. Automated canary analysis compares canary metrics against a baseline statistically, rather than relying on someone eyeballing a dashboard.
- **Feature flags** decouple "deployed" from "enabled." You can ship dark code to prod and flip it on independently — which also gives you an instant rollback (flip the flag back) that's faster than a redeploy.
- **Rollback should always be faster than forward-fixing.** If your rollback path is slower or riskier than fixing forward, that's a standing reliability risk worth closing before you need it under pressure.
- **Immutable infrastructure + infra-as-code** (Terraform etc.) matter for reliability, not just convenience: they make "what does prod actually look like right now" a knowable, versioned fact instead of oral tradition, and they make infra rollback as mechanical as code rollback.

## 7. Distributed Systems Fundamentals

- **CAP theorem:** under a network partition, pick consistency or availability — not both. In practice most real systems live on a tunable spectrum rather than a hard corner. **PACELC** extends the idea: even with no partition, you still trade latency against consistency.
- **Replication & quorum:** majority-based reads/writes (write to N nodes, need W+R>N acks) trade latency for durability/consistency guarantees.
- **Idempotency:** design operations so retries are safe. Retrying a non-idempotent "charge $10" without an idempotency key can double-charge. Idempotency keys are how "at-least-once" delivery behaves like "exactly-once" from the caller's point of view.
- **Retry storms / thundering herd:** naive retries — especially synchronized ones, everyone retrying on the same fixed interval — can turn a brief blip into a sustained outage by multiplying load on a service at exactly the moment it's trying to recover. Exponential backoff with jitter (randomized delay) is the standard fix.
- **Circuit breakers & bulkheads:** circuit breakers stop calling a failing dependency past a failure threshold, giving it room to recover and protecting your own threads/connections from being tied up waiting on something dead. Bulkheads isolate resource pools per-dependency so one slow dependency can't starve calls to healthy ones.
- **Cascading failure:** a local failure (one service gets slow) causes callers to queue up, hold resources, and retry — which makes the callers slow — which cascades to their callers, and so on. A small localized problem becomes a global outage. This mechanism is probably the single most valuable piece of systems intuition for reliability work generally.

## 8. Data & State Management

- **Untested backups are not backups.** A backup you've never restored from is a hypothesis, not a safety net. Regular restore drills are the only way to know your backup strategy actually works, and they routinely surface surprises — corrupted backups, missing pieces, restore times far too slow for your actual RTO.
- **Replication lag** means "write succeeded" and "readable everywhere" are not the same moment. Read-after-write consistency bugs are one of the most common state-related surprises for engineers coming from stateless-service backgrounds.
- **Failover mechanics:** automatic failover is faster but risks split-brain (two nodes both think they're primary) without careful fencing/consensus; manual failover is slower but more controlled. Most mature systems use consensus protocols (e.g. Raft) specifically to make automatic failover safe.
- **RTO vs. RPO:** Recovery Time Objective (how long can you be down) and Recovery Point Objective (how much data can you afford to lose) are two different numbers driving two different sets of engineering decisions. Conflating them is a common planning mistake.
- Stateful systems are categorically harder to operate than stateless ones — which is why many SRE orgs treat database/storage reliability as a distinct sub-specialty rather than something every generalist is expected to own equally.

## 9. Networking Reality Checks

The unglamorous stuff that causes a disproportionate share of real outages:

- **"It's always DNS"** is a running joke because it's often literally true — misconfigurations, propagation delay, and resolver caching produce a lot of "mysterious" outages relative to how rarely anyone thinks about DNS until it breaks.
- **TLS certificate expiry** is a shockingly common self-inflicted outage category. Automated renewal (cert-manager, ACME/Let's Encrypt) and expiry alerting well before the actual deadline are baseline hygiene, not optional extras.
- **Load balancer health checks** need the right depth. Too shallow ("process is listening on the port") and you won't catch a process that's up but can't actually serve — e.g. DB pool exhausted. Too deep/expensive and the health check itself becomes a load problem.
- **Connection pool exhaustion** has a classic, misleading symptom: timeouts and 5xxs that look exactly like "the downstream is down," when the actual cause is that every connection in a pool is held by slow/stuck requests, so new requests can't even get a connection to try.
- **Default timeouts matter more than people expect.** Client library defaults are sometimes absurdly long or nonexistent. A service with no timeout on a call to a slow dependency will happily let its own resources be consumed indefinitely instead of failing fast.

## 10. Capacity Planning & Performance

- **Percentiles, not averages.** An average latency of 50ms can hide a p99 of 3 seconds — and that p99 is exactly the users having a bad time, which the average actively conceals. Look at p50/p95/p99/p999 together. At high request volume, "0.1%" (p999) can still mean thousands of bad requests a day.
- **Queuing intuition worth internalizing without doing the math:** as utilization approaches 100%, queue length and wait time increase non-linearly. A system running at 95% utilization is much closer to falling over than "95%" sounds, because small further load increases cause disproportionate latency blowup. This is why capacity headroom targets usually sit well under 100% (often 60–80%, depending on traffic variance).
- **Load testing** (sustained expected load), **stress testing** (find the actual breaking point), **soak testing** (find slow leaks — memory, file descriptors, connection pools — that only show up after hours or days).
- **Autoscaling:** reactive (scale on a current metric, e.g. CPU) vs. predictive (scale ahead of known cyclical patterns). Reactive-only scaling always lags real demand by however long your scale-up takes — which matters a lot when scale-up is slow.

## 11. The Toolchain Landscape

- **Orchestration:** Kubernetes is the dominant default at this point.
- **Infra-as-code:** Terraform (and OpenTofu, its post-license-change fork), Pulumi, or cloud-native equivalents (CloudFormation, etc.).
- **CI/CD:** GitHub Actions, GitLab CI, Jenkins (older, still everywhere), and GitOps-style continuous delivery via ArgoCD/Flux, where deployed state is continuously reconciled from a git repo rather than pushed imperatively.
- **Observability:** Prometheus + Grafana for metrics (the de facto open-source standard), OpenTelemetry as the vendor-neutral instrumentation layer, plus commercial platforms (Datadog, Honeycomb, New Relic) and log stacks (ELK/OpenSearch, Loki).
- **Incident tooling:** PagerDuty/Opsgenie for paging and escalation, plus chat-ops-style incident bots for coordinating a live incident.
- **Config management** (older generation, still common in legacy fleets): Ansible, Chef, Puppet — mostly superseded by container images + IaC for new work.
- **Chaos engineering:** Chaos Mesh, Litmus, Gremlin (commercial), and the original Chaos Monkey (Netflix).
- **eBPF-based tooling** is the frontier worth knowing exists: kernel-level tracing and observability (Cilium, Pixie, Parca) without needing to modify application code — an increasingly relevant bridge between "observability" and "systems-level" work.

## 12. Chaos Engineering

- **The principle:** failure is inevitable at scale, so deliberately and safely inject it under controlled conditions — limited blast radius, business hours, a rollback plan ready — to find weaknesses before an uncontrolled failure finds them for you.
- **Game days / DiRT-style exercises:** scheduled, sometimes cross-team, simulated-disaster drills ("the primary region is gone, go") that test both the technical failover and the human process — does the on-call actually know the runbook, does paging actually work. Testing people and process matters as much as testing the system, and it's often the part that fails first in these drills.

## 13. Security-Adjacent Concerns

Not the same discipline as security engineering, but SRE work regularly touches: secrets management (no plaintext secrets in configs/env vars/git history), least-privilege production access with break-glass patterns for emergencies, patch/vulnerability cadence across the fleet, and — increasingly — supply-chain awareness (SBOMs, dependency provenance), given how many incidents now originate in third-party or open-source dependencies rather than first-party code.

## 14. Org Patterns & Team Models

- **Embedded SRE** (SREs sit inside product teams) vs. **centralized/platform SRE** (a dedicated team providing shared infra/tooling/on-call across many product teams) vs. **no dedicated SRE at all** (developers on-call for their own services, DevOps-native). These aren't mutually exclusive — most large orgs run a mix.
- **Production Readiness Review (PRR):** a gate a new service passes — defined SLOs, adequate monitoring/alerting, runbooks, tested failover, a capacity plan, on-call staffing — before an SRE team agrees to take it into rotation, or before it's allowed real production traffic.
- **Toil negotiation** is a recurring organizational tension, not just a technical one: SRE teams often explicitly push back on absorbing more manual operational burden from product teams unless those teams also invest in automation and observability.

## 15. Career Progression

- Junior → Mid → Senior → Staff+ roughly tracks three things: **scope of ownership** (a service → a domain → an org's whole reliability posture), **tolerance for ambiguity** (given a runbook → given a vague problem → defining what the problem even is), and **influence** (doing the fix → designing the fix → setting the standard other teams follow).
- The common ideal is a **T-shaped profile:** broad competence across the stack (networking, Linux, at least one cloud, a couple of languages, distributed-systems basics) plus genuine depth in one or two areas — Kubernetes internals, storage/database internals, a specific observability domain — that becomes your actual differentiator.
- Being trusted to run **Incident Commander** for a major incident is one of the clearer, more legible markers of seniority in most SRE orgs, because it requires calm judgment under pressure across systems you may not personally own.

## 16. Essential Reading

- ***Site Reliability Engineering*** (Google, free online) — the foundational text. Some practices are calibrated to Google's scale and don't transfer 1:1 to smaller orgs; read it for the concepts more than the literal prescriptions.
- ***The Site Reliability Workbook*** — the "how" companion to the first book's "what," more applied/practical.
- ***Seeking SRE*** (ed. David N. Blank-Edelman) — essays from practitioners outside Google; a useful counterweight to the Google-only perspective.
- ***Accelerate*** (Forsgren, Humble, Kim) — the empirical research behind most DevOps/SRE practice claims. Genuinely evidence-based rather than anecdotal; worth reading for the methodology alone.
- ***The Phoenix Project*** / ***The Unicorn Project*** (Gene Kim et al.) — narrative business novels dramatizing DevOps transformation. Fast, easy reads, good for the organizational "why."
- ***Systems Performance*** (Brendan Gregg) — deep technical reference for performance analysis methodology, heavily Linux-focused.
- ***Designing Data-Intensive Applications*** (Martin Kleppmann) — not SRE-specific, but arguably the single best book for the distributed-systems intuition SRE work leans on constantly.

## 17. Week 1 Checklist

- Find and read: your team's on-call runbook, its escalation policy, and the SLO dashboard(s) for your service(s).
- Read the last 5–10 postmortems in the archive. This teaches you the system's actual failure modes faster than any architecture doc, because it's where the real incidents — not the idealized diagram — live.
- Trace your deploy pipeline end-to-end once, manually, watching every stage (trigger → build → test → staging → prod), instead of trusting the README's description of it.
- Learn where metrics, logs, and traces actually live, and run one real query in each before you need it under pressure.
- Shadow at least one on-call rotation before taking a solo shift.
- Ask around informally what the single most fragile or most-complained-about part of the system is. Every system has one, it's rarely documented, and knowing it early saves real time later.

## 18. Common Junior SRE Mistakes

- Trying to fully root-cause during a live incident instead of mitigating first (§5).
- Under-escalating — not paging because "I don't want to bother anyone." The failure mode orgs actually worry about is under-escalation, not over-escalation. Paging the wrong person costs two minutes; staying silent on a growing incident doesn't.
- Not keeping a timestamped log of actions taken during an incident. You will not remember the exact sequence afterward, and the postmortem timeline depends on it.
- Treating every alert as equally urgent — which is exactly what produces alert fatigue in yourself.
- Automating a manual process before understanding why it's currently manual. Sometimes "toil" persists because of an edge case the automation would silently break.
- Trusting a dashboard's silence as evidence of health. A metric that was never instrumented can't alert you — "nothing's alerting" and "everything's fine" are not the same statement.

---

*This gets you the vocabulary and mental models. It doesn't replace reading your team's actual architecture docs or sitting through a real incident — it just means you'll understand both faster when you hit them.*
