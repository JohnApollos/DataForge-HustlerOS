import re

def parse_mpesa_sms(sms_text: str):
    patterns = {
        'funds_received': re.compile(r"([A-Z0-9]+) Confirmed\. You have received Ksh([\d,\.]+)\sfrom\s(.+?)\son"),
        'paybill_paid': re.compile(r"([A-Z0-9]+) Confirmed\. Ksh([\d,\.]+)\spaid to\s(.+?)\sfor account"),
        'buy_goods': re.compile(r"([A-Z0-9]+) Confirmed\. Ksh([\d,\.]+)\spaid to\s(.+?)\. on"),
        'withdrawal': re.compile(r"([A-Z0-9]+) Confirmed\. on\s.+?Withdraw Ksh([\d,\.]+)\sfrom")
    }

    for tx_type, pattern in patterns.items():
        match = pattern.search(sms_text)
        if match:
            if tx_type == 'funds_received':
                return {"type": "Credit", "amount": float(match.group(2).replace(',', '')), "party": match.group(3).strip(), "receipt": match.group(1)}
            elif tx_type in ['paybill_paid', 'buy_goods']:
                return {"type": "Debit", "amount": float(match.group(2).replace(',', '')), "party": match.group(3).strip(), "receipt": match.group(1)}
            elif tx_type == 'withdrawal':
                 return {"type": "Debit", "amount": float(match.group(2).replace(',', '')), "party": "Agent", "receipt": match.group(1)}
    return {"type": "Unknown", "original_sms": sms_text}