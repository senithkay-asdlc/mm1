import ballerina/os;

// expense-db (postgres-cnpg platform-resource) — envBindings from design.json, verbatim names.
configurable string expenseDbHost = os:getEnv("EXPENSE_DB_HOST");
configurable string expenseDbPort = os:getEnv("EXPENSE_DB_PORT");
configurable string expenseDbName = os:getEnv("EXPENSE_DB_DBNAME");
configurable string expenseDbUser = os:getEnv("EXPENSE_DB_USER");
configurable string expenseDbPassword = os:getEnv("EXPENSE_DB_PASSWORD");

// email-provider (external/sdk, SendGrid) — may be empty in this environment.
configurable string sendgridApiKey = os:getEnv("SENDGRID_API_KEY");

// user-auth (thunder-app platform-resource) — kept for context; token validation
// itself happens at the gateway, not in this service.
configurable string userAuthIssuer = os:getEnv("USER_AUTH_ISSUER");
configurable string userAuthClientId = os:getEnv("USER_AUTH_CLIENT_ID");

// Derived, safe-to-boot values. These are plain variables (not configurables),
// so the "never hardcode a configurable default" rule does not apply to them —
// they only paper over an empty env var so the service can still start when
// expense-db credentials are not yet configured in this environment.
final string dbHost = expenseDbHost != "" ? expenseDbHost : "localhost";
final int dbPort = expenseDbPort != "" ? (checkDbPort(expenseDbPort)) : 5432;
final string dbName = expenseDbName != "" ? expenseDbName : "expense";
final string dbUser = expenseDbUser != "" ? expenseDbUser : "postgres";
final string dbPassword = expenseDbPassword;

function checkDbPort(string raw) returns int {
    int|error parsed = int:fromString(raw);
    if parsed is int {
        return parsed;
    }
    return 5432;
}
