Вот пошаговый план действий для запуска и использования репозитория samsullivandelgobbo/vPIC-dl на сервере с Ubuntu, если Docker и Python уже установлены:


## Подготовка Ubuntu для работы с vPIC-dl






## Старая инструкция
---

### 1. Клонируй репозиторий

```bash
git clone https://github.com/samsullivandelgobbo/vPIC-dl.git
cd vPIC-dl
```

---

### 2. Установи зависимости Python (в отдельное виртуальное окружение)

```bash
python3 -m venv .venv
source .venv/bin/activate
pip install -r requirements.txt
```

---

### 2.1. Убедись, что Python 3 установлен и доступен
Сделай алиас для python:

```bash
sudo ln -s /usr/bin/python3 /usr/bin/python
```

Или установи python-is-python3
Это стандартный способ для Ubuntu 20.04+:

```bash
sudo apt install python-is-python3
```
После этого команда python будет работать как python3 для всех пользователей.

Да, для установки системного пакета python-is-python3 нужно выйти из виртуального окружения (venv), потому что команда sudo apt install ... устанавливает пакет в систему, а не в виртуалку.

Как выйти из venv:

```bash
deactivate
```
Теперь ты снова находишься в обычном окружении пользователя.

Затем установить пакет:
```bash
sudo apt install python-is-python3
```
После установки можешь снова активировать виртуальное окружение:

```bash
source .venv/bin/activate
```
И продолжить работу!


---

### 2.2. Явно укажи bash для Makefile
В начало твоего Makefile добавь строку:

```Makefile
SHELL := /bin/bash
```
Это заставит все shell-команды в Makefile выполняться под bash (а не под sh/dash).

---
### 2.3. Исправь права temp_data

Если папки нет — создай её
```bash
mkdir -p temp_data
```

```bash
sudo chown -R $USER:$USER temp_data
chmod u+rwx temp_data
```

---


Выполни в корне репозитория команду:

```bash
chmod +x ./scripts/restore_backup.sh
```

---

### 2.5. Установи ODBC и необходимые библиотеки
Нужно установить libodbc на хост:
```bash
sudo apt-get update
sudo apt-get install unixodbc unixodbc-dev
```

---

### 2.6. Установи драйвер MS ODBC Driver 18 for SQL Server

```bash
# Добавить репозиторий Microsoft
sudo apt-get update
sudo apt-get install -y curl apt-transport-https
curl https://packages.microsoft.com/keys/microsoft.asc | sudo apt-key add -
# Определить версию Ubuntu, например, 22.04 -> jammy
source /etc/os-release
echo "deb [arch=amd64] https://packages.microsoft.com/ubuntu/$UBUNTU_CODENAME/prod $UBUNTU_CODENAME main" | sudo tee /etc/apt/sources.list.d/mssql-release.list

# Обновить индексы пакетов
sudo apt-get update

# Установить драйвер и зависимости
sudo ACCEPT_EULA=Y apt-get install -y msodbcsql18 unixodbc-dev

# (по желанию) Проверить, что драйвер установлен:
odbcinst -q -d -n "ODBC Driver 18 for SQL Server"
```

Если используешь Ubuntu 24.04 "Noble", а Microsoft ещё не выпустила репозиторий msodbcsql18 для noble (отсюда 404). Эта проблема известна для всех новых LTS, пока Microsoft не обновит свой репозиторий.
Решение: использовать репозиторий от предыдущей версии Ubuntu — jammy (22.04).

Как установить msodbcsql18 на Ubuntu 24.04 (noble)
Добавь репозиторий от jammy (22.04), а не noble:
```bash
sudo su

# Удали ошибочный noble-репозиторий
rm /etc/apt/sources.list.d/mssql-release.list

# Добавь репозиторий для jammy (22.04)
echo "deb [arch=amd64] https://packages.microsoft.com/ubuntu/22.04/prod jammy main" > /etc/apt/sources.list.d/mssql-release.list

exit
```

