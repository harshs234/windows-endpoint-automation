from fastapi import APIRouter, Depends, HTTPException

from app.models.bookmark_models import BookmarkRequest
from app.models.bookmark_response import BookmarkResponse

from app.security.auth import verify_api_key
from app.services.powershell_services import run_json_script

router = APIRouter()


@router.post(
    "/browser/bookmarks",
    tags=["Bookmarks"],
    summary="Import Browser Bookmarks",
    description="Imports predefined bookmarks into Chrome, Edge, or both browsers.",
    response_model=BookmarkResponse
)
def import_bookmarks(
    request: BookmarkRequest,
    _: str = Depends(verify_api_key)
):
    try:

        args = [
            "-Browser", request.browser
        ]

        if request.close_browser:
            args.append("-CloseBrowser")

        if request.dry_run:
            args.append("-DryRun")

        ps_result = run_json_script(
            "Add-BrowserBookmarks.ps1",
            args
        )

        return BookmarkResponse(
            status=ps_result["Status"],
            browser=ps_result["Browser"],
            profilesProcessed=ps_result["ProfilesProcessed"],
            bookmarksAdded=ps_result["BookmarksAdded"],
            bookmarksSkipped=ps_result["BookmarksSkipped"],
            dryRun=ps_result["DryRun"],
            message=ps_result["Message"]
        )

    except Exception as e:
        raise HTTPException(
            status_code=500,
            detail=str(e)
        )