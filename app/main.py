import os
from fastapi import FastAPI
from fastapi.responses import JSONResponse

APP_VERSION = os.getenv("APP_VERSION", "local")
APP_ENV = os.getenv("APP_ENV", "development")
app = FastAPI(title="Cloud Run Platform Assessment", version=APP_VERSION)

@app.get("/health")
def health():
    return {"status": "ok"}

@app.get("/ready")
def ready():
    return {"status": "ready"}

@app.get("/version")
def version():
    return {"version": APP_VERSION, "environment": APP_ENV}

@app.get("/")
def root():
    return JSONResponse({"service": "cloudrun-platform-assessment", "status": "running"})
