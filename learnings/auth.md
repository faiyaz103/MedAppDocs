# 001 - JWT Authentication, Authorization, and RBAC with Refresh Token Rotation

- **Date:** 2026-06-06
- **Decision Makers:** `<Your Name>`, `<Team/Architect Name>`
- **Related ADRs:**
  - ADR-000 - Modular Monolith Architecture
  - ADR-00X - PostgreSQL as Primary System of Record
  - ADR-00Y - Redis for Caching and Ephemeral State
  - ADR-00Z - Event-Driven Internal Communication
  - ADR-00A - BullMQ for Background Jobs

---

## Context

The system is being built as a **modular monolith** with **PostgreSQL** as the primary database, **Redis** for caching and ephemeral state, **BullMQ** for background jobs, and an **event-driven architecture** for internal module communication.

The platform needs a secure and maintainable approach for:

1. **Authentication**
   - Sign up
   - Sign in
   - Access token issuance
   - Refresh token issuance and rotation
   - Logout and revocation
   - Session tracking

2. **Authorization**
   - Verifying authenticated users on protected routes
   - Enforcing route- and resource-level access rules

3. **Role-Based Access Control (RBAC)**
   - Assigning roles to users
   - Mapping roles to permissions
   - Enforcing permissions consistently across modules

The authentication and authorization design must satisfy the following:

- Support **stateless API authentication** for normal request processing
- Support **server-side session control** for logout, password change, and forced revocation
- Reduce risk from stolen long-lived tokens
- Support **role and permission changes** with timely effect
- Fit the current **modular monolith** while remaining compatible with future service extraction
- Leverage **Redis** for performance and ephemeral security state
- Integrate with **event-driven flows** for audit logging, notifications, and async side effects

A pure JWT-only approach is not sufficient because the system also requires:

- logout and session revocation
- refresh token theft detection
- password-change-triggered invalidation
- role/permission changes to eventually or immediately affect users
- device/session visibility and management

Therefore, the system requires a hybrid approach:

- **short-lived JWT access tokens**
- **stateful refresh tokens with rotation**
- **RBAC enforcement using roles and permissions**
- **Redis-backed caching and short-lived security state**
- **PostgreSQL as the source of truth**
- **internal events** for security and operational workflows

---

## Decision

We will implement **JWT-based authentication** using:

- **short-lived JWT access tokens**
- **refresh token rotation**
- **bcrypt password hashing**
- **RBAC for authorization**
- **PostgreSQL as the source of truth**
- **Redis for ephemeral session/cache support**
- **event publication for security-relevant changes**

### 1. Authentication Model

#### 1.1 Access Token

The system will issue a **short-lived JWT access token** after successful authentication.

**Characteristics**
- Signed by the server
- Sent in `Authorization: Bearer <token>`
- Used to authenticate protected API requests
- Contains enough identity context for request processing
- Kept short-lived to limit damage if stolen

**Recommended claims**
- `sub` -> user ID
- `sid` -> session ID
- `jti` -> unique token ID
- `iat` -> issued-at timestamp
- `exp` -> expiration timestamp
- `iss` -> issuer
- `aud` -> audience
- `authz_version` -> optional version to detect stale authorization state
- optionally `roles` -> only if token size and role volatility are acceptable

**Recommended TTL**
- `5-15 minutes`

---

#### 1.2 Refresh Token

The system will issue a **refresh token** together with the access token.

**Characteristics**
- Long-lived compared to access token
- Used only to obtain a new access token and a new refresh token
- Never used to call business APIs directly
- Stored securely by the client
- Rotated on every successful refresh
- Stored server-side only as a **hash**, never as plaintext

**Recommended TTL**
- `7-30 days`, depending on product security requirements

**Client storage**
- For browser-based clients, prefer **HttpOnly + Secure + SameSite cookie**
- For trusted native clients, store in secure platform storage

---

### 2. Refresh Token Rotation Strategy

Refresh tokens will follow a **single-use rotation strategy**.

On every successful refresh request:

1. the presented refresh token is validated
2. the currently active refresh token is invalidated
3. a new refresh token is generated
4. a new access token is generated
5. the session state is atomically updated

This ensures that an old refresh token becomes unusable immediately after it has been exchanged.

---

### 3. Session and Token Persistence

#### 3.1 PostgreSQL as Source of Truth

The system will persist session metadata in PostgreSQL.

