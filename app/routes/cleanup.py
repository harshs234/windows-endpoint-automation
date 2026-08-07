from urllib import request

from fastapi import APIRouter, Depends, HTTPException

from app.models.cleanup_models import CleanupRequest
from app.models.response_models import CleanupResponse
from app.services.powershell_services import run_json_script
from app.security.auth import verify_api_key
from app.utils.response_mapper import map_cleanup_response, map_preview_response
from app.utils.logger import logger
from app.models.response_models import CleanupResponse


router = APIRouter()


@router.post(
    "/disk/cleanup",
    tags=["Cleanup"],
    summary="Run Windows Disk Cleanup",
    description="Executes or previews Windows temporary file cleanup using PowerShell.",
    response_model=CleanupResponse
)
def run_cleanup(
    request: CleanupRequest,
    _: str = Depends(verify_api_key)
):
    logger.info(f"Cleanup request received. Cleanup level: {request.cleanup_level}, Dry run: {request.dry_run}")
    try:
        if request.dry_run:
            ps_result = run_json_script("cleanup-preview.ps1")
            return map_preview_response(ps_result)

        ps_result = run_json_script("cleanup-api.ps1")
        logger.info(f"Cleanup completed successfully. Recovered {ps_result.get('RecoveredGB', 0)} GB.")
        return map_cleanup_response(ps_result)
        
    except Exception as e:
        logger.exception("Cleanup failed.")
        raise HTTPException(
            status_code=500,
            detail=str(e)
        )
        