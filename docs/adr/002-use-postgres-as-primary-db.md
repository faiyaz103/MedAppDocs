# 002 - Use Postgres as Primary Database

- **Date:** 2026-06-06
- **Decision Makers:** Faiyaz Mahmud (Backend Developer)
- **Related ADRs:**
    - [Modular Monolith](001-use-modular-monolith.md)
---

## Context
- Modular Monolith Architecture
- Each module owns specific domain
- Domains are highly relational

## Decision
Will be using **Postgres as primary database**

---

## Rationale
- ACID transactions
- Foreign key constraints
- Unique constraints
- Indexing
- Join operations accross tables
---