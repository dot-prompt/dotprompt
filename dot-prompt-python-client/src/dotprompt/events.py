"""Event model for SSE streaming."""

from pydantic import BaseModel


class Event(BaseModel):
    """Represents an event from the container SSE stream."""

    type: str
    prompt: str | None = None
    timestamp: float | None = None
    payload: dict | None = None
