# 005 - Use Stripe as the Primary Payment Gateway

- **Date:** 2026-06-06
- **Decision Makers:** Faiyaz Mahmud (Backend Developer)
- **Related ADRs:**
    - [Modular Monolith](001-use-modular-monolith.md)
    - [Postgres](002-use-postgres-as-primary-db.md)
    - [Event-driven Backgorund Job Processing](005-use-bullmq-for-event-driven-bg-job-processing.md)
---

## Context

As our platform facilitates financial transactions, we require a highly secure, reliable, and globally compliant payment processing solution. Building and maintaining a custom payment engine would expose us to immense regulatory burdens, specifically regarding PCI-DSS compliance, and would severely distract from our core business logic. 

Our system specifically requires support for:
* **Customer Management:** Creating and managing customer profiles to track payment histories.
* **Multi-party Routing:** Creating connected accounts to facilitate payouts to third-party sellers, contractors, or partners on our platform.
* **Payment Methods:** Securely adding, storing (tokenizing), and removing payment methods (credit cards, digital wallets) for returning users.
* **Transaction Flow:** Generating Payment Intents, handling seamless checkout experiences, and securely capturing funds.
* **Post-transaction Operations:** Processing partial or full refunds.

We need a third-party vendor that supports all these capabilities via a robust API while integrating cleanly with our event-driven architecture.

## Decision

We will adopt **Stripe** as our exclusive payment gateway and implement a dedicated, isolated `Payment` (or `Billing`) module within our modular monolith.

### Implementation Guardrails:
* **Offloaded PCI Compliance:** The backend will never touch or store raw Primary Account Numbers (PAN) or sensitive card details. The frontend will utilize Stripe Elements or Stripe Checkout to securely tokenize payment methods directly with Stripe's servers. Our database will only store opaque Stripe IDs (e.g., `cus_...`, `pi_...`, `pm_...`).
* **Stripe Connect:** We will utilize Stripe Connect (Custom or Express, depending on onboarding UI requirements) to manage connected accounts and facilitate multi-party fund routing.
* **Webhook-Driven Verification:** The system will not rely on synchronous client-side confirmations to mark a payment as successful. Instead, we will expose a secure webhook endpoint to receive asynchronous events from Stripe (e.g., `payment_intent.succeeded`).
* **Event-Driven Integration:** Upon receiving and verifying a Stripe webhook signature, the `Payment` module will publish an internal event (e.g., `payment.succeeded`) to **BullMQ**. Other modules (like `Order` or `Fulfillment`) will listen to this queue to update their local database state in PostgreSQL, ensuring decoupled reliability.

---

## Rationale

### Strengths & Advantages:
* **Comprehensive Feature Set:** Stripe's API natively covers all our requirements out-of-the-box, from standard PaymentIntents to complex Connect routing and automated refund handling.
* **Developer Experience:** Stripe provides exceptionally well-documented APIs, strongly typed Node.js/TypeScript SDKs, and a robust CLI for local webhook testing.
* **Security & Compliance:** Offloading raw card data collection to Stripe entirely removes the burden of achieving strict PCI compliance from our infrastructure.
* **Ecosystem Reliability:** Stripe handles edge cases like SCA (Strong Customer Authentication) and 3D Secure transparently, ensuring high authorization rates globally.

### Consequences & Trade-offs:
* **Vendor Lock-in:** Migrating away from Stripe in the future (especially migrating vaulted credit cards and connected accounts) is a highly complex and time-consuming process.
* **Operational Costs:** Stripe charges per-transaction fees (and additional fees for Connect features and payouts) which will impact profit margins as transaction volume scales.
* **Idempotency Requirements:** Because Stripe webhooks can be delayed or delivered more than once, our webhook handlers and downstream BullMQ workers must be strictly idempotent to prevent double-crediting users or fulfilling the same order twice.
* **Testing Complexity:** Simulating payment states (like declined cards, disputes, or delayed clearing) requires careful management of Stripe test cards and test clocks in staging environments.

---