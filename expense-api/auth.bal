import ballerina/http;

// Caller identity for expense-api is resolved from the gateway-injected
// X-User-Id header against this service's OWN app_user table (role +
// managerId live here, not in gateway-injected groups) — see security.md.
//
// Missing X-User-Id -> 401. No matching app_user row, or a role that does not
// permit the requested operation -> 403.
//
// Failures are carried as a typed `error` (never a second record type in the
// same union as AppUser) so callers can narrow reliably with `is` and map the
// failure to the right HTTP status once, in one place.

type ApiFailureDetail record {|
    int statusCode;
|};

type ApiFailure error<ApiFailureDetail>;

function apiFailure(int statusCode, string message) returns ApiFailure {
    return error ApiFailure(message, statusCode = statusCode);
}

// Resolves the caller's app_user row for a given X-User-Id header value.
function authenticate(string? xUserId) returns AppUser|ApiFailure {
    if xUserId is () || xUserId.trim() == "" {
        return apiFailure(401, "missing X-User-Id header");
    }
    AppUser?|error callerResult = findUserById(xUserId);
    if callerResult is error {
        return apiFailure(403, "unable to resolve caller identity");
    }
    AppUser? caller = callerResult;
    if caller is () {
        return apiFailure(403, "no user record for caller");
    }
    return caller;
}

function authFailureResponse(ApiFailure failure) returns http:Unauthorized|http:Forbidden {
    if failure.detail().statusCode == 401 {
        return <http:Unauthorized>{body: apiError(401, failure.message())};
    }
    return <http:Forbidden>{body: apiError(403, failure.message())};
}

function claimLookupFailureResponse(ApiFailure failure) returns http:NotFound|http:Forbidden|http:InternalServerError {
    int statusCode = failure.detail().statusCode;
    if statusCode == 404 {
        return <http:NotFound>{body: apiError(404, failure.message())};
    }
    if statusCode == 403 {
        return <http:Forbidden>{body: apiError(403, failure.message())};
    }
    return <http:InternalServerError>{body: apiError(500, failure.message())};
}

function isEmployee(AppUser caller) returns boolean => caller.role == "employee";

function isManager(AppUser caller) returns boolean => caller.role == "manager";

function isFinance(AppUser caller) returns boolean => caller.role == "finance";

// True when `employee` reports directly to `manager`.
function managerOwns(AppUser manager, AppUser employee) returns boolean {
    string? managerId = employee.managerId;
    if managerId is string {
        return managerId == manager.id;
    }
    return false;
}