**Recommended session fields**
- `id`
- `user_id`
- `token_family_id`
- `refresh_token_hash`
- `status` (`active`, `revoked`, `reused`, `expired`)
- `created_at`
- `expires_at`
- `last_used_at`
- `rotated_at`
- `revoked_at`
- `revocation_reason`
- `ip_address` (optional)
- `user_agent` (optional)

**Important rules**
- Never store raw refresh tokens
- Only store a cryptographic hash of the refresh token
- Sessions are revocable
- A refresh token belongs to a session or token family
- Reuse detection can revoke the whole token family

---

#### 3.2 Redis for Ephemeral Security State

Redis will be used for high-speed, short-lived, and frequently accessed auth-related data.

**Redis usage in this design**
1. **Session cache**
   - Cache active session metadata to reduce DB lookups on refresh
   - Example: `session:<sid> -> { userId, status, tokenFamilyId, expiresAt }`

2. **Refresh token lookup optimization**
   - Cache token/session mapping for fast refresh validation
   - TTL aligned with refresh token expiration

3. **Revocation markers**
   - Store revoked session IDs, token families, or token JTIs for immediate invalidation
   - Useful for emergency logout or detecting compromised sessions

4. **Authorization cache**
   - Cache `roles`, `permissions`, and `authz_version`
   - Example: `authz:user:<userId>`

5. **Rate limiting / abuse prevention**
   - Login attempt counters
   - Refresh attempt counters
   - Password reset request throttling
   - Temporary lockouts

6. **Cross-module invalidation signaling**
   - Invalidate cached authorization/session state quickly when:
     - roles change
     - password changes
     - sessions are revoked
     - refresh token reuse is detected

Redis is **not** the source of truth. PostgreSQL remains authoritative.

---

### 4. Password Hashing

Passwords will be hashed using **bcrypt**.

**Decision**
- Use `bcrypt` for password hashing and verification
- Never store plaintext passwords
- Never use reversible encryption for passwords

**Password hashing rules**
- Use a strong bcrypt cost factor appropriate for the deployment environment
- Use library-managed salts
- Compare passwords using secure verification functions
- Rehash passwords when policy changes require stronger cost factors
- Optionally use a server-side pepper managed in secret storage

**When passwords change**
- Revoke all active sessions for that user
- Invalidate Redis session and authorization cache
- Emit a security event
- Require re-authentication on all devices if policy requires it

---

### 5. Authorization Model

Authentication confirms **who the user is**. Authorization confirms **what the user can do**.

All protected routes must pass through authentication and authorization layers.

#### 5.1 Authentication on Protected Requests

For each protected API request:

1. Validate access token signature and standard claims
2. Extract identity from JWT
3. Optionally verify session status for sensitive routes
4. Build current authorization context
5. Apply RBAC checks

If token validation fails, return **`401 Unauthorized`**.

---

### 6. RBAC Model

The system will use **Role-Based Access Control (RBAC)** with optional permission-level enforcement.

#### 6.1 Data Model

**Recommended tables**
- `users`
- `roles`
- `permissions`
- `user_roles`
- `role_permissions`

#### 6.2 Rules

- A user can have one or more roles
- A role can have one or more permissions
- Endpoints declare required role(s) and/or permission(s)
- Authorization guards enforce access before business logic executes

#### 6.3 Examples

- `Admin` -> full management permissions
- `Manager` -> limited operational permissions
- `User` -> standard self-service actions

#### 6.4 Authorization Resolution Strategy

At request time:

1. Access token identifies the user and session
2. Authorization data is resolved
   - from Redis cache first
   - from PostgreSQL on cache miss
3. Route guard compares required permissions/roles with effective permissions
4. Request is allowed or denied

If the user is authenticated but lacks permission, return **`403 Forbidden`**.

---

### 7. Token and Session Invalidation Rules

The system will revoke sessions or invalidate caches in the following cases:

- user logs out
- admin forces logout
- password changes
- password reset completes
- refresh token reuse is detected
- account is disabled
- role/permission changes require immediate effect
- suspicious security activity is detected

**Revocation behavior**
- Mark session(s) revoked in PostgreSQL
- Remove or update Redis session entries
- Add temporary revocation markers where necessary
- Emit security events for audit and further handling

---

### 8. High-Level Flows

#### 8.1 Sign Up Flow

1. Client sends registration data
2. Auth module validates payload and uniqueness constraints
3. Password is hashed using bcrypt
4. User record is created in PostgreSQL
5. Default role(s) are assigned
6. Internal event `auth.user_registered` is emitted
7. BullMQ may enqueue welcome email / email verification / audit jobs
8. Optionally, create a session immediately and issue tokens

---

