from pydantic import BaseModel, Field

class HealthResponse(BaseModel):
    status: str = Field(
        description="The current status of the API",
        example=["online"]
    )
    version: str = Field(
        description="The current version of the API",
        example=["1.1.0"]
    )