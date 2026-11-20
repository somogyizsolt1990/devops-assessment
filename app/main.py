"""Small config service for the DevOps homework.

Config entries live in process memory: they are lost on restart and are not
shared between processes, so run a single uvicorn worker and a single replica.
"""

import os
from typing import Annotated

from fastapi import FastAPI, HTTPException, Path, Response, status
from pydantic import BaseModel, Field

APP_VERSION = os.getenv("APP_VERSION", "1.0.0")

# The name is also a URL path segment, so keep it to a safe character set.
NAME_PATTERN = r"^[A-Za-z0-9_.-]{1,128}$"

app = FastAPI(title="myapp", version=APP_VERSION)

# All handlers are async and run on one event loop, so no lock is needed.
_config: dict[str, str] = {}


class ConfigItem(BaseModel):
    name: str = Field(pattern=NAME_PATTERN)
    value: str


ConfigName = Annotated[str, Path(pattern=NAME_PATTERN)]


@app.get("/health")
async def health() -> dict[str, str]:
    return {"status": "ok"}


@app.get("/version")
async def version() -> dict[str, str]:
    return {"version": APP_VERSION}


@app.get("/env")
async def env() -> dict[str, str]:
    return {"environment": os.getenv("ENVIRONMENT", "unknown")}


@app.post("/config", response_model=ConfigItem)
async def set_config(item: ConfigItem, response: Response) -> ConfigItem:
    """Create or overwrite an entry: 201 when new, 200 when overwritten."""
    is_new = item.name not in _config
    _config[item.name] = item.value
    response.status_code = status.HTTP_201_CREATED if is_new else status.HTTP_200_OK
    return item


@app.get("/config/{name}", response_model=ConfigItem)
async def get_config(name: ConfigName) -> ConfigItem:
    if name not in _config:
        raise HTTPException(status_code=status.HTTP_404_NOT_FOUND, detail=f"config '{name}' not found")
    return ConfigItem(name=name, value=_config[name])


@app.delete("/config/{name}")
async def delete_config(name: ConfigName) -> dict[str, bool]:
    """Idempotent: deleting a missing entry is not an error, it reports deleted=false."""
    existed = _config.pop(name, None) is not None
    return {"deleted": existed}
