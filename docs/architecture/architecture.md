# C4 Model Diagrams
## 1. System Context Diagram
```mermaid
flowchart LR
  Patient[Patient]
  Admin[Admin]
  MedApp[MedApp]
  Stripe["Stripe API\nPayments + Webhooks"]

  Patient -->|Auth + Create/Edit Profile\nBook Services| MedApp
  MedApp -->|Response| Patient

  Admin -->|Auth + Create/Edit Profile\nHospital Info, Packages, Services| MedApp
  MedApp -->|Response| Admin

  MedApp -->|Call Payment APIs| Stripe
  Stripe -->|Responses + Webhook Events| MedApp

  ```