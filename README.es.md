# MLB Data Viewer

[English](README.md) | [日本語](README.ja.md) | [Español](README.es.md) | [한국어](README.ko.md)

Una pipeline completa de análisis de MLB que extrae datos de la API de Estadísticas de MLB y Baseball Savant, los transforma a través de un almacén de datos dbt y sirve dashboards interactivos mediante Evidence.

## Arquitectura

```
MLB Stats API ──┐                         ┌── dim_players
Baseball Savant ─┤  Python ETL  ┌─────┐   │── dim_teams
                 ├─────────────▶│ Raw │   │── fct_batting_performance
                 │   (scripts/) │ PG  │──▶│── fct_pitching_performance    ──▶  Evidence
                 │              └─────┘   │── fct_game_summary                Dashboard
                 │                dbt     │── fct_statcast_leaders
                 │           (dbt_mlb/)   │── fct_team_season_summary
                 │  staging ▶ intermediate ▶ marts
```

**Fuentes de datos:**
- [MLB Stats API](https://statsapi.mlb.com) — Equipos, jugadores, partidos, calendarios, estadísticas de bateo/pitcheo por temporada
- [Baseball Savant](https://baseballsavant.mlb.com) (vía pybaseball) — Datos Statcast a nivel de lanzamiento (velocidad de salida, ángulo de lanzamiento, velocidad de rotación, etc.)

## Características

- **7 scripts de extracción** que cubren equipos, jugadores, calendarios, partidos, estadísticas de bateo, estadísticas de pitcheo y datos Statcast
- **19 modelos dbt** en tres capas (staging, intermediate, marts) con métricas avanzadas (wOBA, FIP, victorias pitagóricas, tasa de barrel)
- **Dashboard de Evidence con 6 páginas** con filtros interactivos, tablas de clasificación y visualizaciones
- **~147 pruebas automatizadas** (pruebas de esquema dbt, pruebas singulares, pruebas E2E del pipeline)

## Estructura del Proyecto

```
mlb_data_viewer/
├── config.yml                  # Configuración de base de datos y extracción
├── config.docker.yml           # Configuración Docker (host: db)
├── docker-compose.yml          # Orquestación multi-contenedor
├── .env.example                # Plantilla de variables de entorno
├── pyproject.toml              # Dependencias Python (uv)
├── main.py                     # Punto de entrada
│
├── docker/                     # Contextos de construcción Docker
│   ├── db/init.sql             # Inicialización de BD (esquema + datos semilla)
│   ├── extraction/Dockerfile   # Contenedor de extracción Python
│   ├── dbt/Dockerfile          # Contenedor de transformación dbt
│   └── evidence/Dockerfile     # Contenedor del dashboard Evidence
│
├── db/
│   └── schema.sql              # DDL PostgreSQL (7 tablas raw, índices)
│
├── scripts/                    # Scripts de extracción Python
│   ├── utils.py                # Conexión BD, logging, decorador de reintentos
│   ├── extract_teams.py        # → raw_mlb.raw_teams
│   ├── extract_players.py      # → raw_mlb.raw_players
│   ├── extract_schedule.py     # → raw_mlb.raw_schedule
│   ├── extract_games.py        # → raw_mlb.raw_games
│   ├── extract_batting_stats.py  # → raw_mlb.raw_batting_stats
│   ├── extract_pitching_stats.py # → raw_mlb.raw_pitching_stats
│   ├── extract_statcast.py     # → raw_mlb.raw_statcast (pybaseball)
│   └── run_extraction.py       # Orquestador (flags --skip / --only)
│
├── dbt_mlb/                    # Proyecto dbt
│   ├── dbt_project.yml
│   ├── profiles.yml
│   ├── models/
│   │   ├── staging/            # 7 vistas  — limpieza y renombrado de columnas raw
│   │   ├── intermediate/       # 5 tablas — lógica de negocio y agregaciones
│   │   └── marts/              # 7 tablas — dimensiones y hechos listos para análisis
│   └── tests/                  # 8 pruebas SQL singulares
│
├── evidence_mlb/               # Dashboard Evidence
│   ├── evidence.config.yaml
│   ├── sources/mlb/            # Conexión PostgreSQL
│   └── pages/                  # 6 páginas del dashboard
│
├── tests/
│   └── test_e2e_pipeline.py    # 45 pruebas E2E (6 clases de prueba)
│
└── docs/
    ├── api_endpoints.md        # Documentación de la API de MLB
    └── qa_report.md            # Informe de cobertura de pruebas QA
```

## Inicio Rápido (Docker)

La forma más rápida de comenzar es usando Docker Compose, que configura PostgreSQL, ejecuta el pipeline de datos y lanza el dashboard automáticamente.

### Requisitos previos

- [Docker](https://docs.docker.com/get-docker/) (20.10+)
- [Docker Compose](https://docs.docker.com/compose/install/) (v2+)

### 1. Configurar el Entorno

```bash
cp .env.example .env
```

Edite `.env` si es necesario (los valores predeterminados funcionan tal cual):

```env
POSTGRES_USER=mlb_user
POSTGRES_PASSWORD=mlb_password
POSTGRES_DB=mlb_data
EVIDENCE_PORT=3000
```

### 2. Iniciar la Base de Datos y el Dashboard

```bash
docker compose up -d
```

Esto inicia:
- **db** — PostgreSQL 16 con inicialización automática del esquema
- **evidence** — Dashboard en [http://localhost:3000](http://localhost:3000)

### 3. Ejecutar el Pipeline de Datos

Los pasos de extracción y dbt son trabajos únicos bajo el perfil `pipeline`:

```bash
# Extraer datos de la API de Estadísticas de MLB (lleva tiempo en la primera ejecución)
docker compose --profile pipeline run --rm extraction

# Ejecutar transformaciones dbt (raw → staging → intermediate → marts)
docker compose --profile pipeline run --rm dbt
```

Para omitir los datos Statcast (que es el paso más lento):

```bash
docker compose --profile pipeline run --rm extraction --skip statcast
```

### 4. Acceder al Dashboard

Abra [http://localhost:3000](http://localhost:3000) en su navegador. El dashboard lee de las tablas marts pobladas por dbt.

### 5. Detener los Servicios

```bash
# Detener todos los servicios en ejecución
docker compose down

# Detener y eliminar volúmenes de datos (restablecimiento completo)
docker compose down -v
```

### Solución de Problemas de Docker

| Problema | Solución |
|---|---|
| Conexión a la base de datos rechazada | Espere el healthcheck: `docker compose ps` debe mostrar db como "healthy" |
| La extracción falla a mitad de ejecución | Vuelva a ejecutar con `docker compose --profile pipeline run --rm extraction` (los upserts son idempotentes) |
| El dashboard no muestra datos | Asegúrese de que la extracción y dbt hayan completado: revise los logs con `docker compose logs dbt` |
| Puerto 5432 ya en uso | Cambie `POSTGRES_PORT` en `.env` o detenga su PostgreSQL local |
| Puerto 3000 ya en uso | Cambie `EVIDENCE_PORT` en `.env` |

---

## Desarrollo Local (sin Docker)

### Requisitos previos

- Python 3.12+
- PostgreSQL 14+
- Node.js 18+ (para Evidence)
- [uv](https://docs.astral.sh/uv/) (gestor de paquetes Python)

## Configuración

### 1. Base de Datos

```bash
# Crear base de datos y esquema
createdb mlb_data
psql mlb_data < db/schema.sql
```

### 2. Entorno Python

```bash
uv sync
```

### 3. Configuración

Edite `config.yml` para que coincida con sus credenciales de PostgreSQL:

```yaml
database:
  host: localhost
  port: 5432
  dbname: mlb_data
  user: your_user
  password: your_password
```

## Uso

### Extraer Datos

```bash
# Ejecutar todos los pasos de extracción (en orden de dependencia)
python main.py

# Ejecutar solo pasos específicos
python main.py --only teams players

# Omitir pasos específicos
python main.py --skip statcast
```

Orden de extracción: `teams` → `players` → `schedule` → `games` → `batting_stats` → `pitching_stats` → `statcast`

### Ejecutar Transformaciones dbt

```bash
cd dbt_mlb

# Instalar paquetes dbt
dbt deps

# Ejecutar todos los modelos
dbt run

# Ejecutar pruebas
dbt test
```

### Lanzar el Dashboard

```bash
cd evidence_mlb

# Configurar credenciales de base de datos
export POSTGRES_USER=your_user
export POSTGRES_PASSWORD=your_password

# Instalar dependencias e iniciar servidor de desarrollo
npm install
npm run dev
```

## Modelos dbt

### Staging (vistas)

| Modelo | Descripción |
|---|---|
| `stg_teams` | Datos maestros de equipos |
| `stg_players` | Datos biográficos de jugadores |
| `stg_games` | Resultados de partidos |
| `stg_schedule` | Calendario de temporada |
| `stg_batting_stats` | Estadísticas de bateo por temporada |
| `stg_pitching_stats` | Estadísticas de pitcheo por temporada |
| `stg_statcast` | Datos Statcast a nivel de lanzamiento |

### Intermediate (tablas)

| Modelo | Descripción |
|---|---|
| `int_player_season_batting` | Agregación de bateo jugador-temporada con wOBA |
| `int_player_season_pitching` | Agregación de pitcheo jugador-temporada con FIP |
| `int_game_results` | Resultados de partidos descruzados (una fila por equipo por partido) |
| `int_team_standings` | Clasificación de equipos con porcentaje de victorias, juegos atrás |
| `int_statcast_metrics` | Agregaciones Statcast (barrel%, hard-hit%, EV promedio) |

### Marts (tablas)

| Modelo | Descripción |
|---|---|
| `dim_players` | Dimensión de jugadores |
| `dim_teams` | Dimensión de equipos |
| `fct_batting_performance` | Hechos de bateo: tradicional + avanzado (wOBA, ISO, BABIP) + Statcast (xBA, xwOBA, barrel%) |
| `fct_pitching_performance` | Hechos de pitcheo: tradicional + FIP + métricas Statcast en contra |
| `fct_game_summary` | Resumen de partidos enriquecido con nombres de pitchers y campos derivados |
| `fct_statcast_leaders` | Tabla de clasificación Statcast con rankings por EV, barrel%, hard-hit%, xwOBA |
| `fct_team_season_summary` | Resumen de temporada del equipo con expectativa de victorias pitagórica |

## Páginas del Dashboard

| Página | Descripción |
|---|---|
| **Resumen** | Tarjetas KPI, gráfico de barras de % victorias por equipo, partidos recientes, gráfico de dispersión de diferencial de carreras |
| **Líderes de Bateo** | Tablas de clasificación OPS, wOBA, HR, SB con filtros de posición/equipo |
| **Líderes de Pitcheo** | Tablas de clasificación ERA, FIP, WHIP, K con filtros de abridores/relevistas |
| **Clasificación de Equipos** | Clasificación por división, comparaciones de OPS/ERA de equipos, análisis pitagórico |
| **Perspectivas Statcast** | Líderes de velocidad de salida, barrel%, hard-hit% con gráficos de dispersión |
| **Perfil del Jugador** | Página individual del jugador con estadísticas, métricas Statcast, gráficos de tendencias |

## Pruebas

El proyecto incluye ~147 pruebas automatizadas en tres capas:

```bash
# Pruebas de esquema + singulares de dbt (~102 pruebas)
cd dbt_mlb && dbt test

# Pruebas E2E del pipeline (45 pruebas)
cd .. && python -m pytest tests/test_e2e_pipeline.py -v
```

Categorías de pruebas:
- **Pruebas de esquema** — unicidad, no-nulo, valores aceptados, integridad referencial
- **Pruebas singulares** — rango de promedio de bateo, validez de ERA, consistencia de OPS, razonabilidad pitagórica
- **Pruebas E2E** — trazabilidad de datos raw a marts, precisión de cálculos, umbrales de tasa NULL

## Licencia

Este proyecto está licenciado bajo la **GNU General Public License v3.0 (GPL-3.0)** — consulte el archivo [LICENSE](LICENSE) para más detalles.

GPL-3.0 es requerido debido a la dependencia [MLB-StatsAPI](https://github.com/toddrob99/MLB-StatsAPI) (copyleft GPL-3.0).

### Restricciones de Uso de Datos

Los datos de MLB accedidos a través de la API de Estadísticas de MLB están restringidos a **uso individual, no comercial y no masivo** según los [términos de MLB Advanced Media](http://gdx.mlb.com/components/copyright.txt). El uso comercial requiere autorización escrita previa de MLBAM.

Consulte [NOTICE](NOTICE) para la atribución completa de terceros.
