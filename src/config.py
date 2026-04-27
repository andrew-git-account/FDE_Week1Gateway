"""
Configuration management for FNOL Claims Processing Agent.
Loads settings from .env file and provides typed configuration objects.
"""

from pydantic_settings import BaseSettings
from pydantic import Field
from typing import Literal


class Settings(BaseSettings):
    """Application settings loaded from environment variables."""

    # Database Configuration
    db_host: str = Field(default="localhost", alias="DB_HOST")
    db_port: int = Field(default=3306, alias="DB_PORT")
    db_name: str = Field(default="fnol_claims", alias="DB_NAME")
    db_user: str = Field(default="fnol_user", alias="DB_USER")
    db_password: str = Field(default="", alias="DB_PASSWORD")

    # CRM API Configuration
    crm_api_base_url: str = Field(alias="CRM_API_BASE_URL")
    crm_api_token: str = Field(default="", alias="CRM_API_TOKEN")
    crm_api_timeout: int = Field(default=5, alias="CRM_API_TIMEOUT")

    # Policy SOAP API Configuration
    policy_soap_url: str = Field(alias="POLICY_SOAP_URL")
    policy_soap_username: str = Field(default="", alias="POLICY_SOAP_USERNAME")
    policy_soap_password: str = Field(default="", alias="POLICY_SOAP_PASSWORD")
    policy_soap_timeout: int = Field(default=8, alias="POLICY_SOAP_TIMEOUT")

    # Notification Service Configuration
    notification_api_base_url: str = Field(alias="NOTIFICATION_API_BASE_URL")
    notification_api_token: str = Field(default="", alias="NOTIFICATION_API_TOKEN")
    notification_api_timeout: int = Field(default=5, alias="NOTIFICATION_API_TIMEOUT")

    # DMS Configuration
    dms_api_base_url: str = Field(alias="DMS_API_BASE_URL")
    dms_api_key: str = Field(default="", alias="DMS_API_KEY")
    dms_api_timeout: int = Field(default=10, alias="DMS_API_TIMEOUT")

    # NLP Configuration
    nlp_provider: Literal["openai", "azure_openai", "claude", "local", "mock"] = Field(
        default="openai", alias="NLP_PROVIDER"
    )
    openai_api_key: str = Field(default="", alias="OPENAI_API_KEY")
    openai_model: str = Field(default="gpt-4-turbo-preview", alias="OPENAI_MODEL")
    openai_temperature: float = Field(default=0.1, alias="OPENAI_TEMPERATURE")

    # Application Configuration
    app_env: Literal["development", "staging", "production", "test"] = Field(
        default="development", alias="APP_ENV"
    )
    log_level: str = Field(default="INFO", alias="LOG_LEVEL")
    debug_mode: bool = Field(default=True, alias="DEBUG_MODE")

    # Agent Behavior Configuration
    extraction_confidence_threshold: float = Field(
        default=0.7, alias="EXTRACTION_CONFIDENCE_THRESHOLD"
    )
    routing_confidence_threshold: float = Field(
        default=0.8, alias="ROUTING_CONFIDENCE_THRESHOLD"
    )
    severity_thresholds_low: int = Field(
        default=5000, alias="SEVERITY_THRESHOLDS_LOW"
    )
    severity_thresholds_high: int = Field(
        default=50000, alias="SEVERITY_THRESHOLDS_HIGH"
    )
    severity_thresholds_critical: int = Field(
        default=100000, alias="SEVERITY_THRESHOLDS_CRITICAL"
    )

    # Integration Configuration
    enable_mock_integrations: bool = Field(
        default=True, alias="ENABLE_MOCK_INTEGRATIONS"
    )
    mock_crm_api: bool = Field(default=True, alias="MOCK_CRM_API")
    mock_policy_soap: bool = Field(default=True, alias="MOCK_POLICY_SOAP")
    mock_notification_api: bool = Field(default=True, alias="MOCK_NOTIFICATION_API")
    mock_dms_api: bool = Field(default=True, alias="MOCK_DMS_API")

    # Monitoring Configuration
    enable_metrics: bool = Field(default=True, alias="ENABLE_METRICS")
    metrics_port: int = Field(default=9090, alias="METRICS_PORT")
    alert_email: str = Field(default="ops-team@company.com", alias="ALERT_EMAIL")

    # Cache Configuration
    enable_policy_cache: bool = Field(default=True, alias="ENABLE_POLICY_CACHE")
    policy_cache_ttl_seconds: int = Field(
        default=3600, alias="POLICY_CACHE_TTL_SECONDS"
    )

    @property
    def database_url(self) -> str:
        """Construct database connection URL."""
        return f"mysql+pymysql://{self.db_user}:{self.db_password}@{self.db_host}:{self.db_port}/{self.db_name}"

    class Config:
        env_file = ".env"
        env_file_encoding = "utf-8"
        case_sensitive = False


# Global settings instance
settings = Settings()
