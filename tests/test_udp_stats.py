from tests.helpers import wait_for_stable_stats, assert_stats


def test_single_datagram(grpc_stub, udp_sender, baseline_stats):
    """
    Проверяет обработку одного UDP-пакета и корректное увеличение счётчиков.
    """
    before = baseline_stats

    udp_sender(b"ABC")

    final = wait_for_stable_stats(grpc_stub)

    assert_stats(final, before, packets_delta=1, a_bytes_delta=1)


def test_multiple_datagrams(grpc_stub, udp_sender, baseline_stats):
    """
    Проверяет корректную обработку нескольких UDP-пакетов разных типов.
    """
    before = baseline_stats

    udp_sender(b"A", n=10)
    udp_sender(b"BBB", n=5)

    final = wait_for_stable_stats(grpc_stub)

    assert_stats(final, before, packets_delta=15, a_bytes_delta=10)


def test_mixed_payload(grpc_stub, udp_sender, baseline_stats):
    """
    Проверяет корректный подсчёт символов 'A' в смешанном payload.
    """
    before = baseline_stats

    n = 3
    udp_sender(b"\x00\x01AAA\xffA", n=n)

    final = wait_for_stable_stats(grpc_stub)

    assert_stats(final, before, packets_delta=n, a_bytes_delta=4 * n)


def test_no_a_bytes(grpc_stub, udp_sender, baseline_stats):
    """
    Проверяет, что при отсутствии символов 'A' счётчик aBytes не изменяется.
    """
    before = baseline_stats

    udp_sender(b"BBBBBB", n=5)

    final = wait_for_stable_stats(grpc_stub)

    assert_stats(final, before, packets_delta=5, a_bytes_delta=0)


def test_only_a_bytes(grpc_stub, udp_sender, baseline_stats):
    """
    Проверяет случай, когда все байты являются символами 'A'.
    """
    before = baseline_stats

    udp_sender(b"A", n=10)

    final = wait_for_stable_stats(grpc_stub)

    assert_stats(final, before, packets_delta=10, a_bytes_delta=10)


def test_single_byte_packets(grpc_stub, udp_sender, baseline_stats):
    """
    Проверяет обработку одиночных байтовых UDP-пакетов.
    """
    before = baseline_stats

    udp_sender(b"A", n=1)
    udp_sender(b"B", n=1)
    udp_sender(b"A", n=1)

    final = wait_for_stable_stats(grpc_stub)

    assert_stats(final, before, packets_delta=3, a_bytes_delta=2)


def test_order_independence(grpc_stub, udp_sender, baseline_stats):
    """
    Проверяет, что порядок пакетов не влияет на результат подсчёта.
    """
    before = baseline_stats

    udp_sender(b"AAA", n=1)
    udp_sender(b"BBB", n=1)
    udp_sender(b"ABA", n=1)

    final = wait_for_stable_stats(grpc_stub)

    assert_stats(final, before, packets_delta=3, a_bytes_delta=5)
