"""Notes API - the application tier of the 3-tier demo app.

DATABASE_URL is injected from Azure Key Vault through the Secrets Store CSI driver.
Falls back to SQLite for local development and tests.
"""
from __future__ import annotations

import logging
import os
import time
from contextlib import asynccontextmanager

from fastapi import Depends, FastAPI, HTTPException, Response
from pydantic import BaseModel, Field
from sqlalchemy import DateTime, String, Text, create_engine, func, select, text
from sqlalchemy.orm import DeclarativeBase, Mapped, Session, mapped_column, sessionmaker

DATABASE_URL = os.getenv("DATABASE_URL", "sqlite:///./notes.db")
if DATABASE_URL.startswith("postgresql://"):
    DATABASE_URL = DATABASE_URL.replace("postgresql://", "postgresql+psycopg://", 1)

engine = create_engine(DATABASE_URL, pool_pre_ping=True, pool_size=5, max_overflow=5) if "sqlite" not in DATABASE_URL \
    else create_engine(DATABASE_URL, connect_args={"check_same_thread": False})
SessionLocal = sessionmaker(bind=engine, expire_on_commit=False)
log = logging.getLogger("notes-api")
logging.basicConfig(level=os.getenv("LOG_LEVEL", "INFO"), format='{"level":"%(levelname)s","msg":"%(message)s"}')


class Base(DeclarativeBase):
    pass


class Note(Base):
    __tablename__ = "notes"
    id: Mapped[int] = mapped_column(primary_key=True)
    title: Mapped[str] = mapped_column(String(200))
    body: Mapped[str] = mapped_column(Text, default="")
    created_at: Mapped[object] = mapped_column(DateTime(timezone=True), server_default=func.now())


class NoteIn(BaseModel):
    title: str = Field(min_length=1, max_length=200)
    body: str = ""


class NoteOut(NoteIn):
    id: int


@asynccontextmanager
async def lifespan(_: FastAPI):
    for attempt in range(10):  # wait for the database during cold starts
        try:
            Base.metadata.create_all(engine)
            break
        except Exception as exc:  # pragma: no cover - only hit when DB is not ready
            log.warning("database not ready (attempt %s): %s", attempt + 1, exc)
            time.sleep(3)
    yield


app = FastAPI(title="Notes API", version=os.getenv("APP_VERSION", "dev"), lifespan=lifespan)


def db():
    with SessionLocal() as s:
        yield s


@app.get("/healthz")
def healthz():
    """Liveness: the process is up."""
    return {"status": "ok", "version": app.version}


@app.get("/readyz")
def readyz(response: Response, s: Session = Depends(db)):
    """Readiness: we can reach the database."""
    try:
        s.execute(text("SELECT 1"))
        return {"status": "ready"}
    except Exception:
        response.status_code = 503
        return {"status": "database unavailable"}


@app.get("/api/notes", response_model=list[NoteOut])
def list_notes(s: Session = Depends(db)):
    return s.scalars(select(Note).order_by(Note.id.desc()).limit(100)).all()


@app.post("/api/notes", response_model=NoteOut, status_code=201)
def create_note(note: NoteIn, s: Session = Depends(db)):
    n = Note(title=note.title, body=note.body)
    s.add(n)
    s.commit()
    return n


@app.delete("/api/notes/{note_id}", status_code=204)
def delete_note(note_id: int, s: Session = Depends(db)):
    n = s.get(Note, note_id)
    if not n:
        raise HTTPException(404, "note not found")
    s.delete(n)
    s.commit()
