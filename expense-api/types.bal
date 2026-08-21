// Domain records. Kept as closed records per the Ballerina code rules — every
// shape this service owns is fully specified, never `map<json>`/`json`.

public type AppUser record {|
    string id;
    string name;
    string email;
    string role;
    string? managerId;
|};

public type ExpenseClaimInput record {|
    decimal amount;
    string category;
    string expenseDate;
    string description;
|};

public type ExpenseClaim record {|
    string id;
    string employeeId;
    decimal amount;
    string category;
    string expenseDate;
    string description;
    string? receiptUrl;
    string status;
    string? rejectionReason;
    boolean exported;
    string createdAt;
    string updatedAt;
|};

public type RejectRequest record {|
    string reason;
|};

public type PayrollExport record {|
    string id;
    string generatedBy;
    string fileUrl;
    string generatedAt;
    int claimCount;
|};

public type ClaimListResponse record {|
    int count;
    string? next;
    string? previous;
    ExpenseClaim[] data;
|};

public type ExportListResponse record {|
    int count;
    string? next;
    string? previous;
    PayrollExport[] data;
|};

public type ApiError record {|
    int code;
    string message;
    string description?;
|};

// Internal row shapes used only for SQL binding — never exposed on the wire.

type ExpenseClaimRow record {|
    string id;
    string employeeId;
    decimal amount;
    string category;
    string expenseDate;
    string description;
    string? receiptUrl;
    string status;
    string? rejectionReason;
    boolean exported;
    string createdAt;
    string updatedAt;
|};

type PayrollExportRow record {|
    string id;
    string generatedBy;
    string fileUrl;
    string generatedAt;
    int claimCount;
|};
