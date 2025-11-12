# backend/main.py - (VERSION 4 - Now with AI Invoice Matching)
from fastapi import FastAPI
from pydantic import BaseModel
from typing import List, Dict, Optional, Any
import os # For reading environment variables
from supabase import create_client, Client # For Supabase connection

# Import our custom functions (from your existing files)
from parser import parse_mpesa_sms
from hustle_score import calculate_hustle_score

# --- 1. Supabase Initialization ---
SUPABASE_URL = os.environ.get("SUPABASE_URL")
SUPABASE_KEY = os.environ.get("SUPABASE_SERVICE_KEY")

# Create the Supabase "admin" client
supabase: Client = create_client(SUPABASE_URL, SUPABASE_KEY)

app = FastAPI()

# --- 2. Update Input Model ---
class SmsBatchInput(BaseModel):
    messages: List[str]
    period: Optional[str] = "all"
    user_id: str # <-- NEW & REQUIRED

# --- 3. Output Model (from your file) ---
class HustlerOSResponse(BaseModel):
    hustle_score: Dict
    parsed_transactions: List[Dict]

# --- 4. The New "AI Agent" Logic ---
def match_invoices(new_payments: List[Dict[str, Any]], user_id: str):
    """
    Tries to match new M-Pesa payments to pending invoices in Supabase.
    """
    for payment in new_payments:
        # 'name' field from parser is the sender (e.g., "0712345678" or "JUMA")
        sender_phone = payment.get('name')
        payment_amount = payment.get('amount', 0)
        
        # We only care about "Income" types with a valid sender and amount
        if payment.get('type') != 'Income' or not sender_phone or payment_amount <= 0:
            continue
            
        try:
            # Query: Find pending invoices for this user from this specific phone number
            query = supabase.table("invoices").select("*") \
                .eq("user_id", user_id) \
                .eq("client_phone", sender_phone) \
                .neq("status", "paid") # Get all 'pending' or 'partially_paid'

            response = query.execute()
            
            if not response.data:
                # No pending invoices from this phone number, check next payment
                continue
                
            # Found pending invoices from this client. Try to match.
            for invoice in response.data:
                invoice_id = invoice['id']
                total_amount = invoice['total_amount']
                amount_paid = invoice['amount_paid']
                amount_due = total_amount - amount_paid
                
                # Using a small tolerance (0.01) for float comparison
                if abs(payment_amount - amount_due) < 0.01:
                    # --- 1. Full Payment Match ---
                    supabase.table("invoices") \
                        .update({
                            "status": "paid",
                            "amount_paid": total_amount
                        }) \
                        .eq("id", invoice_id) \
                        .execute()
                    break # Payment is fully matched, stop checking this payment
                    
                elif payment_amount < amount_due:
                    # --- 2. Partial Payment Match ---
                    new_amount_paid = amount_paid + payment_amount
                    supabase.table("invoices") \
                        .update({
                            "status": "partially_paid",
                            "amount_paid": new_amount_paid
                        }) \
                        .eq("id", invoice_id) \
                        .execute()
                    break # Payment is applied, stop checking this payment
        
        except Exception as e:
            print(f"Error matching invoice: {e}")
            # Don't crash the main analysis if matching fails
            continue

# --- 5. The Main Endpoints (Updated) ---
@app.get("/")
def read_root():
    return {"status": "Hustler OS Backend v4 (with Invoice-Matching) is running"}

@app.post("/analyze", response_model=HustlerOSResponse)
def analyze_sms_batch(batch: SmsBatchInput):
    
    # 1. Parse ALL messages first (your code)
    # Filter out any 'None' results if parser fails
    parsed_results = [parse_mpesa_sms(msg) for msg in batch.messages]
    valid_transactions = [tx for tx in parsed_results if tx is not None]
    
    # 2. Now, calculate the score *based on the requested period* (your code)
    score_data = calculate_hustle_score(valid_transactions, batch.period)
    
    # 3. --- NEW STEP: Run the AI Agent ---
    try:
        # We pass *all* valid transactions. 
        # The agent will filter for 'Income' types.
        match_invoices(valid_transactions, batch.user_id)
    except Exception as e:
        print(f"Could not run invoice matching: {e}")
        # Don't fail the request if matching has an error

    # 4. Return the response (your code)
    return {
        "hustle_score": score_data,
        "parsed_transactions": valid_transactions # Return only valid ones
    }