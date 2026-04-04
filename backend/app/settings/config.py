import os
import typing
from pathlib import Path

from pydantic_settings import BaseSettings, SettingsConfigDict

_SETTINGS_DIR = Path(__file__).resolve().parent
_APP_DIR = _SETTINGS_DIR.parent
_BACKEND_DIR = _APP_DIR.parent
_PROJECT_DIR = _BACKEND_DIR.parent


class Settings(BaseSettings):
    model_config = SettingsConfigDict(
        env_file=(
            _BACKEND_DIR / ".env",
            _PROJECT_DIR / ".env",
        ),
        env_file_encoding="utf-8",
        extra="ignore",
    )

    VERSION: str = "0.1.0"
    APP_TITLE: str = "拾光视频服务端"
    PROJECT_NAME: str = "拾光视频"
    APP_DESCRIPTION: str = "统一为 App、H5 与管理后台提供认证、创作、任务、模型、版本发布与运营能力的后端服务。"

    CORS_ORIGINS: typing.List = ["*"]
    CORS_ALLOW_CREDENTIALS: bool = True
    CORS_ALLOW_METHODS: typing.List = ["*"]
    CORS_ALLOW_HEADERS: typing.List = ["*"]

    DEBUG: bool = True

    PROJECT_ROOT: str = os.path.abspath(os.path.join(os.path.dirname(__file__), os.pardir))
    BASE_DIR: str = os.path.abspath(os.path.join(PROJECT_ROOT, os.pardir))
    LOGS_ROOT: str = os.path.join(BASE_DIR, "app/logs")
    MEDIA_ROOT: str = os.path.join(BASE_DIR, "media")
    RELEASE_PACKAGE_ROOT: str = str(_PROJECT_DIR / "file")
    SERVER_BASE_URL: str = "http://127.0.0.1:10099"
    PUBLIC_BASE_URL: str = "http://127.0.0.1:10099"
    RELEASE_PACKAGE_PUBLIC_BASE_URL: str = ""
    IMAGE_PROXY_UPLOAD_URL: str = "https://imageproxy.zhongzhuan.chat/api/upload"
    GENERATED_VIDEO_STORAGE_BACKEND: str = "local"
    GENERATED_VIDEO_KEEP_LOCAL_COPY: bool = False
    COS_SECRET_ID: str = ""
    COS_SECRET_KEY: str = ""
    COS_BUCKET: str = ""
    COS_REGION: str = ""
    COS_TOKEN: str = ""
    COS_SCHEME: str = "https"
    COS_ENDPOINT: str = ""
    COS_PUBLIC_DOMAIN: str = ""
    COS_OBJECT_ACL: str = "public-read"
    COS_VIDEO_KEY_PREFIX: str = "videos"
    COS_RELEASE_KEY_PREFIX: str = "file"
    SECRET_KEY: str = "change-me-in-env"
    REGISTER_INVITE_CODE: str = ""
    JWT_ALGORITHM: str = "HS256"
    JWT_ACCESS_TOKEN_EXPIRE_MINUTES: int = 60 * 24 * 7  # 7 day
    DB_ENGINE: str = "sqlite"
    DB_HOST: str = "127.0.0.1"
    DB_PORT: int = 3306
    DB_USER: str = "root"
    DB_PASSWORD: str = ""
    DB_NAME: str = "momenta"
    DB_CHARSET: str = "utf8mb4"
    DB_POOL_MINSIZE: int = 1
    DB_POOL_MAXSIZE: int = 5
    XFYUN_ASR_APP_ID: str = ""
    XFYUN_ASR_API_KEY: str = ""
    XFYUN_ASR_API_SECRET: str = ""
    XFYUN_ASR_DOMAIN: str = "slm"
    XFYUN_ASR_LANGUAGE: str = "zh_cn"
    XFYUN_ASR_ACCENT: str = "mandarin"
    XFYUN_ASR_EOS: int = 6000
    XFYUN_ASR_DWA: str = "wpgs"
    XFYUN_ASR_LTC: int = 1
    XFYUN_ASR_VINFO: int = 0
    XFYUN_ASR_RES_ID: str = ""
    XFYUN_ASR_DHW: str = ""
    XFYUN_ASR_SAMPLE_RATE: int = 16000
    XFYUN_ASR_MAX_SECONDS: int = 60
    DATETIME_FORMAT: str = "%Y-%m-%d %H:%M:%S"

    @property
    def TORTOISE_ORM(self) -> dict:
        db_engine = (self.DB_ENGINE or "sqlite").strip().lower()
        if db_engine == "mysql":
            connections = {
                "mysql": {
                    "engine": "tortoise.backends.mysql",
                    "credentials": {
                        "host": self.DB_HOST,
                        "port": self.DB_PORT,
                        "user": self.DB_USER,
                        "password": self.DB_PASSWORD,
                        "database": self.DB_NAME,
                        "charset": self.DB_CHARSET,
                        "minsize": self.DB_POOL_MINSIZE,
                        "maxsize": self.DB_POOL_MAXSIZE,
                    },
                },
            }
            default_connection = "mysql"
        else:
            connections = {
                "sqlite": {
                    "engine": "tortoise.backends.sqlite",
                    "credentials": {"file_path": f"{self.BASE_DIR}/db.sqlite3"},
                },
            }
            default_connection = "sqlite"

        return {
            "connections": connections,
            "apps": {
                "models": {
                    "models": ["app.models"],
                    "default_connection": default_connection,
                },
            },
            "use_tz": False,
            "timezone": "Asia/Shanghai",
        }


settings = Settings()
