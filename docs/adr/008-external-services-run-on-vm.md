# 008 - Decide which external service to run along with backend in the same VM

- **Date:** 2026-06-07
- **Decision Makers:** Faiyaz Mahmud (Backend Developer)
- **Related ADRs:**
    - [Modular Monolith](001-use-modular-monolith.md)
    - [Postgres](002-use-postgres-as-primary-db.md)
    - [Elasticsearch](003-use-elasticsearch-for-search-and-analytics.md)
    - [Redis](004-use-redis-for-cache-management.md)
    - [BullMQ](005-use-bullmq-for-event-driven-bg-job-processing.md)
    - [Stripe](006-use-stripe-as-primary-payment-gateway.md)
---
## Tradeoff Analysis
### 1. BullMQ workers
Yes, often on the same VM But with an important nuance:
- BullMQ itself is not a standalone server.
- It is a Node.js library/runtime component used by your app/worker processes.

The job processors/workers can run:
- inside the same backend app
- or as a separate process on the same VM
- or on a different VM later if you scale

So for a modular monolith, it is very common to have:
- API process on the same VM
- worker process on the same VM
- both using the same Redis instance
---
### 2. Redis
Can run on the same VM in small/medium deployments, Common uses in this case:
- caching
- queue backend for BullMQ
- maybe rate limiting / session / distributed locks

Recommendation:
- Dev / MVP / low traffic: same VM is fine
- Production / higher traffic: often moved to a separate managed service or separate VM/container

Why separate it later?
- Redis is shared infrastructure
- If backend memory spikes, Redis can be affected
- If Redis restarts or gets overloaded, both cache and queue get impacted

So:
- Possible on same VM
- Common initially
- Often separated in serious production
---
### 3. Elasticsearch

Can technically run on the same VM, But usually not recommended unless:
- traffic is small
- dataset is small
- budget is tight
- you are in early-stage deployment
- Possible on the same VM for small setups

Why not usually on same VM?
Elasticsearch is:
- memory hungry
- disk intensive
- CPU intensive
- sensitive to JVM heap tuning
- likely to compete with your backend for resources

Usually better on a separate VM / container / managed cluster in production If you have:
- global search
- ranking
- autocomplete
- geo-aware search
- then Elasticsearch will likely deserve its own service boundary, even if your app is a modular monolith.
---
### 4. Postgres
they can run on the same VM — especially in:
- development
- small projects
- cost-sensitive deployments
- early-stage MVPs

But in production, they are often separated into:
- App VM / app server for the backend
- Dedicated DB VM / managed database for PostgreSQL
---
### 5. Stripe
- Stripe is a third-party external SaaS service
- You do not host Stripe on your VM
---
## Decision
- **Same VM:**
    - Postgres
    - BullMQ
    - Redis
    - Elasticsearch
- **Future scope:**
    - Seperate VM can be considered for **Redis** and **Elasticsearch** after observing production performance