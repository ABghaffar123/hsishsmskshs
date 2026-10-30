"""API-key authentication dependency for all routes."""
from fastapi import Header, HTTPException, Depends

from backend import config


def require_api_key(x_api_key: str = Header(None, alias="x-api-key")):
    if x_api_key is None or x_api_key != config.API_KEY:
        raise HTTPException(status_code=401, detail="Invalid or missing x-api-key")
    return {"authorized": True}


# Convenience: apply globally via a dependency-listing route
# Usage in routes: ``async def fn(_user: dict = Depends(require_api_key))``
