from app.api.models import CastIn, CastOut, CastUpdate
from app.api.db import casts, database
from typing import List

async def add_cast(payload: CastIn):
    query = casts.insert().values(**payload.dict())
    return await database.execute(query=query)

async def get_cast(id: int):
    query = casts.select().where(casts.c.id == id)
    result = await database.fetch_one(query)
    return dict(result) if result else None

async def get_all_casts() -> List[CastOut]:
    query = casts.select()
    results = await database.fetch_all(query)
    return [dict(row) for row in results]