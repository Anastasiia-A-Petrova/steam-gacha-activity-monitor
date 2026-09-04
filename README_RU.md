# Steam Gacha Activity Monitor

Автоматизированная система мониторинга активности игроков в gacha и live-service играх на Steam.

Проект объединяет **сбор данных через Steam Web API, Python, PostgreSQL, SQL-аналитику, n8n, Telegram и Google Sheets** в единый аналитический pipeline.

Основная задача проекта — не просто собрать данные о количестве игроков, а построить систему, которая регулярно получает новые наблюдения, сохраняет историю, рассчитывает изменения активности, оценивает стабильность игр, выявляет потенциальные аномалии и автоматически обновляет аналитический отчет.

---

## Содержание

* [О проекте](#о-проекте)
* [Бизнес-задача](#бизнес-задача)
* [Ключевые вопросы](#ключевые-вопросы)
* [Метрики](#метрики)
* [Архитектура](#архитектура)
* [Стек](#стек)
* [Игровая выборка](#игровая-выборка)
* [Источники данных](#источники-данных)
* [Сбор данных](#сбор-данных)
* [Хранение данных](#хранение-данных)
* [SQL-аналитика](#sql-аналитика)
* [Anomaly Detection](#anomaly-detection)
* [Автоматизация через n8n](#автоматизация-через-n8n)
* [Data Quality](#data-quality)
* [Telegram Alerts](#telegram-alerts)
* [Google Sheets Dashboard](#google-sheets-dashboard)
* [Результаты](#результаты)
* [Структура проекта](#структура-проекта)
* [Установка и запуск](#установка-и-запуск)
* [Запуск API](#запуск-api)
* [Запуск сбора данных](#запуск-сбора-данных)
* [Настройка n8n](#настройка-n8n)
* [SQL Views](#sql-views)
* [Ограничения проекта](#ограничения-проекта)
* [Что можно развивать дальше](#что-можно-развивать-дальше)
* [Итог](#итог)

---

# О проекте

**Steam Gacha Activity Monitor** — портфолио-проект по аналитике данных и автоматизации.

Система предназначена для регулярного мониторинга concurrent player activity в подборке gacha и live-service игр, доступных в Steam.

В отличие от статического анализа CSV-файла, проект построен как **динамическая система мониторинга**:

```text
Steam Web API
     ↓
Python Collector
     ↓
PostgreSQL
     ↓
SQL Analytics Views
     ↓
n8n Automation
     ↓
 ┌───────────────┬────────────────┐
 ↓               ↓                ↓
Telegram     Google Sheets    Data Quality
Alerts          Dashboard        Checks
```

Каждый новый запуск создает новый snapshot данных, благодаря чему постепенно формируется временной ряд для каждой игры.

---

# Бизнес-задача

Основной вопрос проекта:

> **Как изменяется активность игроков в gacha и live-service играх на Steam и какие игры демонстрируют наиболее высокий, стабильный или волатильный уровень активности?**

Система позволяет отвечать на следующие бизнес-вопросы:

* Какие игры имеют наибольшую текущую активность?
* Какие игры растут, а какие теряют аудиторию?
* Насколько стабильна активность конкретной игры?
* Какие игры имеют высокий уровень волатильности?
* Какие изменения можно считать потенциальными аномалиями?
* Насколько надежны последние собранные данные?
* Работает ли pipeline без пропущенных игр и некорректных значений?

---

# Ключевые вопросы

### 1. Activity

Какие игры имеют наибольшее количество одновременно играющих пользователей?

### 2. Growth

Какие игры демонстрируют положительную динамику активности?

### 3. Stability

Какие игры сохраняют относительно стабильный уровень concurrent players?

### 4. Volatility

Какие игры характеризуются значительными колебаниями активности?

### 5. Anomalies

Какие значения существенно отклоняются от исторического поведения конкретной игры?

### 6. Data Quality

Насколько полными и свежими являются данные последнего snapshot?

---

# Метрики

## Current Players

Количество пользователей, одновременно находящихся в игре на Steam в момент получения данных.

```text
current_players
```

Важно:

> Это **Steam concurrent players**, а не размер всей пользовательской базы игры.

Данные не включают пользователей мобильных версий, PlayStation, Xbox и других платформ.

---

## Player Change

Абсолютное изменение количества игроков между двумя последовательными наблюдениями:

```text
player_change =
current_players - previous_players
```

---

## Change %

Процентное изменение активности:

```text
change_percent =
100 × (current_players - previous_players)
/
previous_players
```

---

## Average Players

Среднее количество concurrent players за весь доступный период наблюдений.

```text
AVG(current_players)
```

---

## Minimum / Maximum Players

Минимальное и максимальное зафиксированное значение активности.

```text
MIN(current_players)
MAX(current_players)
```

---

## Standard Deviation

Стандартное отклонение количества игроков.

Используется для оценки абсолютной изменчивости активности.

---

## Coefficient of Variation

Относительная мера волатильности:

```text
CV =
STDDEV(current_players)
/
AVG(current_players)
× 100%
```

Используется для сравнения стабильности игр с разным масштабом аудитории.

---

## Activity Range

Разница между максимальным и минимальным значением относительно среднего:

```text
Activity Range % =
(MAX - MIN)
/
AVG
× 100%
```

---

## Trend

На основе первого и последнего доступного наблюдения игра классифицируется как:

* `Growing`
* `Declining`
* `Stable`

---

## Z-score

Для anomaly detection используется отклонение текущего значения от исторического среднего в единицах стандартного отклонения:

```text
Z-score =
(current_players - baseline_avg)
/
baseline_stddev
```

Используемый порог:

```text
Z ≥ 2  → High anomaly

Z ≤ -2 → Low anomaly

otherwise → Normal
```

---

# Архитектура

Полный pipeline проекта:

```text
                    ┌──────────────────────┐
                    │    Steam Web API     │
                    └──────────┬───────────┘
                               │
                               ▼
                    ┌──────────────────────┐
                    │ Python Data Collector│
                    │      requests        │
                    └──────────┬───────────┘
                               │
                 ┌─────────────┴─────────────┐
                 ▼                           ▼
        ┌─────────────────┐        ┌─────────────────┐
        │   CSV Storage   │        │   PostgreSQL    │
        │ steam_snapshots │        │ steam_monitor   │
        └─────────────────┘        └────────┬────────┘
                                            │
                                            ▼
                                  ┌────────────────────┐
                                  │    SQL Analytics   │
                                  │       Views        │
                                  └─────────┬──────────┘
                                            │
                                            ▼
                                     ┌────────────┐
                                     │    n8n     │
                                     │ Automation │
                                     └─────┬──────┘
                                           │
                         ┌─────────────────┼──────────────────┐
                         ▼                 ▼                  ▼
                  ┌────────────┐   ┌──────────────┐   ┌──────────────┐
                  │  Telegram  │   │ Google Sheets│   │ Data Quality │
                  │   Alerts   │   │   Dashboard  │   │    Checks    │
                  └────────────┘   └──────────────┘   └──────────────┘
```

---

# Стек

## Data Collection

* Python 3.14
* `requests`
* Steam Web API
* REST API

## Data Storage

* PostgreSQL
* CSV

## Data Analysis

* SQL
* PostgreSQL Window Functions
* CTE
* Aggregate Functions
* Statistical metrics

## Automation

* n8n
* Cron / Schedule Trigger
* HTTP Request
* PostgreSQL nodes
* IF logic
* Google Sheets integration
* Telegram integration

## Reporting

* Google Sheets
* Google Sheets formulas
* Charts
* Dashboard

## API Layer

* FastAPI
* Uvicorn

---

# Игровая выборка

В мониторинг включены gacha и live-service игры, доступные в Steam.

## Активные игры

| Game                        | Steam App ID | Category                      |
| --------------------------- | -----------: | ----------------------------- |
| Wuthering Waves             |      3513350 | Open-world Action RPG         |
| Zenless Zone Zero           |      4162040 | Action RPG                    |
| Honkai Impact 3rd           |      1671200 | Action RPG                    |
| Punishing: Gray Raven       |      4125930 | Action RPG                    |
| Blue Archive                |      3557620 | Tactical RPG                  |
| GIRLS' FRONTLINE 2: EXILIUM |      3347400 | Tactical RPG                  |
| Limbus Company              |      1973530 | Turn-based RPG                |
| Umamusume: Pretty Derby     |      3224770 | Character Collection / Racing |
| Snowbreak: Containment Zone |      2668080 | Shooter / RPG                 |
| Reverse: 1999               |      3092660 | Turn-based RPG                |
| AFK Journey                 |      4195600 | Idle / RPG                    |
| Tower of Fantasy            |      2064650 | Open-world RPG                |
| Sword of Convallaria        |      2526380 | Tactical RPG                  |
| NTE: Neverness to Everness  |      4508340 | Open-world Action RPG         |
| OUTERPLANE                  |      4247320 | Turn-based RPG                |
| Summoners War: Chronicles   |      2167580 | MMORPG / Character Collection |
| Summoners War: RUSH         |      3813590 | RPG / Auto-battler            |

Также в игровом universe присутствует:

| Game                | Steam App ID | Status   |
| ------------------- | -----------: | -------- |
| Arknights: Endfield |      4732690 | Upcoming |

Upcoming title не участвует в текущем мониторинге активности.

---

# Источники данных

Основной источник:

**Steam Web API**

Используемый endpoint:

```text
https://api.steampowered.com/ISteamUserStats/GetNumberOfCurrentPlayers/v1/
```

Параметр:

```text
appid
```

Endpoint возвращает текущее количество игроков для указанной Steam App ID.

Для данного endpoint отдельный Steam API key не требуется.

---

# Сбор данных

Основной Python collector получает список активных игр и последовательно запрашивает Steam API.

Пример логики:

```python
for game in ACTIVE_GAMES:

    players = get_current_players(game["appid"])

    snapshot = {
        "collected_at": collected_at,
        "appid": game["appid"],
        "name": game["name"],
        "category": game["category"],
        "current_players": players
    }
```

Каждый запуск формирует новый snapshot.

Например:

```text
2026-09-04 16:31:25
Wuthering Waves
8,603 players

2026-09-04 16:31:25
Zenless Zone Zero
6,598 players

2026-09-04 16:31:25
Limbus Company
31,747 players
```

При 17 активных играх один запуск создает:

```text
17 records
```

---

# Хранение данных

Основная таблица:

```sql
steam_player_snapshots
```

Структура:

```sql
CREATE TABLE steam_player_snapshots (
    id BIGSERIAL PRIMARY KEY,
    collected_at TIMESTAMP NOT NULL,
    appid INTEGER NOT NULL,
    name TEXT NOT NULL,
    category TEXT,
    current_players INTEGER,
    created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP
);
```

Каждая строка представляет одно наблюдение:

```text
game + timestamp + current_players
```

Таким образом, таблица постепенно превращается в исторический dataset:

```text
timestamp 1 → 17 games
timestamp 2 → 17 games
timestamp 3 → 17 games
...
timestamp N → 17 games
```

---

# SQL-аналитика

Для аналитики создано несколько PostgreSQL Views.

---

## 1. `game_activity_changes`

Рассчитывает изменения между последовательными наблюдениями.

Используется:

```sql
LAG()
```

Основные поля:

```text
collected_at
appid
name
category
current_players
previous_players
player_change
change_percent
minutes_since_previous
previous_collected_at
```

---

## 2. `game_activity_metrics`

Рассчитывает основные статистические показатели по каждой игре:

```text
observations
avg_players
min_players
max_players
stddev_players
coefficient_of_variation
first_snapshot
last_snapshot
```

---

## 3. `game_activity_trends`

Сравнивает первое и последнее наблюдение:

```text
first_players
latest_players
total_change
total_change_percent
trend
```

Пример:

```text
first_players = 6,598
latest_players = 9,925

total_change = +3,327

total_change_percent = +50.42%

trend = Growing
```

---

## 4. `game_activity_anomalies`

Используется для выявления потенциальных аномалий.

Для каждого наблюдения рассчитываются:

```text
previous_players
historical_observations
baseline_avg
baseline_stddev
change_percent
z_score
anomaly_level
```

---

## 5. `game_stability_analysis`

Классифицирует стабильность игры:

```text
Very stable
Stable
Volatile
Highly volatile
Insufficient history
```

Классификация основана на coefficient of variation.

---

## 6. `game_activity_ranking`

Объединяет основные аналитические показатели в единую ranking view.

Используется для:

* Game Ranking
* Dashboard
* Activity Trends
* дальнейшей аналитики

---

# Anomaly Detection

Для обнаружения необычных значений используется rolling historical baseline.

Для каждой игры текущий snapshot сравнивается с предыдущими наблюдениями.

Историческое окно:

```text
28 предыдущих наблюдений
```

Минимальное требование:

```text
historical_observations >= 28
```

До накопления достаточной истории:

```text
Insufficient history
```

После накопления истории:

```text
Z-score >= 2
    → High

Z-score <= -2
    → Low

otherwise
    → Normal
```

Это позволяет отличать обычные колебания активности от потенциально значимых изменений.

### Почему 28 наблюдений?

В текущей конфигурации scheduler запускает сбор:

```text
каждые 3 часа
```

Это:

```text
8 snapshots / day
```

Следовательно:

```text
28 observations ≈ 3.5 days
```

После накопления необходимой истории anomaly detection начинает работать в полноценном режиме.

---

# Автоматизация через n8n

n8n используется как orchestration layer.

Текущий pipeline:

```text
Schedule Trigger
       ↓
HTTP Request
       ↓
PostgreSQL Data Quality Check
       ↓
IF
   ↙       ↘
 TRUE     FALSE
   ↓         ↓
Telegram  Telegram
   ↓
Analytics
   ↓
Google Sheets
```

---

## Schedule Trigger

Текущий cron:

```text
0 */3 * * *
```

Запуск:

```text
00:00
03:00
06:00
09:00
12:00
15:00
18:00
21:00
```

Это позволяет постепенно накапливать исторические наблюдения без чрезмерно частых запросов к Steam API.

---

## HTTP Request

n8n вызывает локальный FastAPI endpoint:

```text
POST http://127.0.0.1:8000/collect
```

Ответ:

```json
{
    "status": "success",
    "message": "Steam snapshot collected"
}
```

---

# FastAPI

FastAPI используется как промежуточный API layer между n8n и Python collector.

Основные endpoints:

```text
GET /
POST /collect
```

### GET `/`

Возвращает статус сервиса:

```json
{
    "status": "running",
    "service": "Steam Gacha Monitor API"
}
```

### POST `/collect`

Запускает сбор данных.

После завершения:

```json
{
    "status": "success",
    "message": "Steam snapshot collected"
}
```

---

# Data Quality

Data Quality встроен непосредственно в automation pipeline.

Перед отправкой результатов система проверяет последний snapshot.

Проверяются:

### Количество игр

Ожидается:

```text
17 games
```

### Уникальность игр

```text
17 unique appids
```

### Null values

Проверяется отсутствие:

```text
current_players IS NULL
```

### Freshness

Проверяется время последнего snapshot.

### Historical depth

Проверяется количество исторических наблюдений, доступных для anomaly detection.

---

## Data Quality logic

Успешный запуск:

```text
Games: 17/17
Null players: 0
Freshness: Fresh
```

При проблеме pipeline может отправить alert вместо сообщения об успешном обновлении.

---

# Telegram Alerts

Telegram используется для автоматического мониторинга состояния pipeline.

## Успешный запуск

Пример сообщения:

```text
✅ Steam Activity Monitor

Data collection completed successfully.

Games collected: 17/17

Latest snapshot:
2026-09-04 16:31:25

Data quality: OK
```

## Ошибка Data Quality

При проблеме формируется alert:

```text
🚨 DATA QUALITY ALERT

Steam Activity Monitor

Expected games: 17
Actual games: X

Latest snapshot:
...

⚠️ One or more games may be missing from the latest collection.
```

Таким образом, система не требует ручной проверки каждого запуска.

---

# Google Sheets Dashboard

Google Sheets используется как lightweight reporting layer.

Созданы следующие sheets:

```text
Dashboard
Game Ranking
Activity Trends
Anomalies
Raw Data
Dashboard Data
Trend Data
Dashboard Charts Data
```

---

# Dashboard

Основной Dashboard содержит:

## KPI

### Games monitored

Количество отслеживаемых игр.

```text
17
```

### Latest total players

Суммарное количество concurrent players в последнем snapshot.

### Top game by activity

Игра с максимальным средним количеством игроков.

### Growing games

Количество игр с положительной динамикой.

### Declining games

Количество игр с отрицательной динамикой.

---

# Top 5 Games

Dashboard содержит ranking пяти игр с максимальным средним количеством concurrent players.

Используется SQL:

```sql
SELECT
    ROW_NUMBER() OVER (
        ORDER BY avg_players DESC
    ) AS rank,
    name,
    ROUND(avg_players::numeric, 2) AS avg_players
FROM game_activity_ranking
ORDER BY avg_players DESC
LIMIT 5;
```

Визуализация:

```text
Top 5 Games by Average Steam Players
```

Используется horizontal bar chart.

---

# Activity Dynamics

Отдельный график показывает изменение активности каждой игры:

```text
Activity Change by Game (%)
```

Основная метрика:

```text
total_change_percent
```

Это позволяет быстро увидеть:

* наиболее быстро растущие игры;
* игры с отрицательной динамикой;
* игры с относительно стабильной активностью.

---

# Data Quality Dashboard

На Dashboard отображается техническое состояние pipeline:

```text
Data Quality

Games collected      17/17
Null players         OK
Freshness            Fresh
Anomaly history      X/28
```

Это позволяет одновременно видеть аналитические результаты и качество данных.

---

# Raw Data

`Raw Data` содержит последний собранный snapshot.

Основные поля:

```text
collected_at
appid
name
category
current_players
```

При новых запусках система получает новые значения и сохраняет историю в PostgreSQL.

---

# Результаты

В ходе разработки была построена полностью работающая end-to-end система:

```text
Steam API
   ↓
Python
   ↓
PostgreSQL
   ↓
SQL Analytics
   ↓
n8n
   ↓
Telegram
   ↓
Google Sheets
   ↓
Dashboard
```

На этапе тестирования были проверены:

* корректность получения данных Steam API;
* сбор всех 17 активных игр;
* запись snapshots в PostgreSQL;
* отсутствие `NULL` в `current_players`;
* отсутствие отрицательных значений;
* отсутствие пустых названий игр;
* уникальность игр внутри snapshot;
* корректность SQL Views;
* работу n8n pipeline;
* автоматическое обновление Google Sheets;
* отправку Telegram уведомлений;
* обновление Dashboard;
* накопление исторических данных.

Для каждого полного snapshot система получает:

```text
17 games
17 unique appids
17 player observations
```

При `N` snapshots ожидаемое количество строк:

```text
17 × N
```

Например, при 11 snapshots:

```text
187 rows
17 unique games
11 snapshots
```

---

# Проверка целостности данных

Для проверки pipeline использовались SQL data quality checks.

Пример:

```sql
SELECT
    COUNT(*) AS total_rows,
    COUNT(DISTINCT appid) AS unique_games,
    COUNT(DISTINCT collected_at) AS snapshots
FROM steam_player_snapshots;
```

Также проверяются:

```text
NULL values
negative player counts
empty names
empty categories
duplicate observations
snapshot completeness
```

Для каждого snapshot:

```sql
SELECT
    collected_at,
    COUNT(*) AS games,
    COUNT(DISTINCT appid) AS unique_games
FROM steam_player_snapshots
GROUP BY collected_at
ORDER BY collected_at;
```

Ожидаемый результат:

```text
17 games
17 unique games
```

для каждого timestamp.

---

# Структура проекта

```text
steam_automation/
│
├── .venv/
│
├── data/
│   └── steam_snapshots.csv
│
├── logs/
│
├── scripts/
│   ├── games.py
│   ├── steam_api.py
│   └── collect_snapshot.py
│
├── sql/
│   ├── 01_schema.sql
│   ├── 02_activity_changes.sql
│   ├── 03_activity_metrics.sql
│   ├── 04_activity_trends.sql
│   ├── 05_anomaly_detection.sql
│   ├── 06_game_stability.sql
│   └── 07_game_ranking.sql
│
├── api.py
├── db.py
├── requirements.txt
├── .env
├── .env.example
├── .gitignore
└── README.md
```

---

# Установка и запуск

## 1. Клонирование репозитория

```bash
git clone <repository-url>
cd steam_automation
```

---

## 2. Создание виртуального окружения

```bash
python -m venv .venv
```

Windows:

```powershell
.\.venv\Scripts\Activate.ps1
```

---

## 3. Установка зависимостей

```bash
pip install -r requirements.txt
```

Основные зависимости:

```text
requests
fastapi
uvicorn
psycopg2-binary
python-dotenv
```

---

# PostgreSQL

Создать базу данных:

```text
steam_monitor
```

После этого выполнить:

```text
sql/01_schema.sql
```

Таблица:

```text
steam_player_snapshots
```

---

# Environment Variables

Создать файл:

```text
.env
```

Пример:

```env
DB_HOST=localhost
DB_PORT=5432
DB_NAME=steam_monitor
DB_USER=postgres
DB_PASSWORD=your_password
```

Файл `.env` не должен добавляться в Git.

Для этого используется `.gitignore`.

В репозитории хранится только:

```text
.env.example
```

---

# Создание SQL Views

После создания таблицы последовательно выполнить:

```text
01_schema.sql
02_activity_changes.sql
03_activity_metrics.sql
04_activity_trends.sql
05_anomaly_detection.sql
06_game_stability.sql
07_game_ranking.sql
```

После этого PostgreSQL будет содержать:

```text
steam_player_snapshots
        ↓
game_activity_changes
        ↓
game_activity_metrics
        ↓
game_activity_trends
        ↓
game_activity_anomalies
        ↓
game_stability_analysis
        ↓
game_activity_ranking
```

---

# Запуск сбора данных

Для ручного запуска:

```powershell
python scripts/collect_snapshot.py
```

Пример результата:

```text
Starting collection: 2026-09-04T12:16:54

Active games to collect: 17

OK | Wuthering Waves | 8,603 players
OK | Zenless Zone Zero | 6,598 players
OK | Honkai Impact 3rd | 79 players
...
OK | Summoners War: RUSH | 74 players

Saved 17 records to data\steam_snapshots.csv
Saved 17 records to PostgreSQL
```

---

# Запуск API

Запустить FastAPI:

```powershell
uvicorn api:app --host 127.0.0.1 --port 8000
```

После запуска:

```text
http://127.0.0.1:8000/
```

Swagger:

```text
http://127.0.0.1:8000/docs
```

Проверка:

```text
GET /
```

Ожидаемый результат:

```json
{
    "status": "running",
    "service": "Steam Gacha Monitor API"
}
```

---

# Настройка n8n

Для автоматического запуска необходимо, чтобы одновременно работали:

```text
FastAPI
n8n
PostgreSQL
```

Основной workflow:

```text
Schedule Trigger
        ↓
HTTP Request
        ↓
Postgres Data Quality
        ↓
IF
   ↙       ↘
 TRUE     FALSE
   ↓         ↓
Telegram  Telegram
   ↓
Analytics
   ↓
Google Sheets
```

---

## Schedule

Текущая настройка:

```text
0 */3 * * *
```

То есть один запуск каждые 3 часа.

Для локального проекта компьютер и n8n должны оставаться запущенными, чтобы scheduled workflow выполнялся.

---

# Безопасность

Секретные данные не хранятся в GitHub.

В `.gitignore` включены:

```text
.env
.env.*
```

При этом `.env.example` остается доступным как шаблон конфигурации.

Не следует публиковать:

* database password;
* Telegram bot token;
* OAuth client secret;
* другие credentials;
* персональные access tokens.

---

# Ограничения проекта

## 1. Steam-only data

Метрика отражает активность только на Steam.

Игра может иметь значительно большую аудиторию на:

* mobile;
* PlayStation;
* Xbox;
* других платформах.

Поэтому `current_players` нельзя интерпретировать как total active users.

---

## 2. Concurrent players ≠ DAU / MAU

Steam endpoint показывает количество игроков одновременно в игре.

Это не:

```text
DAU
MAU
registered users
paying users
retention
```

Поэтому проект измеряет именно **Steam activity**, а не полный размер аудитории.

---

## 3. Limited historical period

Anomaly detection требует накопления истории.

До достижения:

```text
28 historical observations
```

игра получает статус:

```text
Insufficient history
```

Это сознательное ограничение, а не ошибка pipeline.

---

## 4. Sampling frequency

Данные собираются дискретно.

При текущем расписании:

```text
1 snapshot / 3 hours
```

система не видит изменения между двумя точками измерения.

Более частый sampling позволил бы лучше анализировать intraday patterns, но увеличил бы количество API requests и операций в pipeline.

---

## 5. External API dependency

Работа системы зависит от доступности Steam API.

Если API недоступен или возвращает ошибку, соответствующий snapshot может потребовать повторной загрузки.

---

## 6. Local automation

В текущей версии:

```text
n8n
FastAPI
PostgreSQL
```

запущены локально.

Поэтому автоматизация зависит от:

* работающего компьютера;
* запущенного n8n;
* запущенного FastAPI;
* доступного PostgreSQL.

---

# Что можно развивать дальше

Проект можно расширить до полноценной monitoring platform.

## 1. Cloud deployment

Перенести:

```text
FastAPI
PostgreSQL
n8n
```

в облачную инфраструктуру.

Например:

```text
Cloud VM
     ↓
FastAPI
     ↓
PostgreSQL
     ↓
n8n
```

Это позволит запускать pipeline 24/7 без локального компьютера.

---

## 2. Более частый sampling

Можно собирать данные:

```text
каждые 30 минут
каждые 15 минут
каждые 10 минут
```

Это позволит анализировать:

* daily patterns;
* peaks;
* drops;
* event effects;
* short-term volatility.

---

## 3. Event Analysis

Следующий уровень — сопоставить изменения player activity с:

* major updates;
* new characters;
* banners;
* collaborations;
* Steam events;
* DLC;
* seasonal content.

Тогда можно перейти от:

> «активность выросла»

к:

> «активность выросла после конкретного события».

---

## 4. Time-of-day Analysis

После накопления достаточной истории можно анализировать:

```text
hour of day
day of week
weekday vs weekend
```

и строить типичный activity profile каждой игры.

---

## 5. Advanced anomaly detection

Вместо простого Z-score можно использовать:

* rolling mean;
* rolling standard deviation;
* EWMA;
* seasonal baseline;
* IQR;
* Isolation Forest;
* change-point detection.

---

## 6. Power BI

Google Sheets Dashboard может быть заменен или дополнен Power BI.

Архитектура:

```text
PostgreSQL
     ↓
Power BI
     ↓
Interactive Dashboard
```

---

## 7. More business metrics

В будущем можно добавить:

* activity share;
* relative market share;
* category averages;
* category growth;
* volatility ranking;
* momentum score;
* retention proxies;
* game lifecycle indicators.

---

# Итог

Проект демонстрирует полный цикл работы с данными:

```text
API
↓
Data Collection
↓
Data Storage
↓
Data Cleaning / Quality Checks
↓
SQL Transformation
↓
Statistical Analysis
↓
Anomaly Detection
↓
Automation
↓
Alerts
↓
Reporting
↓
Dashboard
```

Главная ценность проекта заключается в том, что это не статический анализ готового dataset.

Система самостоятельно:

1. получает данные из внешнего API;
2. формирует новые snapshots;
3. сохраняет историю;
4. рассчитывает аналитические показатели;
5. проверяет качество данных;
6. определяет динамику активности;
7. готовит данные для anomaly detection;
8. запускается по расписанию;
9. отправляет уведомления;
10. обновляет Google Sheets;
11. поддерживает аналитический Dashboard.

Таким образом, проект демонстрирует не только навыки **Data Analysis**, но и работу с **API, Python automation, PostgreSQL, SQL, data quality, orchestration и reporting**.

---

## Key Skills Demonstrated

```text
Python
REST API
Steam Web API
PostgreSQL
SQL
CTE
Window Functions
LAG()
FIRST_VALUE()
Aggregate Functions
Statistical Analysis
Z-score
Anomaly Detection
Data Quality
FastAPI
n8n
Workflow Automation
Telegram Bots
Google Sheets
Dashboarding
Data Pipeline Design
```

---

## Project Status

**Completed MVP / active data collection**

Основной pipeline работает end-to-end:

```text
Steam API
      ↓
Python
      ↓
PostgreSQL
      ↓
SQL Analytics
      ↓
n8n
      ↓
Telegram
      ↓
Google Sheets
      ↓
Dashboard
```

История наблюдений продолжает накапливаться автоматически.

После накопления достаточного количества наблюдений (`28+`) anomaly detection перейдет из режима `Insufficient history` в полноценный режим статистического контроля.
