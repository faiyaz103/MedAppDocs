# 001 - Use Modular Monolith Architecture for Backend

- **Date:** 2026-06-06
- **Decision Makers:** Faiyaz Mahmud (Backend Developer)
- **Related ADRs:**
---

## Context
After reviewing the project requirements and resources, the findings are:
- Application is not too complex
- Light-weight
- Only 2 user roles
- Not heavily feature packed

## Decision

Will be following **Modular Monolith Architecture** as primary system architecture


---

## Rationale

### 1. Single deployable application
- Application can be deployed as a single unit
- Run a single instance/process

---

### 2. Clear module boundaries
- Features can be grouped and divided for modules
- Module to module communication 
    - **Synchronus:** Serviec to service
    - **Asynchronus:** Domain event

---

### 3. Highly scalable
- If future upgrade requires more complex architecture or independent services, upgrade to **Microservice Architecture** is less complex.

---