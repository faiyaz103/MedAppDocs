# Architcturally Significant Requirements
---
## Expected user roles & use cases
1. Patient
    - Authenticated & authorized
    - Create and edit profile information
    - Can deactivate profile
    - Search and view hospitals, doctors, services, packages
    - Select a service and compare with another service
    - can book/cancel booking of a service
    - Uses stripe as payment gateway to make payments
    - Make payment for a booked service
    - Add or remove payment method
    - Set default payment method
    - Request for payment refund
2. Admin
    - Authenticated & authorized
    - Create and edit profile information
    - Add, edit or remove hospital information, directors, doctors, services and packages
    - Add, edit or remove investigations, consultations, facilities and procedures
    - Uses stripe as payment gateway to recieve payments
    - Can accept or reject refund request from patient 
---
## Security/compliance expectations
1. **JWT** with `Refresh Token Rotation Strategy` for **Authentication**, **Authorization** and **Role Based Access Control**
2. `Application Level Encryption (AES-256 GCM)` to secure sensitive columns in database
3. Use of **Validation Pipe** & **DTO's**
---
## Integration requirements
1. **Postgres:** Primary Data Storage
    - Relational Database Management System
    - Transactional Consistency
2. **Stripe:** Payment gateway
    - Create customer account
    - Create connected account
    - Add/remove payment method
    - Make payment intent
    - Pyament checkout
    - Refund
3. **Elasticsearch:** Distributed search and analytics engine
    - Global search across many entities
    - Search with ranks
    - Autocomplete/instant suggestions
    - Geo-aware features
4. **Redis:** Cache management
5. **BullMQ:** Background job queue / task processing system
    - Event-Driven Architecture
---
## Infrastructure requirements
1. **Docker:** Runs the container in development
    - Elasticsearch
    - Redis
    - CI/CD
---

