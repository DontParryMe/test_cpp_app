#!/usr/bin/env bash

# Останавливаем скрипт при любой ошибке
set -euo pipefail

SERVER="./build/grpc_udp_monitor"
ENV_FILE="tests/.env"

# Очищаем переменные окружения от возможных проблем
unset GRPC_ADDR UDP_HOST UDP_PORT READY_TIMEOUT UDP_DELAY

# Загружаем переменные из .env файла простым способом
if [ -f "$ENV_FILE" ]; then
    echo "Загрузка переменных окружения из $ENV_FILE"

    # Удаляем возможные CR символы и читаем файл
    while IFS= read -r line || [ -n "$line" ]; do
        # Удаляем CR символы и пробелы по краям
        line=$(echo "$line" | tr -d '\r' | sed -e 's/^[[:space:]]*//' -e 's/[[:space:]]*$//')

        # Пропускаем комментарии и пустые строки
        [[ -z "$line" ]] && continue
        [[ "$line" =~ ^# ]] && continue

        # Экспортируем переменную
        export "$line"
        echo "  -> Загружено: ${line%%=*}"
    done < "$ENV_FILE"
else
    echo "Файл $ENV_FILE не найден!"
    exit 1
fi

# Проверяем и разбираем GRPC_ADDR
if [ -z "${GRPC_ADDR:-}" ]; then
    echo "Ошибка: GRPC_ADDR не задан в $ENV_FILE"
    exit 1
fi

# Разбираем GRPC_ADDR на HOST и PORT
GRPC_HOST=$(echo "$GRPC_ADDR" | cut -d ':' -f1)
GRPC_PORT=$(echo "$GRPC_ADDR" | cut -d ':' -f2)

echo "GRPC_ADDR='$GRPC_ADDR'"
echo "GRPC_HOST='$GRPC_HOST'"
echo "GRPC_PORT='$GRPC_PORT'"

# Устанавливаем значения по умолчанию для UDP, если не заданы
UDP_HOST="${UDP_HOST:-127.0.0.1}"
UDP_PORT="${UDP_PORT:-2032}"

echo "UDP_HOST='$UDP_HOST'"
echo "UDP_PORT='$UDP_PORT'"

echo "Запуск сервера: $SERVER"
echo "gRPC адрес: $GRPC_ADDR"
echo "UDP адрес: $UDP_HOST:$UDP_PORT"

# Запускаем сервер в фоне
$SERVER &
SERVER_PID=$!

# Функция очистки: завершает сервер при выходе из скрипта
cleanup() {
  echo "Остановка сервера (PID: $SERVER_PID)"
  kill $SERVER_PID 2>/dev/null || true
  wait $SERVER_PID 2>/dev/null || true
}

# Гарантируем выполнение cleanup при любом завершении скрипта
trap cleanup EXIT

echo "Ожидание сервера $GRPC_HOST:$GRPC_PORT ..."

# Ждём, пока сервис откроет TCP-порт gRPC
MAX_RETRIES=5
for i in $(seq 1 $MAX_RETRIES); do
    # Используем nc (netcat) если доступен, иначе bash tcp
    if command -v nc &> /dev/null; then
        if nc -z "$GRPC_HOST" "$GRPC_PORT" 2>/dev/null; then
            echo "gRPC порт открыт (попытка $i)"
            break
        fi
    else
        if (echo > /dev/tcp/$GRPC_HOST/$GRPC_PORT) 2>/dev/null; then
            echo "gRPC порт открыт (попытка $i)"
            break
        fi
    fi

    if [ $i -eq $MAX_RETRIES ]; then
        echo "gRPC сервер не поднялся за отведенное время"
        exit 1
    fi
    sleep 0.2
done

# Дополнительная задержка для полной инициализации gRPC сервера
sleep 0.5

echo "Запуск тестов"

# Активируем виртуальное окружение
source tests/.venv/bin/activate

# Запуск тестов с отключением кэша (убираем warning)
python3 -m pytest tests -v -p no:cacheprovider

echo "Тесты прошли успешно"
