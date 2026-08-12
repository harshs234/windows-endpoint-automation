from fastapi import APIRouter
from app.services.powershell_services import run_json_script
from app.models.disk_response import DiskStatusResponse

router = APIRouter()


@router.get(
    "/disk/status",
    tags=["Disk"],
    summary="Get Disk Usage",
    description="Returns the current usage statistics of all fixed Windows drives.",
    response_model=list[DiskStatusResponse]
)
def get_disk_status():

    result = run_json_script("disk-check-api.ps1")

    return [
        DiskStatusResponse(
            drive=drive["Drive"],
            totalSpaceGB=drive["TotalGB"],
            usedSpaceGB=drive["UsedGB"],
            freeSpaceGB=drive["FreeGB"],
            percentUsed=round(100 - drive["FreePercent"], 1)
        )
        for drive in result
    ]