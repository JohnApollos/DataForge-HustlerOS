# backend/hustle_score.py - (VERSION 3 - Now with Pie Chart Data)
from datetime import datetime, timedelta
from collections import defaultdict

def _filter_transactions(transactions, period="all"):
    """
    Internal helper function to filter transactions by date.
    Returns a new list of filtered transactions.
    """
    now = datetime.now()
    start_date = None

    if period == "week":
        start_date = now - timedelta(days=7)
    elif period == "month":
        start_date = now - timedelta(days=30)
    
    filtered_list = []
    for tx in transactions:
        tx_type = tx.get("type")
        tx_date_str = tx.get("date")
        
        if not tx_type or not tx_date_str:
            continue
            
        if start_date:
            try:
                tx_date = datetime.fromisoformat(tx_date_str)
                if tx_date < start_date:
                    continue
            except (ValueError, TypeError):
                continue
        
        filtered_list.append(tx)
    
    return filtered_list

def _get_top_expenses(filtered_transactions):
    """
    NEW: Analyzes filtered transactions to find top 5 expense categories.
    """
    expenses = defaultdict(float) # A dictionary to sum expenses by party
    
    for tx in filtered_transactions:
        if tx.get("type") == "Debit":
            party = tx.get("party", "Other")
            amount = tx.get("amount", 0.0)
            expenses[party] += amount
            
    # Sort the expenses from highest to lowest
    sorted_expenses = sorted(expenses.items(), key=lambda item: item[1], reverse=True)
    
    # Get the top 5
    top_5 = sorted_expenses[:5]
    
    # Format for the pie chart
    formatted_top_5 = [
        {"name": name, "amount": amount} for name, amount in top_5
    ]
    
    return formatted_top_5

def calculate_hustle_score(transactions, period="all"):
    """
    Calculates the hustle score and top expenses based on a list of
    parsed transactions and a time period.
    """
    
    # 1. Filter transactions by the selected period
    filtered_tx = _filter_transactions(transactions, period)
    
    total_income = 0.0
    total_expenses = 0.0

    for tx in filtered_tx:
        amount = tx.get("amount", 0.0)
        if tx.get("type") == "Credit":
            total_income += amount
        elif tx.get("type") == "Debit":
            total_expenses += amount

    # 2. Calculate the score
    if total_expenses == 0:
        score = 100 if total_income > 0 else 50
    else:
        ratio = total_income / total_expenses
        score = int(ratio * 50)
        score = min(score, 100) # Cap at 100

    # 3. NEW: Get the top 5 expenses from the *same* filtered list
    top_expenses = _get_top_expenses(filtered_tx)

    return {
        "score": score,
        "total_income": total_income,
        "total_expenses": total_expenses,
        "period": period,
        "top_expenses": top_expenses # <-- We've added our new data here!
    }