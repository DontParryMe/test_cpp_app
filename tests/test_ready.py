import tests.monitor_pb2 as pb2


def test_service_ready(grpc_stub):
    """
    Проверяет, что сервис успешно запущен и готов к обработке запросов.

    Тест обращается к gRPC методу IsReady и ожидает, что сервис
    вернёт признак готовности (is_ready = True).
    """

    # Запрос состояния готовности сервиса
    resp = grpc_stub.IsReady(pb2.Empty())

    # Проверяем, что сервис действительно инициализирован
    assert resp.is_ready is True