Дальше стандартно:
```bash
sudo apt-get update
sudo ACCEPT_EULA=Y apt-get install -y msodbcsql18 unixodbc-dev
```
Примечание: такой способ поддерживается Microsoft официально (см. их GitHub Issues и Docs), пока не выйдет поддержка для noble.

---

### Как установить sqlcmd на Ubuntu (24.04, подходит и для 22.04)
Подключи репозиторий (можно использовать тот же, что и msodbcsql18 — jammy):
```bash
sudo su

# Удали старую строку, если была для noble
rm /etc/apt/sources.list.d/mssql-release.list

# Добавь репозиторий для jammy
echo "deb [arch=amd64] https://packages.microsoft.com/ubuntu/22.04/prod jammy main" > /etc/apt/sources.list.d/mssql-release.list

exit
```

Установи пакеты:
```bash
sudo apt-get update
sudo ACCEPT_EULA=Y apt-get install -y mssql-tools18 unixodbc-dev
```
Добавь mssql-tools в PATH (на время сессии):
```bash
export PATH="$PATH:/opt/mssql-tools18/bin"
```
Чтобы путь был постоянным — добавь строку выше в ~/.bashrc и перезапусти терминал.

Теперь проверь соединение:
```bash
sqlcmd -S localhost -U SA -P 'DevPassword123#' -d vpic -Q "SELECT @@VERSION"
```
Если появится версия SQL Server — значит, всё работает, и pyodbc должен тоже работать.

---

### 2.7. Исправь строку подключения к MS SQL в settings.py

В settings.py поменяй строку подключения к MS SQL:
```Python
"server": "127.0.0.1,1433"
```

---

### 3. Запусти Docker-контейнеры для MS SQL и PostgreSQL

> **Важно:** Postgre будет запущен на стандартном порту 5432, MS SQL на 1433. Нужно остановить существующие сервисы, которые могут использовать эти порты.

```bash
make start-containers
```
(Если нет команды make — установи её: `sudo apt install make`)

---

### 4. Запусти миграционный процесс (всё одной командой)

```bash
make all
```

Это скачает свежий дамп базы, восстановит его в MS SQL, мигрирует данные в PostgreSQL и SQLite, и проведёт проверку.

---

### 5. После завершения

- Данные будут доступны в локальном PostgreSQL-контейнере (подключение: user=postgres, password=postgres, база vpic).
- Можно работать с SQLite-файлом или дампами, которые появятся в папке проекта.

---
### 5.1. Экспорт данных из SQLite в SQL-дамп (если нужно)
Но ты можешь сделать SQL-дамп через Python:

```bash
.venv/bin/python -c "import sqlite3; conn = sqlite3.connect('temp_data/vpic.db'); print(''.join(conn.iterdump()))" > temp_data/vpic_sqlite_dump.sql
```
Этот однострочник полностью заменяет sqlite3 ... .dump и не требует внешней утилиты.

---

### ДОПОЛНИТЕЛЬНО: Дамп SQLite через Python (если нет sqlite3)

```bash
# ДОПОЛНИТЕЛЬНО
python3 -c "import sqlite3; print(''.join(sqlite3.connect('temp_data/vpic.db').iterdump()))" > temp_data/vpic_sqlite_dump.sql
```



---

### 6. Остановка и удаление контейнеров (при необходимости)

```bash
docker-compose -f docker/docker-compose.yml down -v
```

---

**Примечания:**
- Все параметры для подключения к базам и контейнерам можно посмотреть/поменять в настройках проекта (например, в .env или settings.py).
- Если что-то не работает — смотри логи через `docker ps`, `docker logs <container_name>`, или вывод команд make.

---

Если хочешь выполнить только отдельные этапы (например, только миграцию или только восстановление), используй отдельные команды make (например, `make migrate-pg`).

Готов ответить на дополнительные вопросы или объяснить, как получить доступ к результату!

---
