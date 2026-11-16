"""Tests for the provider-bound identity model (no network calls)."""
import pytest
import sqlalchemy as sa
from unittest.mock import patch
from app import social_login
from app.db import auth_identities,users,profiles,engine,meta

@pytest.fixture
def separate_db():
    # Isolated sqlite schema to avoid accidental writes to configured production.
    local=sa.create_engine('sqlite+pysqlite:///:memory:')
    @sa.event.listens_for(local,'connect')
    def fk(conn,_): conn.execute('PRAGMA foreign_keys=ON')
    meta.create_all(local)
    try: yield local
    finally:local.dispose()

def test_provider_identity_stable(separate_db):
    with separate_db.begin() as c:
        one=social_login.find_or_create_user(c,'google','subject-a','Ana')
        same=social_login.find_or_create_user(c,'google','subject-a','Otro nombre')
        other=social_login.find_or_create_user(c,'facebook','subject-a','Ana')
        assert same==one
        assert other!=one
        assert c.scalar(sa.select(sa.func.count()).select_from(users))==2

def test_identity_cascade_on_user_delete(separate_db):
    with separate_db.begin() as c:
        user=social_login.find_or_create_user(c,'google','subject-b','Ana')
        c.execute(users.delete().where(users.c.id==user))
        assert c.scalar(sa.select(sa.func.count()).select_from(auth_identities))==0
        assert c.scalar(sa.select(sa.func.count()).select_from(profiles))==0

def test_unknown_provider_is_not_enabled():
    assert social_login.configured('other') is False

def test_google_login_off_without_config(monkeypatch):
    monkeypatch.delenv('GOOGLE_WEB_CLIENT_ID',raising=False)
    assert social_login.configured('google') is False

def test_email_otp_hmac(monkeypatch):
    monkeypatch.setenv('AUTH_CODE_PEPPER','z'*40)
    a=social_login.email_digest('a@example.com','12345678')
    assert a==social_login.email_digest('a@example.com','12345678')
    assert a!=social_login.email_digest('a@example.com','87654321')
    assert a!=social_login.email_digest('b@example.com','12345678')
