# 003 - Use Elasticsearch for Search and Analytics

- **Date:** 2026-06-06
- **Decision Makers:** Faiyaz Mahmud (Backend Developer)
- **Related ADRs:**
    - [Modular Monolith](001-use-modular-monolith.md)
    - [Postgres](002-use-postgres-as-primary-db.md)
---

## Context

We are building our backend system using a **modular monolith** topology with **PostgreSQL** as our primary transactional database. While PostgreSQL provides robust ACID compliance and handles structured relational queries exceptionally well, our application requirements include features that Postgres is not optimally designed to handle at scale:

* **Advanced Search Capabilities:** High-performance full-text search, fuzzy matching, auto-complete (search-as-you-type), and multilingual relevance scoring.
* **Performance Isolation:** Running heavy, non-transactional search and aggregation queries on our primary OLTP database risks locking tables and degrading core transactional performance.
* **Scalability:** The volume of searchable data and read-heavy search requests is expected to grow exponentially, requiring horizontal scaling for search operations without necessarily scaling the primary relational database.

We need a dedicated solution to offload search and analytical workloads from PostgreSQL while maintaining the architectural boundaries of our modular monolith.

## Decision

We will adopt **Elasticsearch** as a secondary data store, specifically optimized for read-heavy search, filtering, and analytical queries. 

### Implementation Guardrails:
* **Source of Truth:** PostgreSQL remains the absolute single source of truth. Elasticsearch will store denormalized views of the data strictly for querying purposes.
* **Data Synchronization:** Data will be synchronized from PostgreSQL to Elasticsearch asynchronously. To prevent tight coupling, we will use an event-driven approach within the monolith (e.g., application-level events or a transactional outbox pattern) to update Elasticsearch indices.
* **Encapsulation:** In alignment with our modular monolith architecture, Elasticsearch access will be isolated within a specific `Search` or `Analytics` module, exposed to other modules via strict internal APIs or interfaces.

---

## Rationale

### Strengths & Advantages:
* **Superior Search Experience:** Elasticsearch provides out-of-the-box support for inverted indices, TF-IDF / BM25 relevance scoring, stemming, tokenization, and fuzzy matching that would be complex and inefficient to replicate in PostgreSQL.
* **Resource Isolation:** By routing complex search queries to Elasticsearch, we preserve PostgreSQL’s CPU and memory for critical write operations and ACID-compliant transactions.
* **Horizontal Scalability:** Elasticsearch scales horizontally by adding more nodes and distributing data across shards, allowing us to handle spikes in search traffic effortlessly.
* **Analytical Power:** It enables fast aggregations and metrics over millions of documents, supporting potential future dashboard or reporting features.
* **Geo-location features:** Supports geo-spatial data types

### Consequences & Trade-offs:
* **Eventual Consistency:** Because synchronization is asynchronous, there will be a minor lag (typically milliseconds) between data being written to PostgreSQL and appearing in search results. The application must be designed to tolerate this.
* **Operational Complexity:** Introducing Elasticsearch adds a new component to our infrastructure stack, requiring monitoring, cluster management, index lifecycle management (ILM), and backup strategies.
* **Code Overhead:** The development team will need to maintain data sync logic and handle dual-writing/mapping strategies, which increases the initial development footprint.

---