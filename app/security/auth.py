import os 

from dotenv import load_dotenv
from fastapi import Security, HTTPException
from fastapi.security import APIKeyHeader

load_dotenv()

API_KEY = os.getenv("API_KEY")

api_key_header = APIKeyHeader(
    name="X-API-KEY", 
    auto_error=False
)

def verify_api_key(api_key: str = Security(api_key_header)):
    if api_key != API_KEY:
        raise HTTPException(
            status_code=403, 
            detail="Invalid API Key"
        )
    return api_key