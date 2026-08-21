# Expense Claims — Design

Employees submit expense claims with a receipt through a single web
application; managers review and approve or reject them from a queue; and
finance reviews approved claims and generates a payroll export file. A
Ballerina service (`expense-api`) owns the full claim lifecycle and sends
email notifications on status changes; a React SPA (`expense-webapp`)
provides the three role-scoped experiences. Both sit behind the org gateway
and sign users in through Thunder.

## Context (C1)

```mermaid
graph TD
  Employee((Employee))
  Manager((Manager))
  Finance((Finance))
  System[Expense Claims System]
  Thunder[[Thunder IDP]]
  Email[[Email Provider]]

  Employee --> System
  Manager --> System
  Finance --> System
  System --> Thunder
  System --> Email
```

## Domain model (ER)

```mermaid
erDiagram
  USER {
    string id PK
    string name
    string email
    string role "employee|manager|finance"
    string managerId FK "for employees"
  }
  EXPENSE_CLAIM {
    string id PK
    string employeeId FK
    decimal amount
    string category
    date expenseDate
    string description
    string receiptUrl
    string status "draft|submitted|approved|rejected"
    boolean exported
    datetime createdAt
    datetime updatedAt
  }
  APPROVAL_DECISION {
    string id PK
    string claimId FK
    string managerId FK
    string decision "approved|rejected"
    string comment
    datetime decidedAt
  }
  PAYROLL_EXPORT {
    string id PK
    string generatedBy FK
    string fileUrl
    datetime generatedAt
  }

  USER ||--o{ EXPENSE_CLAIM : submits
  USER ||--o{ EXPENSE_CLAIM : manages
  EXPENSE_CLAIM ||--o{ APPROVAL_DECISION : "decided by"
  USER ||--o{ APPROVAL_DECISION : decides
  PAYROLL_EXPORT ||--o{ EXPENSE_CLAIM : includes
```

## Key flows

### Employee submits a claim

```mermaid
sequenceDiagram
  actor Employee
  participant Webapp as expense-webapp
  participant API as expense-api
  participant Email as Email Provider

  Employee->>Webapp: Fill claim form + attach receipt
  Webapp->>API: POST /expense-claims
  API->>API: Store claim (status=submitted)
  API->>Email: Notify manager of new claim
  API-->>Webapp: 201 Created
  Webapp-->>Employee: Claim shown as Submitted
```

### Manager approves or rejects a claim

```mermaid
sequenceDiagram
  actor Manager
  participant Webapp as expense-webapp
  participant API as expense-api
  participant Email as Email Provider

  Manager->>Webapp: Open pending queue
  Webapp->>API: GET /expense-claims?status=submitted
  API-->>Webapp: List of pending claims
  Manager->>Webapp: Approve or reject a claim
  Webapp->>API: POST /expense-claims/{id}/approve or /reject
  API->>API: Update claim status
  API->>Email: Notify employee of decision
  API-->>Webapp: 200 OK
```

### Employee resubmits a rejected claim

```mermaid
sequenceDiagram
  actor Employee
  participant Webapp as expense-webapp
  participant API as expense-api

  Employee->>Webapp: Open rejected claim, edit fields
  Webapp->>API: PUT /expense-claims/{id}
  Webapp->>API: POST /expense-claims/{id}/resubmit
  API->>API: Set status=submitted, clear prior decision
  API-->>Webapp: 200 OK
```

### Finance exports approved claims to payroll

```mermaid
sequenceDiagram
  actor Finance
  participant Webapp as expense-webapp
  participant API as expense-api

  Finance->>Webapp: Open approved claims, click Export
  Webapp->>API: POST /payroll-exports
  API->>API: Gather unexported approved claims into a file
  API->>API: Mark included claims as exported
  API-->>Webapp: Export batch + download link
  Finance->>Webapp: Download CSV
  Webapp->>API: GET /payroll-exports/{id}/download
```