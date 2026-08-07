from fastapi import APIRouter
from app.services.powershell_services import run_json_script, run_script
from app.models.disk_response import DiskStatusResponse

router = APIRouter()

@router.get(
    "/disk/status",
    tags=["Disk"],
    summary="Get Disk Usage",
    description="Returns the current usage statistics of the Windows system drive.",
    response_model=DiskStatusResponse
)
def get_disk_status():

    result = run_json_script("disk-check-api.ps1")

    # Find the system drive
    system_drive = next(
        (drive for drive in result if drive["IsSystemDrive"]),
        result[0]
    )

    return DiskStatusResponse(
        drive=system_drive["Drive"],
        totalSpaceGB=system_drive["TotalGB"],
        usedSpaceGB=system_drive["UsedGB"],
        freeSpaceGB=system_drive["FreeGB"],
        percentUsed=100 - system_drive["FreePercent"]
    )