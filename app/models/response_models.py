from pydantic import BaseModel


class CleanupResponse(BaseModel):
    status: str
    computerName: str
    spaceRecoveredGB: float
    cleanupPerformed: bool
    lockedFiles: int
    message: str