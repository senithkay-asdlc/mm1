import ballerina/http;
import ballerina/log;
import ballerinax/sendgrid;

// The email-provider dependency (SendGrid). SENDGRID_API_KEY may be empty in
// this environment (external credentials aren't configured yet) — a missing
// or invalid key must never crash the request or block a claim operation, so
// the client is optional and every send is best-effort.
final sendgrid:Client? sendgridClient = initSendgridClient();

const string emailSender = "notifications@expense-claims.internal";

function initSendgridClient() returns sendgrid:Client? {
    if sendgridApiKey == "" {
        log:printWarn("SENDGRID_API_KEY is empty; email notifications are disabled");
        return ();
    }
    sendgrid:Client|error result = new ({auth: {token: sendgridApiKey}});
    if result is error {
        log:printWarn("failed to initialize SendGrid client; email notifications are disabled", 'error = result);
        return ();
    }
    return result;
}

// Fire-and-forget notification: logs and swallows every failure so a
// down/unconfigured email provider never fails the caller's request.
function sendNotification(string toEmail, string subject, string body) {
    sendgrid:Client? clientRef = sendgridClient;
    if clientRef is () {
        log:printInfo("skipping email notification (no SendGrid client)", to = toEmail, subject = subject);
        return;
    }
    sendgrid:SendEmailRequest mail = {
        personalizations: [{'to: [{email: toEmail}]}],
        'from: {email: emailSender},
        subject,
        content: [{'type: "text/plain", value: body}]
    };
    http:Response|error result = clientRef->sendMail(mail);
    if result is error {
        log:printWarn("failed to send email notification", 'error = result, to = toEmail, subject = subject);
    }
}

function notifyManagerOfSubmission(AppUser manager, ExpenseClaim claim) {
    string subject = "New expense claim submitted";
    string body = string `${claim.employeeId} submitted an expense claim (${claim.category}, ${claim.amount.toBalString()}) for your review.`;
    sendNotification(manager.email, subject, body);
}

function notifyEmployeeOfApproval(AppUser employee, ExpenseClaim claim) {
    string subject = "Your expense claim was approved";
    string body = string `Your expense claim ${claim.id} (${claim.category}, ${claim.amount.toBalString()}) has been approved.`;
    sendNotification(employee.email, subject, body);
}

function notifyEmployeeOfRejection(AppUser employee, ExpenseClaim claim) {
    string subject = "Your expense claim was rejected";
    string reason = claim.rejectionReason ?: "no reason given";
    string body = string `Your expense claim ${claim.id} (${claim.category}, ${claim.amount.toBalString()}) was rejected: ${reason}`;
    sendNotification(employee.email, subject, body);
}
