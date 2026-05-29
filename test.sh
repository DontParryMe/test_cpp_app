#!/usr/bin/env bash

# Останавливаем скрипт при любой ошибке
set -euo pipefail

SERVER="./build/grpc_udp_monitor"
GRPC_HOST="127.0.0.1"
GRPC_PORT="2031"

echo "[INFO] Starting server: $SERVER"

# Запускаем сервер в фоне
$SERVER &
SERVER_PID=$!

# Функция очистки: завершает сервер при выходе из скрипта
cleanup() {
  echo "[INFO] Stopping server (PID: $SERVER_PID)"
  kill $SERVER_PID 2>/dev/null || true
  wait $SERVER_PID 2>/dev/null || true
}

# Гарантируем выполнение cleanup при любом завершении скрипта
trap cleanup EXIT

echo "[INFO] Waiting for gRPC service at $GRPC_HOST:$GRPC_PORT ..."

# Ждём, пока сервис откроет TCP-порт gRPC
for i in {1..100}; do
  if (echo > /dev/tcp/$GRPC_HOST/$GRPC_PORT) >/dev/null 2>&1; then
    echo "[INFO] gRPC port is open"
    break
  fi
  sleep 0.1
done

# Финальная проверка: если порт так и не открылся — падаем
if ! (echo > /dev/tcp/$GRPC_HOST/$GRPC_PORT) >/dev/null 2>&1; then
  echo "[ERROR] gRPC service did not start in expected time"
  exit 1
fi

echo "[INFO] Running tests..."

# Активируем виртуальное окружение
source tests/.venv/bin/activate

# Запуск тестов
python3 -m pytest tests

echo "[INFO] Tests finished successfully"