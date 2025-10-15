# backend/main.py - CORRECT VERSION
from fastapi import FastAPI
from pydantic import BaseModel
from typing import List, Dict

# Import our custom functions
from parser import parse_mpesa_sms
from hustle_score import calculate_hustle_score

app = FastAPI()

# Pydantic models for API request/response structure
class SmsBatchInput(BaseModel):
    messages: List[str]

class HustlerOSResponse(BaseModel):
    hustle_score: Dict
    parsed_transactions: List[Dict]

@app.get("/")
def read_root():
    return {"status": "Hustler OS Backend is running"}

@app.post("/analyze", response_model=HustlerOSResponse)
def analyze_sms_batch(batch: SmsBatchInput):
    """
    This is the main endpoint. It receives a batch of SMS messages, 
    parses them, calculates the Hustle Score, and returns the full analysis.
    """
    # 1. Parse all SMS messages into a structured list
    parsed_results = [parse_mpesa_sms(msg) for msg in batch.messages]

    # 2. Calculate the Hustle Score using the parsed data
    score_data = calculate_hustle_score(parsed_results)

    # 3. Return the combined response
    return {
        "hustle_score": score_data,
        "parsed_transactions": parsed_results
    }