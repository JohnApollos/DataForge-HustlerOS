# backend/hustle_score.py
from datetime import datetime
from typing import List, Dict

def calculate_hustle_score(transactions: List[Dict]) -> Dict:
    """
    Calculates the Hustle Score based on a list of parsed transactions.
    v0.1 Formula: (Income / Expenses) * (Active Days / 30)
    """
    total_income = 0.0
    total_expenses = 0.0
    income_days = set()

    for tx in transactions:
        if tx.get("type") == "Credit":
            total_income += tx.get("amount", 0.0)
            # We will add date parsing later to track days correctly
            # For now, we'll simulate a number of active days
        elif tx.get("type") == "Debit":
            total_expenses += tx.get("amount", 0.0)

    # Prevent division by zero
    if total_expenses == 0:
        cash_flow_ratio = 1.0
    else:
        cash_flow_ratio = total_income / total_expenses

    # --- SIMULATION FOR DEMO ---
    # In a real scenario, we'd parse timestamps and count unique days.
    # For now, let's assume 15 active income days for this batch.
    active_days = 15
    consistency_score = active_days / 30.0
    # --- END SIMULATION ---
    
    # Calculate final score (scaled to 100)
    hustle_score = cash_flow_ratio * consistency_score * 100

    return {
        "score": min(int(hustle_score), 100), # Cap score at 100
        "total_income": total_income,
        "total_expenses": total_expenses,
        "active_days_simulated": active_days
    }