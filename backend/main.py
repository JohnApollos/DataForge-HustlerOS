# backend/main.py - (Reverted to "First Light" Version)
from fastapi import FastAPI
from pydantic import BaseModel
from typing import List, Dict

# Import our custom functions
from parser import parse_mpesa_sms
from hustle_score import calculate_hustle_score

app = FastAPI()

# --- Input Model ---
class SmsBatchInput(BaseModel):
    messages: List[str]

# --- Output Model ---
class HustlerOSResponse(BaseModel):
    hustle_score: Dict
    parsed_transactions: List[Dict]

@app.get("/")
def read_root():
    return {"status": "Hustler OS Backend is running"}

@app.post("/analyze", response_model=HustlerOSResponse)
def analyze_sms_batch(batch: SmsBatchInput):
    parsed_results = [parse_mpesa_sms(msg) for msg in batch.messages]
    score_data = calculate_hustle_score(parsed_results)

    # We are NOT calling the AI here.
    
    return {
        "hustle_score": score_data,
        "parsed_transactions": parsed_results
    }