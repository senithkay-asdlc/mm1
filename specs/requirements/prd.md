# Expense Claims — PRD

## Problem Statement

Employees pay for business expenses out of pocket and today rely on ad-hoc
processes — email threads, spreadsheets, or paper forms — to get reimbursed.
Managers lack a consistent way to review and approve these costs, and finance
has to manually reconcile scattered approvals before feeding reimbursements
into payroll. The result is slow reimbursement, weak audit trails, and manual
rework for finance every pay cycle.

## Solution

A web application where employees submit expense claims with receipts,
managers review and approve or reject those claims, and finance exports the
approved claims as a file ready to feed into payroll — replacing the ad-hoc,
manual process with a single tracked workflow from submission to payout.

## Actors

- **Employee** — submits expense claims with amount, category, date,
description, and a receipt attachment; tracks claim status; edits and
resubmits rejected claims.
- **Manager** — reviews claims submitted by their employees and approves or
rejects each one.
- **Finance** — views approved claims and exports them as a file for payroll
processing.

## User Stories

1. As an Employee, I want to submit an expense claim with amount, category,
date, description, and a receipt attachment, so that I can request
reimbursement for a business expense.
2. As an Employee, I want to see the status of my submitted claims (pending,
approved, rejected), so that I know where each claim stands.
3. As an Employee, I want to edit and resubmit a rejected claim, so that I can
correct it without starting over.
4. As an Employee, I want to receive an email when my claim is approved or
rejected, so that I know the outcome without checking the app.
5. As a Manager, I want to see a queue of pending claims from my employees, so
that I can review them.
6. As a Manager, I want to approve or reject a claim, so that valid expenses
move toward reimbursement and invalid ones are sent back.
7. As a Manager, I want to receive an email when a new claim needs my review,
so that approvals aren't delayed by having to check the app.
8. As Finance, I want to see all approved claims, so that I know what is ready
for payroll processing.
9. As Finance, I want to export approved claims as a file (e.g. CSV), so that
I can upload them into our payroll system.
10. As Finance, I want exported claims to be marked as exported, so that the
same claim is never paid out twice.

## Product Decisions

- Sign-in is via SSO through Thunder, the platform IDP (org default).
- The web app is built as a TypeScript + React single-page app; the backing
services are Ballerina (org default).
- Approval is single-level: every claim goes to the employee's manager only;
there is no amount-based escalation to a second approver.
- Each claim carries exactly one receipt attachment (not multiple line
items per claim).
- Finance's payroll handoff is a file export (e.g. CSV) that finance
downloads and feeds into payroll manually — there is no direct API
integration with a specific payroll system.
- Rejected claims are not final: the employee can edit and resubmit them.
- The system sends email notifications on claim submission, approval, and
rejection, in addition to in-app status visibility.

## Out of Scope

- Direct API integration with a named payroll system.
- Multi-level or amount-based approval escalation.
- Multiple line items per claim (a claim is a single expense with one
receipt).
- Currency conversion / multi-currency claims.
- Mobile native apps (web only).

## Open Questions

None at this time.

## Further Notes

None.