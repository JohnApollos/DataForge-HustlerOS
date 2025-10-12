from fastapi import FastAPI
from pydantic import BaseModel
from typing import List

# Import the parser function
from parser import parse_mpesa_sms

app = FastAPI()

class SmsInput(BaseModel):
    sms_text: str

class SmsBatchInput(BaseModel):
    messages: List[str]

@app.get("/")
def read_root():
    return {"status": "Hustler OS Backend is running"}

@app.post("/parse/single")
def parse_single_sms(sms: SmsInput):
    parsed_data = parse_mpesa_sms(sms.sms_text)
    return {"parsed_data": parsed_data}

@app.post("/parse/batch")
def parse_sms_batch(batch: SmsBatchInput):
    results = [parse_mpesa_sms(msg) for msg in batch.messages]
    return {"parsed_results": results}