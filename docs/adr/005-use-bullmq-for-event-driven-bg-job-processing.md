# 004 - Use BullMQ for Event-Driven Background Job Processing

- **Date:** 2026-06-06
- **Decision Makers:** Faiyaz Mahmud (Backend Developer)
- **Related ADRs:**
    - [Modular Monolith](001-use-modular-monolith.md)
    - [Elasticsearch](003-use-elasticsearch-for-search-and-analytics.md)
---

## Context

As our modular monolith scales, we require a robust mechanism to handle asynchronous operations, long-running tasks, and decoupled communication between modules. Specifically, we face the following challenges:

* **Resource Intensive Tasks:** Operations like sending notifications, processing file uploads, and generating reports should not block the synchronous HTTP request-response lifecycle.
* **Asynchronous Data Sync:** Per ADR-003, we need a reliable way to stream data changes from PostgreSQL to Elasticsearch asynchronously without tightly coupling the domain modules to the search module.
* **Resiliency and Fault Tolerance:** Network requests to third-party APIs or internal module cross-invocations can fail. We need built-in retry mechanisms, exponential backoff, and dead-letter queuing to ensure no tasks are lost.

To achieve a reliable **Event-Driven Architecture (EDA)** within our modular monolith, we need a distributed task queue and message processing system.

## Decision

We will adopt **BullMQ** (powered by **Redis**) as our primary background job queue and internal event-driven message broker.

### Implementation Guardrails:
* **Infrastructure Backing:** Redis will be introduced into our infrastructure stack exclusively to back BullMQ for state management, pub/sub, and message storage. 
* **Event-Driven Integration:** Modules will communicate asynchronously by publishing events to specific BullMQ queues. For instance, when an entity is created in the `Order` module, an `order.created` event is queued. The `Search` module listens to this queue to sync the data to Elasticsearch.
* **Strict Idempotency:** Because network anomalies can cause jobs to be retried, all job consumers/event listeners must be designed to be strictly idempotent.
* **Queue Encapsulation:** Queues must respect modular monolith boundaries. Job definitions, data payloads, and workers should be isolated within their respective module directories.

---

## Rationale

### Strengths & Advantages:
* **Exceptional Performance:** Being backed by Redis, BullMQ operates entirely in-memory with disk persistence, capable of handling tens of thousands of jobs per second with minimal latency.
* **Advanced Feature Set:** It provides out-of-the-box support for complex workflows, including delayed jobs, cron-like repeatable jobs, parent-child job dependencies, rate limiting, and concurrency control.
* **Robust Error Handling:** BullMQ features automated retries with configurable exponential backoff strategies and shifts consistently failing jobs into a "failed" state for manual inspection.
* **Type Safety & Ecosystem:** It offers native, robust support for TypeScript/Node.js environments, aligning seamlessly with modern backend architectures and minimizing development friction.

### Consequences & Trade-offs:
* **Additional Infrastructure Component:** Introducing Redis increases our infrastructure footprint. We must monitor Redis memory utilization, configure persistence policies (RDB/AOF), and establish an eviction policy that prevents job data from being deleted.
* **Eventual Consistency Complexity:** Moving to an event-driven model means the system state across modules (and Elasticsearch) will be eventually consistent. Debugging and tracing distributed asynchronous workflows requires structured logging and correlation IDs.
* **Redis Memory Constraints:** BullMQ stores job payloads in Redis memory. Large payloads must be avoided; instead of passing full entity objects through the queue, workers should pass minimal references (e.g., Database IDs) and fetch the latest data directly from PostgreSQL during execution.

---