from fastapi import APIRouter
from app.models.health_response import HealthResponse

router = APIRouter()

@router.get(
    "/health", 
    tags=["Health"],
    summary="Check API health status",
    description="Returns the health status of the window endpoint automation API.",
    response_model=HealthResponse,
)
def get_health():
    return HealthResponse(
        status="online",
        version="1.1.0"
    )