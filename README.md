

# Инструкция по запуску и использованию vPIC-dl на Ubuntu

> Оригинальный репозиторий: [samsullivandelgobbo/vPIC-dl](https://github.com/samsullivandelgobbo/vPIC-dl)

Этот форк создан с целью исправления ошибок и доработки инструкции для корректного запуска на Ubuntu.


Пошаговый план действий для запуска и использования репозитория Angpeu/vPIC-dl на сервере с Ubuntu, если Docker и Python уже установлены:

## 1. Клонируй репозиторий

```bash
git clone https://github.com/Angpeu/vPIC-dl.git
cd vPIC-dl
```


## 2. Подготовка Ubuntu для работы с vPIC-dl


### 2.1. Установи необходимые системные пакеты и зависимости

```bash
sudo apt-get update
sudo apt-get install -y python3 python3-venv python3-pip make curl apt-transport-https unixodbc unixodbc-dev
```

#### 2.1.1. Сделай алиас для python (если нужно)
```bash
sudo ln -s /usr/bin/python3 /usr/bin/python
```
или установи python-is-python3 (рекомендуется для Ubuntu 20.04+):
```bash
sudo apt install python-is-python3
```

#### 2.1.2. Установи make (если не установлен)
```bash
sudo apt install make
```



#### 2.1.3. Установи драйверы MS ODBC и инструменты для MS SQL Server
```bash
# Добавляем репозиторий Microsoft 
curl https://packages.microsoft.com/keys/microsoft.asc | sudo apt-key add -
echo "deb [arch=amd64] https://packages.microsoft.com/ubuntu/22.04/prod jammy main" | sudo tee /etc/apt/sources.list.d/mssql-release.list
sudo apt-get update
sudo ACCEPT_EULA=Y apt-get install -y msodbcsql18 mssql-tools18
odbcinst -q -d -n "ODBC Driver 18 for SQL Server"
export PATH="$PATH:/opt/mssql-tools18/bin"
```

Чтобы путь был постоянным, добавь строку выше в ~/.bashrc:
```bash
echo 'export PATH="$PATH:/opt/mssql-tools18/bin"' >> ~/.bashrc
source ~/.bashrc
```



#### 2.2. Исправь права temp_data
Если папки нет — создай её:
```bash
mkdir -p temp_data
sudo chown -R $USER:$USER temp_data
chmod u+rwx temp_data
```

#### 2.3. Сделай исполняемым restore_backup.sh
```bash
chmod +x ./scripts/restore_backup.sh
```

## 3. Запуск проекта vPIC-dl

### 3.1. Установи зависимости Python (в отдельное виртуальное окружение)

```bash
python3 -m venv .venv
source .venv/bin/activate
pip install -r requirements.txt
```



### 3.2. Запусти Docker-контейнеры для MS SQL и PostgreSQL

> **Важно:** Postgre будет запущен на стандартном порту 5432, MS SQL на 1433. Нужно остановить существующие сервисы, которые могут использовать эти порты.

```bash
make start-containers
```
(Если нет команды make — установи её: `sudo apt install make`)

---

### 3.3. Запусти миграционный процесс (всё одной командой)

```bash
make all
```

Это скачает свежий дамп базы, восстановит его в MS SQL, мигрирует данные в PostgreSQL и SQLite, и проведёт проверку.

---

### 3.4. После завершения

- Данные будут доступны **/temp_data/**

---
#### Экспорт данных из SQLite в SQL-дамп (если нужно)


```bash
.venv/bin/python -c "import sqlite3; conn = sqlite3.connect('temp_data/vpic.db'); print(''.join(conn.iterdump()))" > temp_data/vpic_sqlite_dump.sql
```


### 3.5. Дополнительные команды

Ниже список основных команд Makefile, которые можно выполнять по отдельности:

- `make clean` — очистить окружение, удалить контейнеры, виртуальное окружение и временные файлы.
- `make setup` — создать виртуальное окружение Python и установить зависимости.
- `make install` — установить пакет в режиме разработки (после setup).
- `make start-containers` — запустить Docker-контейнеры для MS SQL и PostgreSQL.
- `make download` — скачать свежие данные vPIC.
- `make restore` — восстановить бэкап в MS SQL и проверить базу.
- `make migrate-pg` — миграция данных из MS SQL в PostgreSQL.
- `make migrate-sqlite` — миграция данных из MS SQL в SQLite.
- `make verify-pg` — проверить корректность миграции (вывести таблицы в обеих базах).
- `make test` — запустить тесты.
- `make backup` — создать резервную копию базы PostgreSQL: формирует три файла в папке temp_data — дамп только схемы, только данных и полный бинарный дамп. Имя файлов содержит текущую дату и время. Эта команда просто вызывает export-pg.
- `make export-pg` — непосредственно выполняет экспорт базы PostgreSQL в temp_data (дамп схемы, дамп данных, полный дамп). Обычно используется внутри backup, но можно вызывать отдельно.

Выполняй нужные этапы по отдельности, если не требуется полный процесс (`make all`).


## 3. Остановка и удаление контейнеров (при необходимости)

```bash
docker-compose -f docker/docker-compose.yml down -v
```

---

# Original README.md content":
# vPIC Database Migration Tool

A robust tool for downloading, migrating, and managing the NHTSA's Vehicle Product Information Catalog (vPIC) database across different database platforms (SQL Server, PostgreSQL, and SQLite).

[![License: MIT](https://img.shields.io/badge/License-MIT-yellow.svg)](https://opensource.org/licenses/MIT)

## Overview

This tool facilitates the migration of the NHTSA's vPIC database, which contains comprehensive vehicle specification data, including:
- Vehicle Makes, Models, and Types
- Manufacturer Information
- Vehicle Specifications and Features
- WMI (World Manufacturer Identifier) Data
- VIN Decoder implementation

## Features

- 🚀 Automated download of the latest vPIC database backup
- 🔄 Migration support for multiple database platforms:
  - Microsoft SQL Server
  - PostgreSQL
  - SQLite
- ✅ Data integrity verification
- 📊 Progress tracking with detailed logging
- 🔧 Configurable settings and type mappings
- 🐳 Docker support for easy deployment

## Prerequisites

- Python 3.8 or higher
- Docker and Docker Compose
- Make (optional, but recommended)


## Quick Start

1. Clone the repository:
```
   git clone https://github.com/samsullivandelgobbo/vPIC-dl.git
   cd vpic-migration
```
2. Install dependencies:
   # On macOS
```
   ./install_deps.sh
```
   # On Windows / Linux
```
   python -m venv .venv
   .venv\Scripts\activate
   pip install -r requirements.txt
```

3. Start the containers:
```
   make start-containers
```

4. Run the migration:
```
  make download
   make restore
   make migrate-pg
   make migrate-sqlite
   make verify-pg
   make backup
```

   or
```
   make all
```
## Usage

### Basic Usage

The simplest way to use the tool is through the provided Makefile commands:

# Run all steps
```
make all
```
# Download latest vPIC data
```
make download
```
# Restore SQL Server backup
```
make restore
```
# Migrate to PostgreSQL
```
make migrate-pg
```
# Migrate to SQLite
```
make migrate-sqlite
```
# Verify migration
```
make verify
```
# Create backup
```
make backup
```

## Configuration

Configuration can be modified through environment variables or by editing vpic_migration/settings.py:
```python
SQL_SERVER = {
    "driver": "ODBC Driver 18 for SQL Server",
    "server": "localhost",
    "database": "vpic",
    "user": "SA",
    "password": "YourPassword",
    "trust_cert": "yes"
}
```

## Data Structure

The vPIC database contains numerous tables with vehicle-related information. Key tables include:

- Make: Vehicle manufacturers
- Model: Vehicle models
- VehicleType: Types of vehicles
- WMI: World Manufacturer Identifier information
- And many more...

For complete schema information, see [DATA_STRUCTURE.md](docs/DATA_STRUCTURE.md).
