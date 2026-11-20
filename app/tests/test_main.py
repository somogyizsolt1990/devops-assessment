import pytest
from fastapi.testclient import TestClient

import main


@pytest.fixture
def client():
    main._config.clear()
    return TestClient(main.app)


def test_health(client):
    r = client.get("/health")
    assert r.status_code == 200
    assert r.json() == {"status": "ok"}


def test_version(client):
    r = client.get("/version")
    assert r.status_code == 200
    assert r.json() == {"version": "1.0.0"}


def test_env_from_variable(client, monkeypatch):
    monkeypatch.setenv("ENVIRONMENT", "dev")
    assert client.get("/env").json() == {"environment": "dev"}


def test_env_default_when_unset(client, monkeypatch):
    monkeypatch.delenv("ENVIRONMENT", raising=False)
    assert client.get("/env").json() == {"environment": "unknown"}


def test_config_lifecycle(client):
    item = {"name": "database_url", "value": "postgres://example"}

    r = client.post("/config", json=item)
    assert r.status_code == 201
    assert r.json() == item

    r = client.get("/config/database_url")
    assert r.status_code == 200
    assert r.json() == item

    r = client.delete("/config/database_url")
    assert r.status_code == 200
    assert r.json() == {"deleted": True}

    assert client.get("/config/database_url").status_code == 404


def test_config_overwrite_returns_200(client):
    client.post("/config", json={"name": "k", "value": "v1"})
    r = client.post("/config", json={"name": "k", "value": "v2"})
    assert r.status_code == 200
    assert client.get("/config/k").json() == {"name": "k", "value": "v2"}


def test_get_missing_returns_404(client):
    assert client.get("/config/missing").status_code == 404


def test_delete_is_idempotent(client):
    r = client.delete("/config/missing")
    assert r.status_code == 200
    assert r.json() == {"deleted": False}


@pytest.mark.parametrize("name", ["", "a/b", "has space", "x" * 129])
def test_invalid_name_rejected(client, name):
    assert client.post("/config", json={"name": name, "value": "v"}).status_code == 422


@pytest.mark.parametrize("body", [{"name": "k"}, {"value": "v"}, {"name": "k", "value": 1}])
def test_invalid_body_rejected(client, body):
    assert client.post("/config", json=body).status_code == 422
