# backend/hustle_score.py - (VERSION 2 - Now with Date Filtering)
from datetime import datetime, timedelta

def calculate_hustle_score(transactions, period="all"):
    """
    Calculates the hustle score based on a list of parsed transactions
    and a time period ('week', 'month', or 'all').
    """
    
    # --- New Feature: Date Filtering ---
    # We are in Kenya, so we can use datetime.now()
    now = datetime.now()
    start_date = None

    if period == "week":
        # Start date is 7 days ago
        start_date = now - timedelta(days=7)
    elif period == "month":
        # Start date is 30 days ago
        start_date = now - timedelta(days=30)
    
    total_income = 0.0
    total_expenses = 0.0

    for tx in transactions:
        tx_type = tx.get("type")
        tx_date_str = tx.get("date")
        
        # Skip if we don't have a date or type
        if not tx_type or not tx_date_str:
            continue
            
        # --- New Filter Logic ---
        if start_date:
            try:
                # Convert the transaction's date string back into a datetime object
                tx_date = datetime.fromisoformat(tx_date_str)
                # If the transaction date is *before* our start date, skip it
                if tx_date < start_date:
                    continue
            except (ValueError, TypeError):
                continue # Skip if date is invalid

        # --- Original Calculation Logic ---
        amount = tx.get("amount", 0.0)
        if tx_type == "Credit":
            total_income += amount
        elif tx_type == "Debit":
            total_expenses += amount

    # Calculate score
    if total_expenses == 0:
        # If no expenses, score is 100 (or 50 if no income either)
        score = 100 if total_income > 0 else 50
    else:
        # Our original formula
        ratio = total_income / total_expenses
        score = int(ratio * 50)
        # Cap the score at 100
        score = min(score, 100)

    return {
        "score": score,
        "total_income": total_income,
        "total_expenses": total_expenses,
        "period": period
    }