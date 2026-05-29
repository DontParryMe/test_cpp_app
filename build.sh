#!/usr/bin/env bash

# Проверка версии python3, если нет 3.10.12 сразу падаем (Наличие python именно 3.10.12 полностью гарантирует совместимость тестов)
PYTHON=$(which python3.10.12 || true)

if [ -z "$PYTHON" ]; then
  echo "Python 3.10.12 not found"
  exit 1
fi

# Останавливаем выполнение при любой ошибке
set -e

echo "===> Updating packages"

# Обновляем список пакетов системы
sudo apt update

echo "===> Installing dependencies"

# Устанавливаем системные зависимости:
# - build-essential: компилятор и базовые инструменты сборки
# - cmake: система сборки C++
# - grpc/protobuf: для генерации и работы с gRPC сервисом
# - boost: может использоваться в C++ проекте
sudo apt install -y \
    build-essential \
    cmake \
    pkg-config \
    libboost-system-dev \
    libgrpc++-dev \
    libprotobuf-dev \
    protobuf-compiler \
    protobuf-compiler-grpc

echo "===> Creating build directory"

# Отдельная директория для сборки
mkdir -p build

echo "===> Running CMake"

cd build

# Генерация make файлов проекта
cmake ../cpp-application

echo "===> Building project"

# Компиляция проекта с использованием всех ядер CPU
cmake --build . -j"$(nproc)"

echo "===> Build completed"

cd ..

echo "===> Creating Python virtual environment"

# Виртуальное окружение для тестов
python3 -m venv tests/.venv

# Активация окружения для установки зависимостей
source tests/.venv/bin/activate

echo "===> Installing Python dependencies"

# Python зависимости:
# - grpcio: gRPC клиент
# - pytest: тестовый фреймворк
# - protobuf: работа с proto-моделями
# - pydantic: конфигурирование тестового окружения
pip install grpcio grpcio-tools pytest protobuf pydantic pydantic-settings

cd cpp-application

echo "===> Generating gRPC stubs from proto"

# Генерация Python-кода из protobuf описания:
# - monitor_pb2.py: модели сообщений
# - monitor_pb2_grpc.py: gRPC клиентский stub
$PYTHON -m grpc_tools.protoc \
    -I. \
    --python_out=. \
    --grpc_python_out=. \
    monitor.proto

echo "===> Moving generated stubs into tests package"

# Перенос сгенерированных файлов в тестовый проект
mv -f monitor_pb2.py ../tests
mv -f monitor_pb2_grpc.py ../tests

echo "===> Build and test environment ready"