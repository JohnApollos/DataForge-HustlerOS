# backend/parser.py - (VERSION 3.1 - Fixed Date/Time Parsing)
import re
from datetime import datetime

def parse_date(text):
    """
    Finds and parses the M-Pesa date format (e.g., 28/10/25 at 8:01 AM)
    """
    match = re.search(r'on (\d{1,2}/\d{1,2}/\d{2}) at (\d{1,2}:\d{2} [AP]M)', text)
    if match:
        date_part = match.group(1) # "24/10/25"
        time_part = match.group(2) # "6:32 AM"

        # --- THIS IS THE FIX ---
        # If the time is a single digit (e.g., "6:32"), add a "0" to make it "06:32"
        if time_part[1] == ':': 
            time_part = f"0{time_part}"
        # ---------------------
            
        date_str = f"{date_part} {time_part}"
        try:
            # Now, strptime will always work
            dt = datetime.strptime(date_str, '%d/%m/%y %I:%M %p')
            return dt.isoformat()
        except ValueError as e:
            print(f"Error parsing date: {e}") # For our debug
            return None
    return None

def parse_mpesa_sms(text):
    """
    Parses a single M-Pesa SMS string and returns a structured dictionary.
    """
    text = text.replace('\n', ' ').strip()
    
    tx_date = parse_date(text)
    
    def create_result(tx_type, amount, party):
        return {
            "type": tx_type,
            "amount": amount,
            "party": party,
            "date": tx_date
        }

    # PATTERN 1: Income (Received)
    pattern_income = re.search(r"received Ksh([\d,.]+) from ([\w\s]+) \d+", text)
    if pattern_income:
        return create_result(
            "Credit",
            float(pattern_income.group(1).replace(',', '')),
            pattern_income.group(2).strip()
        )

    # PATTERN 2: Sent to Business/Utility (for account)
    pattern_utility = re.search(r"Ksh([\d,.]+) sent to ([\w\s]+) for account", text)
    if pattern_utility:
        return create_result(
            "Debit",
            float(pattern_utility.group(1).replace(',', '')),
            pattern_utility.group(2).strip()
        )

    # PATTERN 3: Sent to Person (P2P)
    pattern_p2p = re.search(r"Ksh([\d,.]+) sent to ([\w\s]+?) (?:on \d|at \d|\d{10})", text)
    if pattern_p2p:
        return create_result(
            "Debit",
            float(pattern_p2p.group(1).replace(',', '')),
            pattern_p2p.group(2).strip()
        )

    # PATTERN 4: Paid to (Paybill/Till)
    pattern_paid_to = re.search(r"Ksh([\d,.]+) paid to ([\w\s\.]+) on \d+", text)
    if pattern_paid_to:
        return create_result(
            "Debit",
            float(pattern_paid_to.group(1).replace(',', '')),
            pattern_paid_to.group(2).strip()
        )
    
    # PATTERN 5: Withdrawal
    pattern_withdraw = re.search(r"Withdraw Ksh([\d,.]+) from ([\w\s\.'-]+) New", text)
    if pattern_withdraw:
        return create_result(
            "Debit",
            float(pattern_withdraw.group(1).replace(',', '')),
            f"Withdrawal ({pattern_withdraw.group(2).strip()})"
        )
    
    # --- If no pattern matched ---
    return {
        "type": None, 
        "amount": 0.0,
        "party": None,
        "date": None
    }