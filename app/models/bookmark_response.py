from pydantic import BaseModel

class BookmarkResponse(BaseModel):
    status: str
    browser: str
    profilesProcessed: int
    bookmarksAdded: int
    bookmarksSkipped: int
    dryRun: bool
    message: str