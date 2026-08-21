import ballerina/log;
import ballerina/sql;
import ballerina/time;
import ballerina/uuid;
import ballerinax/postgresql;
import ballerinax/postgresql.driver as _;

// Module-level client, established lazily so the service still boots when
// expense-db credentials are not yet configured in this environment (the
// component "starts with no required environment variables").
postgresql:Client? dbClient = ();

function init() {
    postgresql:Client|error result = connectDb();
    if result is postgresql:Client {
        dbClient = result;
        error? schemaResult = initSchema(result);
        if schemaResult is error {
            log:printError("failed to initialize expense-db schema", 'error = schemaResult);
        }
        error? seedResult = seedUsersIfEmpty(result);
        if seedResult is error {
            log:printError("failed to seed demo users", 'error = seedResult);
        }
    } else {
        log:printWarn("expense-db not reachable at startup; will retry lazily on first request", 'error = result);
    }
}

function connectDb() returns postgresql:Client|error {
    return new (host = dbHost, port = dbPort, database = dbName, username = dbUser, password = dbPassword);
}

// Returns the live client, attempting one lazy reconnect if startup failed.
function getDb() returns postgresql:Client|error {
    postgresql:Client? existing = dbClient;
    if existing is postgresql:Client {
        return existing;
    }
    postgresql:Client|error result = connectDb();
    if result is postgresql:Client {
        dbClient = result;
        check initSchema(result);
        check seedUsersIfEmpty(result);
        return result;
    }
    return result;
}

function initSchema(postgresql:Client db) returns error? {
    _ = check db->execute(`
        CREATE TABLE IF NOT EXISTS app_user (
            id TEXT PRIMARY KEY,
            name TEXT NOT NULL,
            email TEXT NOT NULL,
            role TEXT NOT NULL,
            manager_id TEXT NULL
        )`);
    _ = check db->execute(`
        CREATE TABLE IF NOT EXISTS expense_claim (
            id TEXT PRIMARY KEY,
            employee_id TEXT NOT NULL,
            amount NUMERIC(12,2) NOT NULL,
            category TEXT NOT NULL,
            expense_date TEXT NOT NULL,
            description TEXT NOT NULL,
            receipt_url TEXT NULL,
            receipt_blob BYTEA NULL,
            receipt_filename TEXT NULL,
            receipt_content_type TEXT NULL,
            status TEXT NOT NULL,
            rejection_reason TEXT NULL,
            exported BOOLEAN NOT NULL DEFAULT false,
            export_id TEXT NULL,
            created_at TEXT NOT NULL,
            updated_at TEXT NOT NULL
        )`);
    _ = check db->execute(`
        CREATE TABLE IF NOT EXISTS approval_decision (
            id TEXT PRIMARY KEY,
            claim_id TEXT NOT NULL,
            manager_id TEXT NOT NULL,
            decision TEXT NOT NULL,
            comment TEXT NULL,
            decided_at TEXT NOT NULL
        )`);
    _ = check db->execute(`
        CREATE TABLE IF NOT EXISTS payroll_export (
            id TEXT PRIMARY KEY,
            generated_by TEXT NOT NULL,
            file_url TEXT NOT NULL,
            generated_at TEXT NOT NULL,
            claim_count INT NOT NULL,
            csv_content TEXT NOT NULL
        )`);
}

// Seeds a minimal, plausible demo roster (one finance user, one manager, two
// of their direct reports) so X-User-Id lookups resolve end-to-end. There is
// no registration endpoint anywhere in this system by design.
function seedUsersIfEmpty(postgresql:Client db) returns error? {
    int|error countResult = db->queryRow(`SELECT COUNT(*)::int FROM app_user`);
    int existing = countResult is int ? countResult : 0;
    if existing > 0 {
        return;
    }
    AppUser[] demoUsers = [
        {id: "user-mgr-1", name: "Morgan Lee", email: "morgan.lee@example.com", role: "manager", managerId: ()},
        {id: "user-emp-1", name: "Alex Chen", email: "alex.chen@example.com", role: "employee", managerId: "user-mgr-1"},
        {id: "user-emp-2", name: "Jordan Patel", email: "jordan.patel@example.com", role: "employee", managerId: "user-mgr-1"},
        {id: "user-fin-1", name: "Riley Kim", email: "riley.kim@example.com", role: "finance", managerId: ()}
    ];
    foreach AppUser demoUser in demoUsers {
        _ = check db->execute(`
            INSERT INTO app_user (id, name, email, role, manager_id)
            VALUES (${demoUser.id}, ${demoUser.name}, ${demoUser.email}, ${demoUser.role}, ${demoUser.managerId})`);
    }
    log:printInfo("seeded demo users into expense-db", userCount = demoUsers.length());
}

function nowString() returns string {
    return time:utcToString(time:utcNow());
}

function newId(string prefix) returns string {
    return prefix + "-" + uuid:createType4AsString();
}

// ---- users ----

function findUserById(string id) returns AppUser?|error {
    postgresql:Client db = check getDb();
    AppUser|sql:Error result = db->queryRow(`SELECT id, name, email, role, manager_id as "managerId" FROM app_user WHERE id = ${id}`);
    if result is sql:NoRowsError {
        return ();
    }
    if result is sql:Error {
        return result;
    }
    return result;
}

function listDirectReportIds(string managerId) returns string[]|error {
    postgresql:Client db = check getDb();
    stream<record {| string id; |}, sql:Error?> rows = db->query(`SELECT id FROM app_user WHERE manager_id = ${managerId}`);
    string[] ids = [];
    check from record {| string id; |} row in rows
        do {
            ids.push(row.id);
        };
    check rows.close();
    return ids;
}

// ---- expense claims ----

function claimRowToClaim(ExpenseClaimRow row) returns ExpenseClaim => {
    id: row.id,
    employeeId: row.employeeId,
    amount: row.amount,
    category: row.category,
    expenseDate: row.expenseDate,
    description: row.description,
    receiptUrl: row.receiptUrl,
    status: row.status,
    rejectionReason: row.rejectionReason,
    exported: row.exported,
    createdAt: row.createdAt,
    updatedAt: row.updatedAt
};

function insertClaim(string employeeId, ExpenseClaimInput input) returns ExpenseClaim|error {
    postgresql:Client db = check getDb();
    string id = newId("claim");
    string timestamp = nowString();
    _ = check db->execute(`
        INSERT INTO expense_claim
            (id, employee_id, amount, category, expense_date, description, status, exported, created_at, updated_at)
        VALUES
            (${id}, ${employeeId}, ${input.amount}, ${input.category}, ${input.expenseDate}, ${input.description}, 'submitted', false, ${timestamp}, ${timestamp})`);
    return {
        id,
        employeeId,
        amount: input.amount,
        category: input.category,
        expenseDate: input.expenseDate,
        description: input.description,
        receiptUrl: (),
        status: "submitted",
        rejectionReason: (),
        exported: false,
        createdAt: timestamp,
        updatedAt: timestamp
    };
}

function getClaimById(string claimId) returns ExpenseClaim?|error {
    postgresql:Client db = check getDb();
    ExpenseClaimRow|sql:Error result = db->queryRow(`
        SELECT id, employee_id as "employeeId", amount, category, expense_date as "expenseDate",
               description, receipt_url as "receiptUrl", status, rejection_reason as "rejectionReason",
               exported, created_at as "createdAt", updated_at as "updatedAt"
        FROM expense_claim WHERE id = ${claimId}`);
    if result is sql:NoRowsError {
        return ();
    }
    if result is sql:Error {
        return result;
    }
    return claimRowToClaim(result);
}

function listClaims(string? status, string? employeeId, string[]? employeeIdIn, int 'limit, int offset)
        returns [ExpenseClaim[], int]|error {
    postgresql:Client db = check getDb();
    sql:ParameterizedQuery countQuery = `SELECT COUNT(*)::int FROM expense_claim WHERE 1 = 1`;
    sql:ParameterizedQuery selectQuery = `
        SELECT id, employee_id as "employeeId", amount, category, expense_date as "expenseDate",
               description, receipt_url as "receiptUrl", status, rejection_reason as "rejectionReason",
               exported, created_at as "createdAt", updated_at as "updatedAt"
        FROM expense_claim WHERE 1 = 1`;

    if status is string {
        countQuery = sql:queryConcat(countQuery, ` AND status = ${status}`);
        selectQuery = sql:queryConcat(selectQuery, ` AND status = ${status}`);
    }
    if employeeId is string {
        countQuery = sql:queryConcat(countQuery, ` AND employee_id = ${employeeId}`);
        selectQuery = sql:queryConcat(selectQuery, ` AND employee_id = ${employeeId}`);
    }
    if employeeIdIn is string[] {
        countQuery = sql:queryConcat(countQuery, ` AND employee_id = ANY(${employeeIdIn})`);
        selectQuery = sql:queryConcat(selectQuery, ` AND employee_id = ANY(${employeeIdIn})`);
    }
    selectQuery = sql:queryConcat(selectQuery, ` ORDER BY created_at DESC LIMIT ${'limit} OFFSET ${offset}`);

    int total = check db->queryRow(countQuery);
    stream<ExpenseClaimRow, sql:Error?> rows = db->query(selectQuery);
    ExpenseClaim[] claims = [];
    check from ExpenseClaimRow row in rows
        do {
            claims.push(claimRowToClaim(row));
        };
    check rows.close();
    return [claims, total];
}

function updateClaimContent(string claimId, ExpenseClaimInput input) returns ExpenseClaim?|error {
    postgresql:Client db = check getDb();
    string timestamp = nowString();
    sql:ExecutionResult result = check db->execute(`
        UPDATE expense_claim
        SET amount = ${input.amount}, category = ${input.category}, expense_date = ${input.expenseDate},
            description = ${input.description}, updated_at = ${timestamp}
        WHERE id = ${claimId}`);
    int? affected = result.affectedRowCount;
    if affected is int && affected == 0 {
        return ();
    }
    return getClaimById(claimId);
}

function setClaimReceipt(string claimId, byte[] content, string fileName, string contentType) returns ExpenseClaim?|error {
    postgresql:Client db = check getDb();
    string receiptUrl = "/expense-claims/" + claimId + "/receipt";
    string timestamp = nowString();
    sql:ExecutionResult result = check db->execute(`
        UPDATE expense_claim
        SET receipt_url = ${receiptUrl}, receipt_blob = ${content}, receipt_filename = ${fileName},
            receipt_content_type = ${contentType}, updated_at = ${timestamp}
        WHERE id = ${claimId}`);
    int? affected = result.affectedRowCount;
    if affected is int && affected == 0 {
        return ();
    }
    return getClaimById(claimId);
}

function resubmitClaimRow(string claimId) returns ExpenseClaim?|error {
    postgresql:Client db = check getDb();
    string timestamp = nowString();
    sql:ExecutionResult result = check db->execute(`
        UPDATE expense_claim
        SET status = 'submitted', rejection_reason = NULL, updated_at = ${timestamp}
        WHERE id = ${claimId}`);
    int? affected = result.affectedRowCount;
    if affected is int && affected == 0 {
        return ();
    }
    return getClaimById(claimId);
}

function decideClaim(string claimId, string managerId, string decision, string? comment) returns ExpenseClaim?|error {
    postgresql:Client db = check getDb();
    string timestamp = nowString();
    string newStatus = decision == "approved" ? "approved" : "rejected";
    sql:ExecutionResult result = check db->execute(`
        UPDATE expense_claim
        SET status = ${newStatus}, rejection_reason = ${comment}, updated_at = ${timestamp}
        WHERE id = ${claimId}`);
    int? affected = result.affectedRowCount;
    if affected is int && affected == 0 {
        return ();
    }
    string decisionId = newId("decision");
    _ = check db->execute(`
        INSERT INTO approval_decision (id, claim_id, manager_id, decision, comment, decided_at)
        VALUES (${decisionId}, ${claimId}, ${managerId}, ${decision}, ${comment}, ${timestamp})`);
    return getClaimById(claimId);
}

// ---- payroll exports ----

function listUnexportedApprovedClaims() returns ExpenseClaim[]|error {
    postgresql:Client db = check getDb();
    stream<ExpenseClaimRow, sql:Error?> rows = db->query(`
        SELECT id, employee_id as "employeeId", amount, category, expense_date as "expenseDate",
               description, receipt_url as "receiptUrl", status, rejection_reason as "rejectionReason",
               exported, created_at as "createdAt", updated_at as "updatedAt"
        FROM expense_claim WHERE status = 'approved' AND exported = false`);
    ExpenseClaim[] claims = [];
    check from ExpenseClaimRow row in rows
        do {
            claims.push(claimRowToClaim(row));
        };
    check rows.close();
    return claims;
}

function createExportRecord(string generatedBy, string[] claimIds, string csvContent) returns PayrollExport|error {
    postgresql:Client db = check getDb();
    string id = newId("export");
    string timestamp = nowString();
    string fileUrl = "/payroll-exports/" + id + "/download";
    int claimCount = claimIds.length();
    _ = check db->execute(`
        INSERT INTO payroll_export (id, generated_by, file_url, generated_at, claim_count, csv_content)
        VALUES (${id}, ${generatedBy}, ${fileUrl}, ${timestamp}, ${claimCount}, ${csvContent})`);
    foreach string claimId in claimIds {
        _ = check db->execute(`
            UPDATE expense_claim SET exported = true, export_id = ${id} WHERE id = ${claimId}`);
    }
    return {id, generatedBy, fileUrl, generatedAt: timestamp, claimCount};
}

function listExports(int 'limit, int offset) returns [PayrollExport[], int]|error {
    postgresql:Client db = check getDb();
    int total = check db->queryRow(`SELECT COUNT(*)::int FROM payroll_export`);
    stream<PayrollExportRow, sql:Error?> rows = db->query(`
        SELECT id, generated_by as "generatedBy", file_url as "fileUrl", generated_at as "generatedAt", claim_count as "claimCount"
        FROM payroll_export ORDER BY generated_at DESC LIMIT ${'limit} OFFSET ${offset}`);
    PayrollExport[] exportList = [];
    check from PayrollExportRow row in rows
        do {
            exportList.push({id: row.id, generatedBy: row.generatedBy, fileUrl: row.fileUrl, generatedAt: row.generatedAt, claimCount: row.claimCount});
        };
    check rows.close();
    return [exportList, total];
}

function getExportCsv(string exportId) returns string?|error {
    postgresql:Client db = check getDb();
    string|sql:Error result = db->queryRow(`SELECT csv_content FROM payroll_export WHERE id = ${exportId}`);
    if result is sql:NoRowsError {
        return ();
    }
    if result is sql:Error {
        return result;
    }
    return result;
}
