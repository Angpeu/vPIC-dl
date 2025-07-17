Вот пошаговый план действий для запуска и использования репозитория samsullivandelgobbo/vPIC-dl на сервере с Ubuntu, если Docker и Python уже установлены:

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

```bash
sudo chown -R $USER:$USER temp_data
chmod u+rwx temp_data
```

Если папки нет — создай её
```bash
mkdir -p temp_data
```
---
### 2.4 Вместо жёстко заданного имени, скрипт должен автоматически находить последний (или единственный) файл с маской VPICList_lite_*.bak в папке.

Пример исправленного кода:

```bash
# Найти последний .bak-файл по алфавиту (обычно он самый свежий)
BACKUP_FILE=$(docker exec sqltemp bash -c "ls -1 /var/opt/mssql/backup/VPICList_lite_*.bak 2>/dev/null | sort | tail -n 1")

if [ -z "$BACKUP_FILE" ]; then
    echo "Error: Backup file not found in container"
    exit 1
fi
```

Теперь дальше по скрипту используем переменную $BACKUP_FILE как раньше.

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

## 1. Недоработки автора репозитория

### 1.1. Документация и инструкции
- Нет явного списка системных зависимостей для Ubuntu (ODBC, драйверы, бинарники, sqlite3 и т.д.).
- Не указаны шаги по установке Python 3 и создания виртуального окружения.
- Нет инструкции по выдаче прав на папку temp_data для пользователя, запускающего скрипты.
- Не описано, что делать, если нет доступа к файлам (ошибки прав).
- Не отражена актуальная схема имён файлов (например, `vpic.db` вместо устаревших).

### 1.2. Makefile и автоматизация
- Нет цели для дампа SQLite (`export-sqlite`).
- В некоторых целях/скриптах используются устаревшие имена файлов (например, `vpic.sqlite` вместо `vpic.db`).
- Нет цели для выдачи прав на папку temp_data:
    ```bash
    chmod -R ugo+rw temp_data
    ```
- Нет цели для установки всех системных пакетов (Python 3, ODBC, драйверы, pg_dump, sqlite3 и т.п.).

### 1.3. Код и настройки
- Строки подключения к MS SQL используют `"localhost"`, что не всегда работает; нужно `"127.0.0.1,1433"`.
- В некоторых местах неявно указан порт или не заданы все параметры для ODBC Driver 18 (например, TrustServerCertificate).
- Путь к файлу SQLite в коде не всегда совпадает с реальным именем (`vpic.db`).
- Не реализована автоматическая проверка/создание папки temp_data и прав доступа к ней.
- Нет обработки ошибок, если не хватает прав на запись/чтение файлов.
- В ряде скриптов не добавлена проверка наличия нужных бинарников (`sqlite3`, `pg_dump`).

### 1.4. Хранение и доступ к файлам
- Скрипты не создают папку temp_data автоматически, если её нет.
- Скрипты не проверяют и не выдают предупреждение, если нет прав на запись в temp_data.

---

## 2. Необходимые пакеты для Ubuntu 24.04

```bash
sudo apt update
sudo apt install -y python3 python3-venv python3-pip gcc g++ python3-dev unixodbc-dev curl wget \
    postgresql-client sqlite3 msodbcsql18
```
_(msodbcsql18 — см. инструкции Microsoft по добавлению их репозитория для Ubuntu 24.04)_

---

## 3. Исправления, которые нужно внести в код и инфраструктуру

### 3.1. Makefile
- Исправить все цели, чтобы использовались актуальные имена файлов (например, `vpic.db`, а не `vpic.sqlite`).
- Добавить цель для дампа SQLite:
    ```makefile
    export-sqlite:
    	sqlite3 temp_data/vpic.db .dump > temp_data/vpic_sqlite_dump.sql
    ```
- Добавить цель для выдачи прав на папку:
    ```makefile
    fix-permissions:
    	chmod -R ugo+rw temp_data
    ```
- Добавить создание папки temp_data, если её нет:
    ```makefile
    init-data-dir:
    	mkdir -p temp_data
    ```
- Добавить цель для установки системных зависимостей.

### 3.2. README.md
- Добавить инструкции по выдаче прав на папку temp_data:
    ```bash
    chmod -R ugo+rw temp_data
    ```
- Описать установку всех системных пакетов.
- Обновить имена файлов и команды, чтобы не было ссылок на устаревшие имена.
- Добавить пример дампа SQLite через Python, если на хосте нет sqlite3:
    ```bash
    python3 -c "import sqlite3; print(''.join(sqlite3.connect('temp_data/vpic.db').iterdump()))" > temp_data/vpic_sqlite_dump.sql
    ```

### 3.3. В коде Python
- Везде заменить `"localhost"` на `"127.0.0.1,1433"` в строках подключения к MS SQL.
- Проверять существование папки temp_data и создавать её при необходимости.
- Добавлять обработку ошибок при отсутствии прав на запись.
- Везде использовать актуальные имена файлов (`vpic.db`), не использовать устаревшие (`vpic.sqlite`).
- Добавить информативные ошибки и подсказки (например, "Нет прав на temp_data, попробуйте chmod").

### 3.4. Контроль доступа
- Проверять права на папку temp_data перед записью файлов.
- В случае ошибки выводить чёткое сообщение с примером команды для исправления.

---

## 4. Пример исправлений файлов (Makefile и README.md)

Могу предложить патч для Makefile и README.md с этими исправлениями — если нужно, дай знать!

---

## 5. Итоговый чек-лист

- [ ] Исправить устаревшие имена файлов в коде и Makefile
- [ ] Добавить создание папки temp_data и выдачу прав
- [ ] Добавить цели для дампа SQLite и экспорта/бэкапов
- [ ] Обновить документацию по установке и правам доступа
- [ ] Проверить строки подключения и параметры для MS SQL
- [ ] Добавить обработку ошибок и информативные сообщения

---

**Если нужны примеры файлов — напиши, покажу как это реализовать!**