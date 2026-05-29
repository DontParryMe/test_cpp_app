#!/usr/bin/env bash

set -e

# =========================
# Проверка версии Python
# =========================
echo "===> Проверка версии Python (>= 3.10.12)"

PYTHON=python3

$PYTHON - << 'EOF'
import sys

# минимально допустимая версия
min_version = (3, 10, 12)

# текущая версия интерпретатора
current = sys.version_info[:3]

print(f"[INFO] Обнаружен Python: {current[0]}.{current[1]}.{current[2]}")

# строгая проверка совместимости
if current < min_version:
    raise SystemExit(
        f"Требуется Python >= 3.10.12, найден {current[0]}.{current[1]}.{current[2]}"
    )
EOF

echo "===> Python версия подходит"

# =========================
# Установка системных зависимостей
# =========================
echo "===> Обновление пакетов системы"
sudo apt update

echo "===> Установка зависимостей"
sudo apt install -y \
    build-essential \
    cmake \
    pkg-config \
    libboost-system-dev \
    libgrpc++-dev \
    libprotobuf-dev \
    protobuf-compiler \
    protobuf-compiler-grpc

# =========================
# Сборка C++ проекта
# =========================
echo "===> Создание директории сборки"
mkdir -p build

echo "===> Запуск CMake"
cd build
cmake ../cpp-application

echo "===> Сборка проекта"
cmake --build . -j"$(nproc)"
cd ..

# =========================
# Python окружение для тестов
# =========================
echo "===> Создание виртуального окружения Python"

python3 -m venv tests/.venv
source tests/.venv/bin/activate

echo "===> Установка Python зависимостей"

pip install --upgrade pip

pip install \
    grpcio \
    grpcio-tools \
    pytest \
    protobuf \
    pydantic \
    pydantic-settings

# =========================
# Генерация gRPC stubs
# =========================
cd cpp-application

echo "===> Генерация gRPC кода из proto"

python3 -m grpc_tools.protoc \
    -I. \
    --python_out=. \
    --grpc_python_out=. \
    monitor.proto

echo "===> Перенос сгенерированных файлов в тесты"

mv -f monitor_pb2.py ../tests
mv -f monitor_pb2_grpc.py ../tests

cd ..

echo "===> Сборка и подготовка окружения завершены успешно"
