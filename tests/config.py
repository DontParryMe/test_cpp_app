from pydantic import Field
from pydantic_settings import BaseSettings, SettingsConfigDict


class Settings(BaseSettings):
    """
    Конфигурация тестового окружения.

    Загружается из файла .env_example.
    """

    # Адрес gRPC сервиса к которому подключаются тесты
    grpc_addr: str = Field(default="127.0.0.1:2031")

    # UDP endpoint, куда отправляются датаграммы
    udp_host: str = Field(default="127.0.0.1")
    udp_port: int = Field(default=2032)

    # Таймаут ожидания готовности сервиса (IsReady)
    ready_timeout: float = Field(default=30.0)

    # Задержка между UDP отправками
    udp_delay: float = Field(default=0.001)

    model_config = SettingsConfigDict(
        # Путь к .env_example файлу относительно запуска pytest
        env_file="tests/.env_example",
        env_file_encoding="utf-8",

        # Игнорировать лишние переменные окружения
        extra="ignore",

        # Позволяет использовать переменные окружения без учёта регистра
        case_sensitive=False,
    )


# Singleton-конфиг, используемый во всём тестовом проекте
settings = Settings()