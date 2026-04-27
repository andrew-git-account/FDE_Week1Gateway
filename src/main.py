"""
FNOL Claims Processing Agent - Main Application Entry Point.

FastAPI application that processes first-notice-of-loss (FNOL) claims through
5 stages: extraction, triage, validation, routing, and acknowledgment.
"""

from fastapi import FastAPI
from fastapi.middleware.cors import CORSMiddleware
import structlog

from config import settings

# Configure structured logging
structlog.configure(
    processors=[
        structlog.processors.TimeStamper(fmt="iso"),
        structlog.processors.add_log_level,
        structlog.processors.JSONRenderer(),
    ],
    logger_factory=structlog.PrintLoggerFactory(),
)

logger = structlog.get_logger()

# Create FastAPI application
app = FastAPI(
    title="FNOL Claims Processing Agent",
    description="AI-powered automation for insurance claims intake, triage, and routing",
    version="1.0.0",
    docs_url="/docs",
    redoc_url="/redoc",
)

# CORS middleware (adjust origins for production)
app.add_middleware(
    CORSMiddleware,
    allow_origins=["*"] if settings.app_env == "development" else [],
    allow_credentials=True,
    allow_methods=["*"],
    allow_headers=["*"],
)


@app.on_event("startup")
async def startup_event():
    """Initialize application on startup."""
    logger.info(
        "fnol_agent_starting",
        env=settings.app_env,
        debug=settings.debug_mode,
        mock_integrations=settings.enable_mock_integrations,
    )


@app.on_event("shutdown")
async def shutdown_event():
    """Cleanup on shutdown."""
    logger.info("fnol_agent_stopping")


@app.get("/health")
async def health_check():
    """Health check endpoint."""
    return {
        "status": "healthy",
        "environment": settings.app_env,
        "mock_integrations": settings.enable_mock_integrations,
    }


@app.get("/")
async def root():
    """Root endpoint with API information."""
    return {
        "service": "FNOL Claims Processing Agent",
        "version": "1.0.0",
        "docs": "/docs",
        "health": "/health",
    }


# Import and include routers (will be created later)
# from api import claims, admin
# app.include_router(claims.router, prefix="/api/v1/claims", tags=["Claims"])
# app.include_router(admin.router, prefix="/api/v1/admin", tags=["Admin"])


if __name__ == "__main__":
    import uvicorn

    uvicorn.run(
        "main:app",
        host="0.0.0.0",
        port=8000,
        reload=settings.debug_mode,
        log_level=settings.log_level.lower(),
    )
