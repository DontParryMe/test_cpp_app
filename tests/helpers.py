import time
import tests.monitor_pb2 as pb2
from dataclasses import dataclass


@dataclass
class StatsSnapshot:
    """
    Снимок статистики UDP-сервиса в конкретный момент времени.
    Используется для удобного сравнения состояния между вызовами.
    """
    packets: int
    aBytes: int


def get_stats(stub) -> StatsSnapshot:
    """
    Получает текущую статистику из gRPC сервиса
    и приводит их к удобной структурированной форме.
    """
    resp = stub.GetUdpStatistics(pb2.Empty())

    return StatsSnapshot(
        packets=int(resp.packets),
        aBytes=int(resp.aBytes),
    )


def wait_for_stable_stats(
    stub,
    stable_rounds: int = 3,
    timeout: float = 5.0,
    interval: float = 0.05,
) -> StatsSnapshot:
    """
    Ожидает стабилизации сервиса.

    Считаем, что состояние стабильно, если оно не меняется
    stable_rounds последовательных проверок подряд.

    Это важно, потому что UDP обработка асинхронная.
    """

    last = None
    stable_count = 0
    deadline = time.time() + timeout

    while time.time() < deadline:
        current = get_stats(stub)

        # Если состояние не изменилось — увеличиваем счётчик стабильности
        if current == last:
            stable_count += 1
        else:
            # Если изменилось — сбрасываем счётчик
            stable_count = 0
            last = current

        # Достаточно стабильных наблюдений → считаем систему "устаканившейся"
        if stable_count >= stable_rounds:
            return current

        time.sleep(interval)

    raise TimeoutError("Stats did not stabilize within timeout")


def assert_stats(final, before, packets_delta: int, a_bytes_delta: int):
    """
    Унифицированная проверка изменения счётчиков.
    """
    assert final.packets == before.packets + packets_delta
    assert final.aBytes == before.aBytes + a_bytes_delta