#### 8.2 Sign In Flow

1. Client submits identifier and password
2. Auth module loads user from PostgreSQL
3. bcrypt verifies the password
4. If valid:
   - create a new session in PostgreSQL
   - generate refresh token
   - hash refresh token and store hash
   - cache session metadata in Redis
   - resolve user roles/permissions
   - issue access token
   - issue refresh token
5. Emit `auth.user_signed_in`
6. Return tokens to the client

---

#### 8.3 Access Token Usage Flow

1. Client calls protected endpoint with JWT access token
2. API validates JWT
3. Identity is extracted from token
4. Authorization guard loads effective roles/permissions
   - prefer Redis
   - fallback to PostgreSQL
5. RBAC rules are evaluated
6. Request proceeds or is denied

---

#### 8.4 Refresh Token Rotation Flow

1. Client sends refresh token to refresh endpoint
2. Server hashes incoming token
3. Server looks up matching active session/token record
4. If token is valid:
   - invalidate old refresh token
   - generate new refresh token
   - hash and store the new refresh token
   - update PostgreSQL session atomically
   - update Redis cache
   - issue new access token
   - issue new refresh token
5. If an old/rotated token is presented again:
   - detect token reuse
   - mark session or token family as compromised
   - revoke all linked active sessions if policy requires
   - remove Redis state
   - emit `auth.refresh_token_reuse_detected`
   - force user to sign in again

---

#### 8.5 Logout Flow

1. Client calls logout endpoint
2. Current session is identified
3. Session is marked revoked in PostgreSQL
4. Related Redis keys are deleted or marked revoked
5. Refresh token becomes unusable
6. If "logout all devices" is requested, revoke all sessions for the user

---

#### 8.6 Role/Permission Change Flow

1. Admin or system updates role assignments or permissions
2. PostgreSQL authorization tables are updated
3. Redis authorization cache is invalidated
4. Event such as `auth.user_role_updated` is emitted
5. Depending on policy:
   - changes take full effect on next request if authz cache is live and checked centrally
   - or effect is enforced on next refresh
   - or all sessions are revoked immediately for strict security

---

### 9. Event-Driven Behavior

The auth module will emit internal events such as:

- `auth.user_registered`
- `auth.user_signed_in`
- `auth.user_signed_out`
- `auth.password_changed`
- `auth.password_reset_requested`
- `auth.password_reset_completed`
- `auth.user_role_updated`
- `auth.user_permission_updated`
- `auth.session_revoked`
- `auth.refresh_token_reuse_detected`

These events may be consumed by other modules for:

- audit logging
- notifications
- anomaly detection
- user security alerts
- analytics
- search/index sync
- cleanup jobs

**BullMQ** will be used for background processing of non-blocking tasks such as:
- welcome email
- email verification email
- password reset email
- audit/event persistence
- suspicious activity notifications

---

### 10. Security Rules

The implementation must follow these rules:

- Access tokens must be short-lived
- Refresh tokens must be rotated on every successful use
- Refresh tokens must be stored hashed, never plaintext
- Passwords must be hashed with bcrypt
- Sensitive endpoints may additionally verify session state
- Redis must only be used for cache and ephemeral security state
- PostgreSQL remains the source of truth
- Role and permission changes must invalidate authorization cache
- Password changes must revoke existing sessions
- Authentication endpoints must be rate-limited
- Security-sensitive activities must be auditable

---

### 11. Recommended Failure Responses

- Invalid or expired access token -> `401 Unauthorized`
- Invalid refresh token -> `401 Unauthorized`
- Reused refresh token -> `401 Unauthorized` and revoke token family/session
- Authenticated but insufficient permissions -> `403 Forbidden`
- Too many login/refresh attempts -> `429 Too Many Requests`

---

### 12. Complete High-Level Flow Diagram

#### 12.1 End-to-End Authentication, Authorization, and RBAC Flow

