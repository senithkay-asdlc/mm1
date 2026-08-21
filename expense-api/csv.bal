// Builds the payroll export CSV body from the claims included in a batch.

function buildExportCsv(ExpenseClaim[] claims) returns string {
    string csv = "claimId,employeeId,amount,category,expenseDate,description\n";
    foreach ExpenseClaim claim in claims {
        csv += string `${claim.id},${claim.employeeId},${claim.amount.toBalString()},${csvEscape(claim.category)},${claim.expenseDate},${csvEscape(claim.description)}` + "\n";
    }
    return csv;
}

function csvEscape(string value) returns string {
    if value.includes(",") || value.includes("\"") || value.includes("\n") {
        string escaped = re `"`.replaceAll(value, "\"\"");
        return "\"" + escaped + "\"";
    }
    return value;
}
