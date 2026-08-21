// Expense Claims — three roles, seven screens

screen MyClaims "Employee views all their submitted claims and status"
  navbar "ExpenseClaims"
  sidebar "My Claims -> MyClaims | Settings"
  row
    heading "My Claims"
    right
    button "New claim" primary -> NewClaim
  row
    card "Pending | 2 | awaiting manager review"
    card "Approved | 5 | ready for payroll"
    card "Rejected | 1 | needs your edits"
  tabs "All | Pending | Approved | Rejected"
  table "Expense | Category | Amount | Status | Updated" -> ClaimDetail
    row "Client dinner | Meals | $84.20 | Submitted | 2h ago"
    row "Flight to Denver | Travel | $412.00 | Approved | 1d ago"
    row "Taxi receipts | Travel | $38.50 | Rejected | 3d ago"

screen NewClaim "Employee submits a new expense claim with a receipt"
  navbar "ExpenseClaims"
  sidebar "My Claims -> MyClaims | Settings"
  breadcrumb "My Claims / New claim"
  heading "New Expense Claim"
  row
    input "Amount — e.g. 84.20"
    select "Category: Meals"
  input "Date of expense"
  textarea "What was this expense for?"
  button "Attach receipt"
  row
    right
    button "Cancel"
    button "Submit claim" primary -> MyClaims

screen ClaimDetail "Employee tracks one claim and edits it if rejected"
  navbar "ExpenseClaims"
  sidebar "My Claims -> MyClaims | Settings"
  breadcrumb "My Claims / Taxi receipts"
  row
    heading "Taxi receipts"
    badge "Rejected" danger
  text "Manager: J. Alvarez — Updated 3d ago"
  split 60/40
    left
      text "Amount: $38.50 — Category: Travel"
      text "Date: 12 Aug 2026"
      text "Description: Airport taxi for client visit"
      image "receipt.jpg"
      row
        right
        button "Edit and resubmit" primary -> NewClaim
    right
      heading "Review notes"
      text "J. Alvarez · 3d: missing itemized receipt, please reattach."

screen ReviewQueue "Manager reviews pending claims from their team"
  navbar "ExpenseClaims"
  sidebar "Review Queue -> ReviewQueue | Settings"
  row
    heading "Review Queue"
    right
    select "Employee: All"
  row
    card "Pending review | 6 | across your team"
    card "Approved this week | 14 |  total $3,240"
  table "Employee | Expense | Category | Amount | Submitted" -> ClaimReview
    row "A. Chen | Client dinner | Meals | $84.20 | 2h ago"
    row "M. Diaz | Flight to Denver | Travel | $412.00 | 1d ago"
    row "K. Smith | Hotel stay | Travel | $210.00 | 2d ago"

screen ClaimReview "Manager approves or rejects a single claim"
  navbar "ExpenseClaims"
  sidebar "Review Queue -> ReviewQueue | Settings"
  breadcrumb "Review Queue / Client dinner"
  row
    heading "Client dinner"
    badge "Submitted" info
  text "Employee: A. Chen — Submitted 2h ago"
  split 60/40
    left
      text "Amount: $84.20 — Category: Meals"
      text "Date: 19 Aug 2026"
      text "Description: Dinner with prospective client"
      image "receipt.jpg"
      row
        right
        button "Reject"
        button "Approve" primary -> ReviewQueue
    right
      textarea "Add a note if rejecting…"

screen ApprovedClaims "Finance reviews approved claims ready for payroll"
  navbar "ExpenseClaims"
  sidebar "Approved Claims -> ApprovedClaims | Export History -> ExportHistory | Settings"
  row
    heading "Approved Claims"
    right
    button "Export to payroll" primary -> ExportHistory
  row
    card "Ready to export | 14 | total $3,240.00"
    card "Already exported | 52 | across 3 batches"
  table "Employee | Expense | Category | Amount | Approved"
    row "A. Chen | Client dinner | Meals | $84.20 | 2h ago"
    row "M. Diaz | Flight to Denver | Travel | $412.00 | 1d ago"
    row "K. Smith | Hotel stay | Travel | $210.00 | 3d ago"

screen ExportHistory "Finance downloads generated payroll export files"
  navbar "ExpenseClaims"
  sidebar "Approved Claims -> ApprovedClaims | Export History -> ExportHistory | Settings"
  heading "Export History"
  table "Export date | Claims | Total | " 
    row "20 Aug 2026 | 14 | $3,240.00 | Download"
    row "13 Aug 2026 | 18 | $4,105.50 | Download"
    row "6 Aug 2026 | 20 | $3,890.00 | Download"

flow "Submit and track a claim"
  role "Employee"
  description "An employee submits a claim, tracks its status, and fixes a rejected one"
  MyClaims
  NewClaim
  ClaimDetail

flow "Review and decide"
  role "Manager"
  description "A manager reviews their team's pending claims and approves or rejects each"
  ReviewQueue
  ClaimReview

flow "Export to payroll"
  role "Finance"
  description "Finance reviews approved claims and generates a payroll export file"
  ApprovedClaims
  ExportHistory
