# backend/test_client.py
import requests
import json
from sample_sms import SAMPLE_MESSAGES

# The URL where your local FastAPI server is running
API_URL = "http://127.0.0.1:8000/analyze"

def test_api():
    print("--- 🚀 Starting Hustler OS Backend Test ---")
    
    # The data we are sending, formatted as the API expects
    payload = {"messages": SAMPLE_MESSAGES}
    
    try:
        # Send the POST request to the /analyze endpoint
        response = requests.post(API_URL, json=payload)
        
        # Check if the request was successful
        if response.status_code == 200:
            print("--- ✅ API Call Successful! ---")
            
            # Print the JSON response in a readable format
            response_data = response.json()
            print(json.dumps(response_data, indent=2))
            
            print("\n--- Test Complete ---")
        else:
            print(f"--- ❌ API Call Failed with Status Code: {response.status_code} ---")
            print("Response:", response.text)
            
    except requests.exceptions.ConnectionError:
        print("--- ❌ CONNECTION FAILED ---")
        print("Please make sure your FastAPI server is running in another terminal.")

if __name__ == "__main__":
    test_api()