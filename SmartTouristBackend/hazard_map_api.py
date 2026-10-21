"""GeoJSON export for local-development hazard reports.

Reports are unverified user submissions. Do not expose publicly without
administrator authentication, moderation, and explicit test-data separation.
"""
from contextlib import closing
from fastapi import APIRouter, Query
from hazard_api import connect, initialize_database

router = APIRouter(prefix="/api/hazards", tags=["Hazard Map"])


@router.get("/geojson")
def hazard_geojson(include_test: bool = Query(default=False)):
    """Return active, unverified reports as GeoJSON points."""
    initialize_database()
    sql = """SELECT id, hazard_type, latitude, longitude, severity,
                    description, status, created_at
             FROM hazard_reports WHERE status = 'active'"""
    params = []
    if not include_test:
        sql += " AND UPPER(description) NOT LIKE ?"
        params.append("%TEST DATA%")
    sql += " ORDER BY id DESC"
    with closing(connect()) as connection:
        rows = connection.execute(sql, params).fetchall()

    features = []
    for row in rows:
        features.append({
            "type": "Feature",
            "geometry": {
                "type": "Point",
                "coordinates": [row["longitude"], row["latitude"]],
            },
            "properties": {
                "hazard_id": row["id"],
                "hazard_type": row["hazard_type"],
                "severity": row["severity"],
                "description": row["description"],
                "status": row["status"],
                "created_at": row["created_at"],
                "verification_status": "unverified",
            },
        })
    return {"type": "FeatureCollection", "features": features}