```mermaid
flowchart TD
    A["Client App"] --> B["API Gateway / Auth API"]
    B --> C{"Request Type"}

    %% =========================
    %% Sign Up
    %% =========================
    C -->|Sign Up| SU1["Validate Input"]
    SU1 --> SU2{"Valid Payload?"}
    SU2 -->|No| SU_ERR1["Return 400 Validation Error"]
    SU2 -->|Yes| SU3["Check Email/Phone Uniqueness in PostgreSQL"]
    SU3 --> SU4{"Already Exists?"}
    SU4 -->|Yes| SU_ERR2["Return 409 Conflict"]
    SU4 -->|No| SU5["Hash Password with bcrypt"]
    SU5 --> SU6["Create User in PostgreSQL"]
    SU6 --> SU7["Assign Default Role(s)"]
    SU7 --> SU8["Emit auth.user_registered"]
    SU8 --> SU9["Queue Welcome / Verification Jobs via BullMQ"]
    SU7 --> SU10{"Auto Login After Sign Up?"}
    SU10 -->|No| SU11["Return 201 Created"]
    SU10 -->|Yes| SU12["Create Session"]
    SU12 --> SU13["Generate Refresh Token"]
    SU13 --> SU14["Hash Refresh Token"]
    SU14 --> SU15["Store Session in PostgreSQL"]
    SU15 --> SU16["Cache Session in Redis"]
    SU16 --> SU17["Resolve Roles / Permissions"]
    SU17 --> SU18["Issue JWT Access Token + Refresh Token"]
    SU18 --> SU19["Return Tokens to Client"]

    %% =========================
    %% Sign In
    %% =========================
    C -->|Sign In| SI1["Rate Limit Check in Redis"]
    SI1 --> SI2{"Allowed?"}
    SI2 -->|No| SI_ERR1["Return 429 Too Many Requests"]
    SI2 -->|Yes| SI3["Load User from PostgreSQL"]
    SI3 --> SI4{"User Found?"}
    SI4 -->|No| SI_ERR2["Return 401 Invalid Credentials"]
    SI4 -->|Yes| SI5{"Account Active?"}
    SI5 -->|No| SI_ERR3["Return 403 Account Disabled / Unverified"]
    SI5 -->|Yes| SI6["Verify Password with bcrypt"]
    SI6 -->|Invalid| SI7["Increment Failed Login Counter in Redis"]
    SI7 --> SI_ERR4["Return 401 Invalid Credentials"]
    SI6 -->|Valid| SI8["Reset Failed Login Counter in Redis"]
    SI8 --> SI9["Create Session"]
    SI9 --> SI10["Generate Refresh Token"]
    SI10 --> SI11["Hash Refresh Token"]
    SI11 --> SI12["Store Session in PostgreSQL"]
    SI12 --> SI13["Cache Session in Redis"]
    SI13 --> SI14["Load Roles / Permissions from Redis or PostgreSQL"]
    SI14 --> SI15["Issue JWT Access Token + Refresh Token"]
    SI15 --> SI16["Emit auth.user_signed_in"]
    SI16 --> SI17["Return Tokens to Client"]

    %% =========================
    %% Protected Request
    %% =========================
    C -->|Protected API Request| PR1["Extract Access Token from Authorization Header"]
    PR1 --> PR2["Validate JWT Signature and Standard Claims"]
    PR2 --> PR3{"Token Valid?"}
    PR3 -->|No| PR_ERR1["Return 401 Unauthorized"]
    PR3 -->|Yes| PR4["Extract userId / sessionId / jti / authz_version"]
    PR4 --> PR5{"Sensitive Endpoint?"}
    PR5 -->|Yes| PR6["Check Session / Revocation Status in Redis"]
    PR6 --> PR7{"Session Revoked / Blocked?"}
    PR7 -->|Yes| PR_ERR2["Return 401 Session Invalid"]
    PR7 -->|No| PR8["Load Roles / Permissions from Redis"]
    PR5 -->|No| PR8
    PR8 --> PR9{"AuthZ Cache Hit?"}
    PR9 -->|No| PR10["Load Roles / Permissions from PostgreSQL"]
    PR10 --> PR11["Update Redis AuthZ Cache"]
    PR9 -->|Yes| PR12["Use Cached Roles / Permissions"]
    PR11 --> PR13["Apply RBAC Guard / Permission Check"]
    PR12 --> PR13
    PR13 --> PR14{"Authorized?"}
    PR14 -->|No| PR_ERR3["Return 403 Forbidden"]
    PR14 -->|Yes| PR15["Execute Business Logic"]
    PR15 --> PR16["Return 2xx Response"]

    %% =========================
    %% Refresh Token Rotation
    %% =========================
    C -->|Refresh Token Request| RF1["Rate Limit Refresh Endpoint in Redis"]
    RF1 --> RF2{"Allowed?"}
    RF2 -->|No| RF_ERR1["Return 429 Too Many Requests"]
    RF2 -->|Yes| RF3["Read Refresh Token from Secure Cookie / Request"]
    RF3 --> RF4["Hash Presented Refresh Token"]
    RF4 --> RF5["Lookup Session in Redis"]
    RF5 --> RF6{"Cache Hit?"}
    RF6 -->|No| RF7["Load Session from PostgreSQL"]
    RF6 -->|Yes| RF8["Use Cached Session State"]
    RF7 --> RF9{"Session Found?"}
    RF9 -->|No| RF_ERR2["Return 401 Invalid Refresh Token"]
    RF8 --> RF10["Validate Session Status / Expiry / Token Match"]
    RF7 --> RF10
    RF10 --> RF11{"Valid and Current?"}
    RF11 -->|No - Expired or Revoked| RF_ERR3["Return 401 Re-Authentication Required"]
    RF11 -->|No - Old / Rotated Token| RF12["Detect Refresh Token Reuse / Replay"]
    RF12 --> RF13["Mark Session or Token Family as Compromised in PostgreSQL"]
    RF13 --> RF14["Delete / Mark Redis Session State"]
    RF14 --> RF15["Emit auth.refresh_token_reuse_detected"]
    RF15 --> RF16["Optionally Notify User / Queue Security Alert"]
    RF16 --> RF_ERR4["Return 401 Force Re-Authentication"]

    RF11 -->|Yes| RF17["Begin DB Transaction"]
    RF17 --> RF18["Invalidate Old Refresh Token / Mark Rotated"]
    RF18 --> RF19["Generate New Refresh Token"]
    RF19 --> RF20["Hash New Refresh Token"]
    RF20 --> RF21["Atomically Update Session in PostgreSQL"]
    RF21 --> RF22["Update Redis Session Cache"]
    RF22 --> RF23["Resolve Roles / Permissions"]
    RF23 --> RF24["Issue New JWT Access Token + New Refresh Token"]
    RF24 --> RF25["Return New Tokens"]

    %% =========================
    %% Logout
    %% =========================
    C -->|Logout| LO1["Identify Current Session"]
    LO1 --> LO2{"Logout All Devices?"}
    LO2 -->|No| LO3["Mark Current Session Revoked in PostgreSQL"]
    LO2 -->|Yes| LO4["Mark All User Sessions Revoked in PostgreSQL"]
    LO3 --> LO5["Delete / Mark Redis Session State"]
    LO4 --> LO6["Delete / Mark All User Session Keys in Redis"]
    LO5 --> LO7["Emit auth.session_revoked"]
    LO6 --> LO7
    LO7 --> LO8["Return Success"]

    %% =========================
    %% Password Change / Reset
    %% =========================
    C -->|Password Change / Reset| PW1["Validate Password Reset Token or Current Password"]
    PW1 --> PW2{"Valid?"}
    PW2 -->|No| PW_ERR1["Return 400 / 401"]
    PW2 -->|Yes| PW3["Hash New Password with bcrypt"]
    PW3 --> PW4["Update Password in PostgreSQL"]
    PW4 --> PW5["Revoke All Active Sessions for User"]
    PW5 --> PW6["Delete User Session Keys from Redis"]
    PW6 --> PW7["Invalidate User AuthZ Cache in Redis"]
    PW7 --> PW8["Emit auth.password_changed or auth.password_reset_completed"]
    PW8 --> PW9["Queue Security Notification via BullMQ"]
    PW9 --> PW10["Return Success - Re-Authentication Required"]

    %% =========================
    %% RBAC Changes
    %% =========================
    ADM["Admin / System"] --> RB1["Update User Roles / Permissions"]
    RB1 --> RB2["Persist Changes in PostgreSQL"]
    RB2 --> RB3["Invalidate Redis AuthZ Cache"]
    RB3 --> RB4["Increment authz_version / permission version"]
    RB4 --> RB5["Emit auth.user_role_updated / auth.permission_updated"]
    RB5 --> RB6{"Immediate Enforcement Policy?"}
    RB6 -->|No| RB7["Apply Updated RBAC on Next Request / Refresh"]
    RB6 -->|Yes| RB8["Revoke Active Sessions or Force Token Refresh"]
    RB8 --> RB9["Delete Related Session Keys in Redis"]

    %% =========================
    %% Optional Email Verification
    %% =========================
    SU9 --> EV1["User Clicks Verification Link"]
    EV1 --> EV2["Validate Verification Token"]
    EV2 --> EV3{"Token Valid?"}
    EV3 -->|No| EV_ERR1["Return Invalid / Expired Link"]
    EV3 -->|Yes| EV4["Mark User as Verified in PostgreSQL"]
    EV4 --> EV5["Emit auth.user_verified"]
    EV5 --> EV6["Return Verification Success"]
    ```