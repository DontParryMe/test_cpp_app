import grpc
import socket
import pytest
import tests.monitor_pb2 as pb2
import time

from tests.helpers import get_stats
from tests.config import settings


def wait_for_ready(stub):
    """
    Ожидает, пока сервис полностью инициализируется и начнёт
    обрабатывать UDP.
    """
    deadline = time.time() + settings.ready_timeout

    while time.time() < deadline:
        try:
            resp = stub.IsReady(pb2.Empty())

            # Проверяем именно флаг готовности
            if resp.is_ready:
                return True

        except Exception as e:
            # На старте сервис может временно не отвечать
            print("ERROR:", repr(e))

        time.sleep(0.5)

    raise TimeoutError("Service did not become ready")


@pytest.fixture(scope="session")
def grpc_stub():
    """
    gRPC клиент.

    Используется всеми тестами для получения статистики и проверки состояния сервиса.
    """
    import tests.monitor_pb2_grpc as pb2_grpc

    channel = grpc.insecure_channel(settings.grpc_addr)
    stub = pb2_grpc.MonitorServiceStub(channel)

    # Ждём готовности сервиса перед запуском тестов
    wait_for_ready(stub)

    return stub


@pytest.fixture
def udp_sender():
    """
    Утилита для отправки UDP датаграмм.

    Позволяет отправлять один или несколько одинаковых пакетов с задержкой.
    """
    sock = socket.socket(socket.AF_INET, socket.SOCK_DGRAM)

    def send(data: bytes, n: int = 1):
        for _ in range(n):
            sock.sendto(
                data,
                (settings.udp_host, settings.udp_port),
            )

            # Небольшая задержка снижает риск потери пакетов
            time.sleep(settings.udp_delay)

    yield send
    sock.close()


@pytest.fixture
def baseline_stats(grpc_stub):
    """
    Статистика до выполнения теста.

    Используется как точка отсчёта для проверки роста счётчиков.
    """
    return get_stats(grpc_stub)
