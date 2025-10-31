# backend/main.py - (VERSION 3 - Now with Time Filters)
from fastapi import FastAPI
from pydantic import BaseModel
from typing import List, Dict, Optional

# Import our custom functions
from parser import parse_mpesa_sms
from hustle_score import calculate_hustle_score

app = FastAPI()

# --- Input Model ---
# We now accept an optional 'period' string
class SmsBatchInput(BaseModel):
    messages: List[str]
    period: Optional[str] = "all" # Default to "all" if app doesn't send it

# --- Output Model ---
class HustlerOSResponse(BaseModel):
    hustle_score: Dict
    parsed_transactions: List[Dict]

@app.get("/")
def read_root():
    return {"status": "Hustler OS Backend is running"}

@app.post("/analyze", response_model=HustlerOSResponse)
def analyze_sms_batch(batch: SmsBatchInput):
    
    # Parse ALL messages first
    parsed_results = [parse_mpesa_sms(msg) for msg in batch.messages]
    
    # Now, calculate the score *based on the requested period*
    score_data = calculate_hustle_score(parsed_results, batch.period)

    return {
        "hustle_score": score_data,
        "parsed_transactions": parsed_results # We still return ALL transactions
    }