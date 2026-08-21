import ballerina/http;
import ballerina/log;
import ballerina/mime;

listener http:Listener expenseListener = new (9090);

service / on expenseListener {

    // ---- expense claims ----

    resource function get expense\-claims(
            @http:Header {name: "X-User-Id"} string? xUserId,
            string? status,
            string? employeeId,
            int 'limit = 20,
            int offset = 0)
            returns ClaimListResponse|http:Unauthorized|http:Forbidden|http:InternalServerError {

        AppUser|ApiFailure callerResult = authenticate(xUserId);
        if callerResult is ApiFailure {
            return authFailureResponse(callerResult);
        }
        AppUser caller = callerResult;
        if !isEmployee(caller) && !isManager(caller) && !isFinance(caller) {
            return <http:Forbidden>{body: apiError(403, "caller has no recognized role")};
        }

        int boundedLimit = boundLimit('limit);
        int boundedOffset = boundOffset(offset);

        string? filterEmployeeId = employeeId;
        string[]? reportIds = ();
        if isEmployee(caller) {
            filterEmployeeId = caller.id;
        } else if isManager(caller) {
            string[]|error reports = listDirectReportIds(caller.id);
            if reports is error {
                log:printError("failed to list direct reports", 'error = reports);
                return <http:InternalServerError>{body: apiError(500, "failed to list claims")};
            }
            reportIds = reports;
        }

        [ExpenseClaim[], int]|error result = listClaims(status, filterEmployeeId, reportIds, boundedLimit, boundedOffset);
        if result is error {
            log:printError("failed to list expense claims", 'error = result);
            return <http:InternalServerError>{body: apiError(500, "failed to list claims")};
        }
        [ExpenseClaim[], int] [claims, total] = result;

        string queryPrefix = status is string ? "status=" + status + "&" : "";
        return {
            count: total,
            next: nextLink("/expense-claims", queryPrefix, total, boundedLimit, boundedOffset),
            previous: previousLink("/expense-claims", queryPrefix, boundedLimit, boundedOffset),
            data: claims
        };
    }

    resource function post expense\-claims(
            @http:Header {name: "X-User-Id"} string? xUserId,
            ExpenseClaimInput payload)
            returns http:Created|http:BadRequest|http:Unauthorized|http:Forbidden|http:InternalServerError {

        AppUser|ApiFailure callerResult = authenticate(xUserId);
        if callerResult is ApiFailure {
            return authFailureResponse(callerResult);
        }
        AppUser caller = callerResult;
        if !isEmployee(caller) {
            return <http:Forbidden>{body: apiError(403, "only employees can submit expense claims")};
        }

        string? validationError = validateClaimInput(payload);
        if validationError is string {
            return <http:BadRequest>{body: apiError(400, validationError)};
        }

        ExpenseClaim|error created = insertClaim(caller.id, payload);
        if created is error {
            log:printError("failed to create expense claim", 'error = created);
            return <http:InternalServerError>{body: apiError(500, "failed to create claim")};
        }

        notifyManagerOfClaim(caller, created);
        return <http:Created>{body: created};
    }

    resource function get expense\-claims/[string claimId](
            @http:Header {name: "X-User-Id"} string? xUserId)
            returns ExpenseClaim|http:Unauthorized|http:Forbidden|http:NotFound|http:InternalServerError {

        AppUser|ApiFailure callerResult = authenticate(xUserId);
        if callerResult is ApiFailure {
            return authFailureResponse(callerResult);
        }
        AppUser caller = callerResult;

        ExpenseClaim?|error claimResult = getClaimById(claimId);
        if claimResult is error {
            log:printError("failed to fetch expense claim", 'error = claimResult);
            return <http:InternalServerError>{body: apiError(500, "failed to fetch claim")};
        }
        ExpenseClaim? claim = claimResult;
        if claim is () {
            return <http:NotFound>{body: apiError(404, "claim not found")};
        }

        boolean|ApiFailure visible = canView(caller, claim);
        if visible is ApiFailure {
            return claimLookupFailureResponse(visible);
        }
        if !visible {
            return <http:NotFound>{body: apiError(404, "claim not found")};
        }
        return claim;
    }

    resource function put expense\-claims/[string claimId](
            @http:Header {name: "X-User-Id"} string? xUserId,
            ExpenseClaimInput payload)
            returns ExpenseClaim|http:BadRequest|http:Unauthorized|http:Forbidden|http:NotFound|http:InternalServerError {

        AppUser|ApiFailure callerResult = authenticate(xUserId);
        if callerResult is ApiFailure {
            return authFailureResponse(callerResult);
        }
        AppUser caller = callerResult;

        ExpenseClaim?|error claimResult = getClaimById(claimId);
        if claimResult is error {
            log:printError("failed to fetch expense claim", 'error = claimResult);
            return <http:InternalServerError>{body: apiError(500, "failed to fetch claim")};
        }
        ExpenseClaim? claim = claimResult;
        if claim is () {
            return <http:NotFound>{body: apiError(404, "claim not found")};
        }
        if !isEmployee(caller) || claim.employeeId != caller.id {
            return <http:Forbidden>{body: apiError(403, "caller does not own this claim")};
        }
        if claim.status != "draft" && claim.status != "rejected" {
            return <http:BadRequest>{body: apiError(400, "claim is not editable in its current status")};
        }

        string? validationError = validateClaimInput(payload);
        if validationError is string {
            return <http:BadRequest>{body: apiError(400, validationError)};
        }

        ExpenseClaim?|error updated = updateClaimContent(claimId, payload);
        if updated is error {
            log:printError("failed to update expense claim", 'error = updated);
            return <http:InternalServerError>{body: apiError(500, "failed to update claim")};
        }
        ExpenseClaim? updatedClaim = updated;
        if updatedClaim is () {
            return <http:NotFound>{body: apiError(404, "claim not found")};
        }
        return updatedClaim;
    }

    resource function post expense\-claims/[string claimId]/receipt(
            @http:Header {name: "X-User-Id"} string? xUserId,
            http:Request request)
            returns ExpenseClaim|http:BadRequest|http:Unauthorized|http:Forbidden|http:NotFound|http:InternalServerError {

        AppUser|ApiFailure callerResult = authenticate(xUserId);
        if callerResult is ApiFailure {
            return authFailureResponse(callerResult);
        }
        AppUser caller = callerResult;

        ExpenseClaim?|error claimResult = getClaimById(claimId);
        if claimResult is error {
            log:printError("failed to fetch expense claim", 'error = claimResult);
            return <http:InternalServerError>{body: apiError(500, "failed to fetch claim")};
        }
        ExpenseClaim? claim = claimResult;
        if claim is () {
            return <http:NotFound>{body: apiError(404, "claim not found")};
        }
        if !isEmployee(caller) || claim.employeeId != caller.id {
            return <http:Forbidden>{body: apiError(403, "caller does not own this claim")};
        }

        mime:Entity[]|http:ClientError bodyParts = request.getBodyParts();
        if bodyParts is http:ClientError {
            return <http:BadRequest>{body: apiError(400, "expected multipart/form-data with a file part")};
        }

        byte[]? fileContent = ();
        string fileName = "receipt";
        string contentType = "application/octet-stream";
        foreach mime:Entity part in bodyParts {
            mime:ContentDisposition disposition = part.getContentDisposition();
            if disposition.name == "file" {
                byte[]|mime:ParserError content = part.getByteArray();
                if content is byte[] {
                    fileContent = content;
                    string partFileName = disposition.fileName;
                    if partFileName != "" {
                        fileName = partFileName;
                    }
                    contentType = part.getContentType();
                }
            }
        }

        byte[]? uploadedContent = fileContent;
        if uploadedContent is () || uploadedContent.length() == 0 {
            return <http:BadRequest>{body: apiError(400, "missing file part")};
        }

        ExpenseClaim?|error updated = setClaimReceipt(claimId, uploadedContent, fileName, contentType);
        if updated is error {
            log:printError("failed to store receipt", 'error = updated);
            return <http:InternalServerError>{body: apiError(500, "failed to store receipt")};
        }
        ExpenseClaim? updatedClaim = updated;
        if updatedClaim is () {
            return <http:NotFound>{body: apiError(404, "claim not found")};
        }
        return updatedClaim;
    }

    resource function post expense\-claims/[string claimId]/resubmit(
            @http:Header {name: "X-User-Id"} string? xUserId)
            returns ExpenseClaim|http:BadRequest|http:Unauthorized|http:Forbidden|http:NotFound|http:InternalServerError {

        AppUser|ApiFailure callerResult = authenticate(xUserId);
        if callerResult is ApiFailure {
            return authFailureResponse(callerResult);
        }
        AppUser caller = callerResult;

        ExpenseClaim?|error claimResult = getClaimById(claimId);
        if claimResult is error {
            log:printError("failed to fetch expense claim", 'error = claimResult);
            return <http:InternalServerError>{body: apiError(500, "failed to fetch claim")};
        }
        ExpenseClaim? claim = claimResult;
        if claim is () {
            return <http:NotFound>{body: apiError(404, "claim not found")};
        }
        if !isEmployee(caller) || claim.employeeId != caller.id {
            return <http:Forbidden>{body: apiError(403, "caller does not own this claim")};
        }
        if claim.status != "rejected" {
            return <http:BadRequest>{body: apiError(400, "claim is not in a resubmittable state")};
        }

        ExpenseClaim?|error updated = resubmitClaimRow(claimId);
        if updated is error {
            log:printError("failed to resubmit expense claim", 'error = updated);
            return <http:InternalServerError>{body: apiError(500, "failed to resubmit claim")};
        }
        ExpenseClaim? updatedClaim = updated;
        if updatedClaim is () {
            return <http:NotFound>{body: apiError(404, "claim not found")};
        }
        notifyManagerOfClaim(caller, updatedClaim);
        return updatedClaim;
    }

    resource function post expense\-claims/[string claimId]/approve(
            @http:Header {name: "X-User-Id"} string? xUserId)
            returns ExpenseClaim|http:BadRequest|http:Unauthorized|http:Forbidden|http:NotFound|http:InternalServerError {

        AppUser|ApiFailure callerResult = authenticate(xUserId);
        if callerResult is ApiFailure {
            return authFailureResponse(callerResult);
        }
        AppUser caller = callerResult;
        if !isManager(caller) {
            return <http:Forbidden>{body: apiError(403, "caller is not the claim's manager")};
        }

        [ExpenseClaim, AppUser]|ApiFailure loaded = loadClaimForManagerDecision(claimId, caller);
        if loaded is ApiFailure {
            return claimLookupFailureResponse(loaded);
        }
        [ExpenseClaim, AppUser] [claim, employee] = loaded;

        if claim.status != "submitted" {
            return <http:BadRequest>{body: apiError(400, "claim is not pending approval")};
        }

        ExpenseClaim?|error updated = decideClaim(claimId, caller.id, "approved", ());
        if updated is error {
            log:printError("failed to approve expense claim", 'error = updated);
            return <http:InternalServerError>{body: apiError(500, "failed to approve claim")};
        }
        ExpenseClaim? updatedClaim = updated;
        if updatedClaim is () {
            return <http:NotFound>{body: apiError(404, "claim not found")};
        }
        notifyEmployeeOfApproval(employee, updatedClaim);
        return updatedClaim;
    }

    resource function post expense\-claims/[string claimId]/reject(
            @http:Header {name: "X-User-Id"} string? xUserId,
            RejectRequest payload)
            returns ExpenseClaim|http:BadRequest|http:Unauthorized|http:Forbidden|http:NotFound|http:InternalServerError {

        AppUser|ApiFailure callerResult = authenticate(xUserId);
        if callerResult is ApiFailure {
            return authFailureResponse(callerResult);
        }
        AppUser caller = callerResult;
        if !isManager(caller) {
            return <http:Forbidden>{body: apiError(403, "caller is not the claim's manager")};
        }
        if payload.reason.trim() == "" {
            return <http:BadRequest>{body: apiError(400, "reason is required")};
        }

        [ExpenseClaim, AppUser]|ApiFailure loaded = loadClaimForManagerDecision(claimId, caller);
        if loaded is ApiFailure {
            return claimLookupFailureResponse(loaded);
        }
        [ExpenseClaim, AppUser] [claim, employee] = loaded;

        if claim.status != "submitted" {
            return <http:BadRequest>{body: apiError(400, "claim is not pending approval")};
        }

        ExpenseClaim?|error updated = decideClaim(claimId, caller.id, "rejected", payload.reason);
        if updated is error {
            log:printError("failed to reject expense claim", 'error = updated);
            return <http:InternalServerError>{body: apiError(500, "failed to reject claim")};
        }
        ExpenseClaim? updatedClaim = updated;
        if updatedClaim is () {
            return <http:NotFound>{body: apiError(404, "claim not found")};
        }
        notifyEmployeeOfRejection(employee, updatedClaim);
        return updatedClaim;
    }

    // ---- payroll exports ----

    resource function get payroll\-exports(
            @http:Header {name: "X-User-Id"} string? xUserId,
            int 'limit = 20,
            int offset = 0)
            returns ExportListResponse|http:Unauthorized|http:Forbidden|http:InternalServerError {

        AppUser|ApiFailure callerResult = authenticate(xUserId);
        if callerResult is ApiFailure {
            return authFailureResponse(callerResult);
        }
        AppUser caller = callerResult;
        if !isFinance(caller) {
            return <http:Forbidden>{body: apiError(403, "only finance can manage payroll exports")};
        }

        int boundedLimit = boundLimit('limit);
        int boundedOffset = boundOffset(offset);

        [PayrollExport[], int]|error result = listExports(boundedLimit, boundedOffset);
        if result is error {
            log:printError("failed to list payroll exports", 'error = result);
            return <http:InternalServerError>{body: apiError(500, "failed to list payroll exports")};
        }
        [PayrollExport[], int] [exportBatches, total] = result;

        return {
            count: total,
            next: nextLink("/payroll-exports", "", total, boundedLimit, boundedOffset),
            previous: previousLink("/payroll-exports", "", boundedLimit, boundedOffset),
            data: exportBatches
        };
    }

    resource function post payroll\-exports(
            @http:Header {name: "X-User-Id"} string? xUserId)
            returns http:Created|http:BadRequest|http:Unauthorized|http:Forbidden|http:InternalServerError {

        AppUser|ApiFailure callerResult = authenticate(xUserId);
        if callerResult is ApiFailure {
            return authFailureResponse(callerResult);
        }
        AppUser caller = callerResult;
        if !isFinance(caller) {
            return <http:Forbidden>{body: apiError(403, "only finance can manage payroll exports")};
        }

        ExpenseClaim[]|error unexported = listUnexportedApprovedClaims();
        if unexported is error {
            log:printError("failed to list unexported claims", 'error = unexported);
            return <http:InternalServerError>{body: apiError(500, "failed to gather claims for export")};
        }
        if unexported.length() == 0 {
            return <http:BadRequest>{body: apiError(400, "no approved, unexported claims to export")};
        }

        string csvContent = buildExportCsv(unexported);
        string[] claimIds = unexported.map(claim => claim.id);

        PayrollExport|error created = createExportRecord(caller.id, claimIds, csvContent);
        if created is error {
            log:printError("failed to create payroll export", 'error = created);
            return <http:InternalServerError>{body: apiError(500, "failed to create payroll export")};
        }
        return <http:Created>{body: created};
    }

    resource function get payroll\-exports/[string exportId]/download(
            @http:Header {name: "X-User-Id"} string? xUserId)
            returns http:Ok|http:Unauthorized|http:Forbidden|http:NotFound|http:InternalServerError {

        AppUser|ApiFailure callerResult = authenticate(xUserId);
        if callerResult is ApiFailure {
            return authFailureResponse(callerResult);
        }
        AppUser caller = callerResult;
        if !isFinance(caller) {
            return <http:Forbidden>{body: apiError(403, "only finance can manage payroll exports")};
        }

        string?|error csvResult = getExportCsv(exportId);
        if csvResult is error {
            log:printError("failed to load payroll export", 'error = csvResult);
            return <http:InternalServerError>{body: apiError(500, "failed to load payroll export")};
        }
        string? csvContent = csvResult;
        if csvContent is () {
            return <http:NotFound>{body: apiError(404, "export batch not found")};
        }
        return <http:Ok>{body: csvContent, mediaType: "text/csv"};
    }
}

// ---- shared handler helpers ----

function canView(AppUser caller, ExpenseClaim claim) returns boolean|ApiFailure {
    if isFinance(caller) {
        return true;
    }
    if isEmployee(caller) {
        return claim.employeeId == caller.id;
    }
    if isManager(caller) {
        AppUser?|error ownerResult = findUserById(claim.employeeId);
        if ownerResult is error {
            log:printError("failed to resolve claim owner", 'error = ownerResult);
            return apiFailure(500, "failed to resolve claim owner");
        }
        AppUser? owner = ownerResult;
        if owner is () {
            return false;
        }
        return managerOwns(caller, owner);
    }
    return false;
}

// Loads the claim and its owning employee for a manager decision (approve or
// reject), enforcing that the claim belongs to one of the manager's own
// direct reports.
function loadClaimForManagerDecision(string claimId, AppUser manager) returns [ExpenseClaim, AppUser]|ApiFailure {
    ExpenseClaim?|error claimResult = getClaimById(claimId);
    if claimResult is error {
        log:printError("failed to fetch expense claim", 'error = claimResult);
        return apiFailure(500, "failed to fetch claim");
    }
    ExpenseClaim? claim = claimResult;
    if claim is () {
        return apiFailure(404, "claim not found");
    }

    AppUser?|error ownerResult = findUserById(claim.employeeId);
    if ownerResult is error {
        log:printError("failed to resolve claim owner", 'error = ownerResult);
        return apiFailure(500, "failed to resolve claim owner");
    }
    AppUser? owner = ownerResult;
    if owner is () || !managerOwns(manager, owner) {
        return apiFailure(403, "caller is not the claim's manager");
    }
    return [claim, owner];
}

function notifyManagerOfClaim(AppUser employee, ExpenseClaim claim) {
    string? managerId = employee.managerId;
    if managerId is () {
        return;
    }
    AppUser?|error managerResult = findUserById(managerId);
    if managerResult is error {
        log:printWarn("failed to resolve manager for notification", 'error = managerResult);
        return;
    }
    AppUser? manager = managerResult;
    if manager is AppUser {
        notifyManagerOfSubmission(manager, claim);
    }
}

function boundLimit(int requested) returns int {
    if requested < 1 {
        return 20;
    }
    if requested > 100 {
        return 100;
    }
    return requested;
}

function boundOffset(int requested) returns int {
    if requested < 0 {
        return 0;
    }
    return requested;
}
