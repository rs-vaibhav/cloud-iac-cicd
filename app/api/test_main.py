import os

os.environ["DATABASE_URL"] = "sqlite:///./test_notes.db"

from fastapi.testclient import TestClient  # noqa: E402

from main import app  # noqa: E402


def test_health_and_crud():
    with TestClient(app) as c:
        assert c.get("/healthz").json()["status"] == "ok"
        assert c.get("/readyz").status_code == 200

        r = c.post("/api/notes", json={"title": "deploy checklist", "body": "plan, review, apply"})
        assert r.status_code == 201
        nid = r.json()["id"]
        assert any(n["id"] == nid for n in c.get("/api/notes").json())

        assert c.post("/api/notes", json={"title": ""}).status_code == 422
        assert c.delete(f"/api/notes/{nid}").status_code == 204
        assert c.delete(f"/api/notes/{nid}").status_code == 404
