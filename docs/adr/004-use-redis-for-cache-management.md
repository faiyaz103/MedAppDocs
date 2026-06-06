# 004 - Use Redis for Cache Management

- **Date:** 2026-06-06
- **Decision Makers:** Faiyaz Mahmud (Backend Developer)
- **Related ADRs:**
    - [Modular Monolith](001-use-modular-monolith.md)
    - [Postgres](002-use-postgres-as-primary-db.md)
---

## Context

As our modular monolith grows, we are seeing an increasing number of repetitive, read-heavy operations on our primary PostgreSQL database. Many of these reads involve data that changes infrequently, such as application configurations, user session states, global settings, and frequently viewed static content. 

Querying the relational database repeatedly for this static or semi-static data introduces unnecessary latency, consumes database CPU/memory resources, and limits overall system throughput. To achieve sub-millisecond response times for critical API endpoints and reduce the load on PostgreSQL, we require a high-performance, in-memory data store dedicated to caching and temporary state management.

## Decision

We will adopt **Redis** as our centralized, in-memory key-value store for cache management and session storage.

### Implementation Guardrails:
* **Mandatory TTLs (Time-To-Live):** Every single key stored in Redis must have an explicit TTL expiration set. This prevents "cache bloat" and ensures that stale data is naturally purged if invalidation logic fails.
* **Cache-Aside Pattern:** The application will use the Cache-Aside (Lazy Loading) pattern. When reading data, the application will check Redis first; if a cache miss occurs, it will fetch from PostgreSQL, write to Redis, and return the result.
* **Cache Key Namespacing:** In alignment with our modular monolith architecture, cache keys must be strictly isolated by module using structured prefixes (e.g., `module_name:entity:id`). One module must never access or modify the cache keys of another module.
* **Eviction Policy:** We will configure the Redis instance with an explicit eviction policy, specifically `volatile-lru` (Least Recently Used among keys with an expiration set), to ensure the system degrades gracefully under high memory pressure.

---

## Rationale

### Strengths & Advantages:
* **Sub-Millisecond Latency:** Operating entirely in-memory allows Redis to handle tens of thousands of operations per second with microsecond execution times.
* **Rich Data Structures:** Beyond simple string key-values, Redis supports hashes, lists, sets, and sorted sets, allowing us to implement advanced caching strategies (like rate-limiting counters or leaderboards) natively.
* **Horizontal Read Scalability:** Redis supports leader-follower replication, enabling us to easily spin up read replicas if our application's read demands increase.
* **Maturity and Ecosystem:** Redis is an industry-standard tool with robust client libraries available for virtually every modern backend programming language.

### Consequences & Trade-offs:
* **Cache Invalidation Complexity:** Keeping the cache synchronized with the primary database is notoriously complex. We will need to carefully write invalidation logic during data updates to avoid serving stale data.
* **Data Volatility:** Redis is primarily an in-memory store. While it offers persistence features (RDB/AOF), it must not be treated as a durable database. If the Redis instance restarts, any uncached data must be reconstructible from PostgreSQL.
* **Additional Infrastructure Component:** Introducing Redis increases our operational overhead, requiring dedicated monitoring for memory usage, hit/miss ratios, and connection pool sizing.

---