from pydantic import BaseModel
from typing import Literal

class CleanupRequest(BaseModel):
    cleanup_level: Literal["safe","standard"] = "safe"
    dry_run: bool = False
