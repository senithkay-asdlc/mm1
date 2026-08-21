function validateClaimInput(ExpenseClaimInput input) returns string? {
    if input.amount <= 0d {
        return "amount must be greater than zero";
    }
    if input.category.trim() == "" {
        return "category is required";
    }
    if input.expenseDate.trim() == "" {
        return "expenseDate is required";
    }
    if input.description.trim() == "" {
        return "description is required";
    }
    return ();
}
