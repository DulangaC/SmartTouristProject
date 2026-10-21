"""SQLite-backed hazard reports for Smart Tourist prototype.

Administrator write operations require an API key. Prototype only.
"""
from contextlib import closing
from datetime import datetime, timezone
from pathlib import Path
import sqlite3
import os
import secrets

from fastapi import APIRouter, HTTPException, Query, Depends, Security
from fastapi.security import APIKeyHeader
from pydantic import BaseModel, Field

router = APIRouter(prefix="/api/hazards", tags=["Hazard Reports"])
DB_PATH = Path(__file__).resolve().parent / "hazard_ml" / "hazard_reports.db"
admin_key_header = APIKeyHeader(name="X-Admin-Key", auto_error=False)


def require_admin_key(provided_key: str | None = Security(admin_key_header)):
    expected_key = os.environ.get("HAZARD_ADMIN_API_KEY", "").strip()
    if not expected_key:
        key_file = Path(__file__).resolve().parent / ".hazard_admin_key"
        if key_file.is_file():
            expected_key = key_file.read_text(encoding="utf-8").strip()
    if not expected_key:
        raise HTTPException(status_code=503, detail="Administrator API key is not configured")
    if not provided_key or not secrets.compare_digest(provided_key, expected_key):
        raise HTTPException(status_code=401, detail="Invalid or missing administrator API key")



def connect():
    DB_PATH.parent.mkdir(parents=True, exist_ok=True)
    connection = sqlite3.connect(DB_PATH, timeout=10)
    connection.row_factory = sqlite3.Row
    return connection


def initialize_database():
    with closing(connect()) as connection:
        connection.execute("""
            CREATE TABLE IF NOT EXISTS hazard_reports (
                id INTEGER PRIMARY KEY AUTOINCREMENT,
                hazard_type TEXT NOT NULL,
                latitude REAL NOT NULL,
                longitude REAL NOT NULL,
                severity TEXT NOT NULL,
                description TEXT NOT NULL,
                status TEXT NOT NULL DEFAULT 'active',
                created_at TEXT NOT NULL,
                resolved_at TEXT
            )
        """)
        connection.commit()


class HazardReport(BaseModel):
    hazard_type: str = Field(min_length=2, max_length=80)
    latitude: float = Field(ge=-90, le=90)
    longitude: float = Field(ge=-180, le=180)
    severity: str = Field(pattern="^(Low|Medium|High)$")
    description: str = Field(min_length=3, max_length=1000)


@router.post("/report", status_code=201)
def report_hazard(report: HazardReport, _admin: None = Depends(require_admin_key)):
    initialize_database()
    timestamp = datetime.now(timezone.utc).isoformat()
    with closing(connect()) as connection:
        cursor = connection.execute("""
            INSERT INTO hazard_reports
                (hazard_type, latitude, longitude, severity, description, status, created_at)
            VALUES (?, ?, ?, ?, ?, 'active', ?)
        """, (report.hazard_type, report.latitude, report.longitude,
              report.severity, report.description, timestamp))
        connection.commit()
        report_id = cursor.lastrowid
    return {"status": "success", "hazard_id": report_id, "message": "Hazard report saved"}


@router.get("")
def get_hazards(active_only: bool = Query(default=True)):
    initialize_database()
    query = "SELECT * FROM hazard_reports"
    if active_only:
        query += " WHERE status = 'active'"
    query += " ORDER BY id DESC"
    with closing(connect()) as connection:
        rows = [dict(row) for row in connection.execute(query).fetchall()]
    return {"status": "success", "total": len(rows), "hazards": rows}


@router.patch("/{hazard_id}/resolve")
def resolve_hazard(hazard_id: int, _admin: None = Depends(require_admin_key)):
    initialize_database()
    timestamp = datetime.now(timezone.utc).isoformat()
    with closing(connect()) as connection:
        cursor = connection.execute("""
            UPDATE hazard_reports SET status = 'resolved', resolved_at = ?
            WHERE id = ? AND status = 'active'
        """, (timestamp, hazard_id))
        connection.commit()
        if cursor.rowcount == 0:
            raise HTTPException(status_code=404, detail="Active hazard not found")
    return {"status": "success", "hazard_id": hazard_id, "message": "Hazard resolved"}
