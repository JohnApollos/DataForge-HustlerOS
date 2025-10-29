# backend/parser.py - (VERSION 2 - MUCH SMARTER)
import re

def parse_mpesa_sms(text):
    """
    Parses a single M-Pesa SMS string and returns a structured dictionary.
    """
    # Remove newlines and extra spaces for easier parsing
    text = text.replace('\n', ' ').strip()
    
    # --- We will try patterns in order of priority ---

    # PATTERN 1: Income (Received)
    # "You have received Ksh300.00 from EDNA BOLO 0724297970..."
    pattern_income = re.search(r"received Ksh([\d,.]+) from ([\w\s]+) \d+", text)
    if pattern_income:
        return {
            "type": "Credit",
            "amount": float(pattern_income.group(1).replace(',', '')),
            "party": pattern_income.group(2).strip()
        }

    # PATTERN 2: Sent to Business/Utility (for account)
    # "Ksh20.00 sent to AIRTEL MONEY for account 254788283068..."
    # "Ksh20.00 sent to SAFARICOM DATA BUNDLES for account..."
    pattern_utility = re.search(r"Ksh([\d,.]+) sent to ([\w\s]+) for account", text)
    if pattern_utility:
        return {
            "type": "Debit",
            "amount": float(pattern_utility.group(1).replace(',', '')),
            "party": pattern_utility.group(2).strip()
        }

    # PATTERN 3: Sent to Person (P2P)
    # "Ksh20.00 sent to AGNES OGADA 0740664352..."
    # "Ksh100.00 sent to Kevin Musungu on 24/10/25..."
    # We use ([\w\s]+?) (non-greedy) to stop at the first match of a phone number OR the word 'on'
    pattern_p2p = re.search(r"Ksh([\d,.]+) sent to ([\w\s]+?) (?:on \d|at \d|\d{10})", text)
    if pattern_p2p:
        return {
            "type": "Debit",
            "amount": float(pattern_p2p.group(1).replace(',', '')),
            "party": pattern_p2p.group(2).strip()
        }

    # PATTERN 4: Paid to (Paybill/Till)
    # "Ksh65.00 paid to JANET OSESE..."
    pattern_paid_to = re.search(r"Ksh([\d,.]+) paid to ([\w\s\.]+) on \d+", text)
    if pattern_paid_to:
        return {
            "type": "Debit",
            "amount": float(pattern_paid_to.group(1).replace(',', '')),
            "party": pattern_paid_to.group(2).strip()
        }
    
    # PATTERN 5: Withdrawal
    # (Keeping our old rule, as it's still needed)
    pattern_withdraw = re.search(r"Withdraw Ksh([\d,.]+) from ([\w\s\.'-]+) New", text)
    if pattern_withdraw:
        return {
            "type": "Debit",
            "amount": float(pattern_withdraw.group(1).replace(',', '')),
            "party": f"Withdrawal ({pattern_withdraw.group(2).strip()})"
        }
    
    # --- If no pattern matched ---
    # This will catch "Failed, you have entered the wrong PIN..."
    # and any other message we don't understand yet.
    return {
        "type": None, 
        "amount": 0.0,
        "party": None
    }