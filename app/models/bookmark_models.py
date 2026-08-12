from typing import Literal
from pydantic import BaseModel

class BookmarkRequest(BaseModel):
    browser: Literal["Chrome", "Edge", "Both"] = "Both"
    close_browser: bool = True
    dry_run:  bool = False              