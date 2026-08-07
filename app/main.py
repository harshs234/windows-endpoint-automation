from fastapi import FastAPI
from app.routes.health import router as health_router
from app.routes.disk import router as disk_router
from app.routes.cleanup import router as cleanup_router
app = FastAPI(
    title="Windows Endpoint Automation API",
    description="REST API for secure Windows endpoint maintenance and automation using PowerShell.",
    version="1.1.0"
)

app.include_router(health_router)
app.include_router(disk_router)
app.include_router(cleanup_router)