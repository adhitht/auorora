from pydantic import BaseModel
from typing import List, Optional, Union, Literal

class Geometry(BaseModel):
    type: Literal["LineString", "SingleLightSource"]
    coordinates: Optional[List[List[float]]] = None
    center: Optional[List[float]] = None
    radius: Optional[float] = None

class Properties(BaseModel):
    temperature: int
    color: str

class Light(BaseModel):
    geometry: Geometry
    properties: Properties

class LightsRequest(BaseModel):
    lights: List[Light]
