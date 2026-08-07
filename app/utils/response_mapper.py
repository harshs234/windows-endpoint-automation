from app.models.response_models import CleanupResponse


def map_cleanup_response(ps_result: dict) -> CleanupResponse:

    recovered = float(ps_result.get("RecoveredGB", 0))
    errors = ps_result.get("Errors", [])

    return CleanupResponse(
        status="success",
        computerName=ps_result.get("ComputerName", ""),
        spaceRecoveredGB=recovered,
        cleanupPerformed=recovered > 0,
        lockedFiles=len(errors),
        message=(
            "Disk cleanup completed successfully."
            if recovered > 0
            else "Cleanup completed. No additional space was recovered."
        ),
    )

def map_preview_response(ps_result: dict) -> CleanupResponse:
    return CleanupResponse(
        status="preview",
        computerName=ps_result.get("ComputerName", ""),
        spaceRecoveredGB=0.0,
        cleanupPerformed=False,
        lockedFiles=0,
        message=ps_result.get("Message", "Preview only. No files were deleted."),
    )