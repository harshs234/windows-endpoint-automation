from pydantic import BaseModel, Field

class DiskStatusResponse(BaseModel):
    drive: str = Field(
        description="Drive being inspected",
        examples=["C:"]
    )
    totalSpaceGB: float = Field(
        description="Total drive capacity in GB",
        examples=[237.0]
    )
    usedSpaceGB: float = Field(
        description="Used disk space in GB",
        examples=[181.5]
    )
    freeSpaceGB: float = Field(
        description="Available disk space in GB",
        examples=[55.5]
    )
    percentUsed: float = Field(
        description="Percentage of disk currently used",
        examples=[76.6]
    )