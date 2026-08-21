// Shared helpers for error payloads and collection pagination envelopes.

function apiError(int code, string message) returns ApiError => {code, message};

function paginationLink(string basePath, string queryPrefix, int 'limit, int offset) returns string {
    return basePath + "?" + queryPrefix + "limit=" + 'limit.toString() + "&offset=" + offset.toString();
}

function nextLink(string basePath, string queryPrefix, int total, int 'limit, int offset) returns string? {
    int nextOffset = offset + 'limit;
    if nextOffset >= total {
        return ();
    }
    return paginationLink(basePath, queryPrefix, 'limit, nextOffset);
}

function previousLink(string basePath, string queryPrefix, int 'limit, int offset) returns string? {
    if offset <= 0 {
        return ();
    }
    int prevOffset = offset - 'limit;
    if prevOffset < 0 {
        prevOffset = 0;
    }
    return paginationLink(basePath, queryPrefix, 'limit, prevOffset);
}
