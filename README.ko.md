# MLB Data Viewer

[English](README.md) | [日本語](README.ja.md) | [Español](README.es.md) | [한국어](README.ko.md)

MLB Stats API와 Baseball Savant에서 데이터를 추출하고, dbt 데이터 웨어하우스를 통해 변환하며, Evidence로 인터랙티브 대시보드를 제공하는 엔드투엔드 MLB 분석 파이프라인입니다.

## 아키텍처

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

**데이터 소스:**
- [MLB Stats API](https://statsapi.mlb.com) — 팀, 선수, 경기, 일정, 타격/투구 시즌 통계
- [Baseball Savant](https://baseballsavant.mlb.com) (pybaseball 경유) — 투구 레벨 Statcast 데이터 (타구 속도, 발사각, 회전수 등)

## 주요 기능

- **7개의 추출 스크립트** — 팀, 선수, 일정, 경기, 타격 성적, 투구 성적, Statcast 데이터 수집
- **19개의 dbt 모델** — 3개 레이어(스테이징, 중간, 마트)에 걸친 고급 지표 (wOBA, FIP, 피타고라스 승률, 배럴률)
- **6페이지 Evidence 대시보드** — 인터랙티브 필터, 리더보드, 시각화
- **약 147개의 자동화 테스트** — dbt 스키마 테스트, 단위 테스트, E2E 파이프라인 테스트

## 프로젝트 구조

```
mlb_data_viewer/
├── config.yml                  # 데이터베이스 및 추출 설정
├── config.docker.yml           # Docker 설정 (host: db)
├── docker-compose.yml          # 멀티 컨테이너 오케스트레이션
├── .env.example                # 환경 변수 템플릿
├── pyproject.toml              # Python 의존성 (uv)
├── main.py                     # 진입점
│
├── docker/                     # Docker 빌드 컨텍스트
│   ├── db/init.sql             # DB 초기화 (스키마 + 시드 데이터)
│   ├── extraction/Dockerfile   # Python 추출 컨테이너
│   ├── dbt/Dockerfile          # dbt 변환 컨테이너
│   └── evidence/Dockerfile     # Evidence 대시보드 컨테이너
│
├── db/
│   └── schema.sql              # PostgreSQL DDL (7개 raw 테이블, 인덱스)
│
├── scripts/                    # Python 추출 스크립트
│   ├── utils.py                # DB 연결, 로깅, 재시도 데코레이터
│   ├── extract_teams.py        # → raw_mlb.raw_teams
│   ├── extract_players.py      # → raw_mlb.raw_players
│   ├── extract_schedule.py     # → raw_mlb.raw_schedule
│   ├── extract_games.py        # → raw_mlb.raw_games
│   ├── extract_batting_stats.py  # → raw_mlb.raw_batting_stats
│   ├── extract_pitching_stats.py # → raw_mlb.raw_pitching_stats
│   ├── extract_statcast.py     # → raw_mlb.raw_statcast (pybaseball)
│   └── run_extraction.py       # 오케스트레이터 (--skip / --only 플래그)
│
├── dbt_mlb/                    # dbt 프로젝트
│   ├── dbt_project.yml
│   ├── profiles.yml
│   ├── models/
│   │   ├── staging/            # 7개 뷰 — raw 컬럼 정제 및 이름 변경
│   │   ├── intermediate/       # 5개 테이블 — 비즈니스 로직 및 집계
│   │   └── marts/              # 7개 테이블 — 분석용 디멘션 및 팩트
│   └── tests/                  # 8개 단위 SQL 테스트
│
├── evidence_mlb/               # Evidence 대시보드
│   ├── evidence.config.yaml
│   ├── sources/mlb/            # PostgreSQL 연결
│   └── pages/                  # 6개 대시보드 페이지
│
├── tests/
│   └── test_e2e_pipeline.py    # 45개 E2E 테스트 (6개 테스트 클래스)
│
└── docs/
    ├── api_endpoints.md        # MLB API 문서
    └── qa_report.md            # QA 테스트 커버리지 보고서
```

## 빠른 시작 (Docker)

가장 빠르게 시작하는 방법은 Docker Compose를 사용하는 것입니다. PostgreSQL 설정, 데이터 파이프라인 실행, 대시보드 시작을 자동으로 수행합니다.

### 사전 요구 사항

- [Docker](https://docs.docker.com/get-docker/) (20.10+)
- [Docker Compose](https://docs.docker.com/compose/install/) (v2+)

### 1. 환경 설정

```bash
cp .env.example .env
```

필요한 경우 `.env`를 편집하세요 (기본값으로 바로 동작합니다):

```env
POSTGRES_USER=mlb_user
POSTGRES_PASSWORD=mlb_password
POSTGRES_DB=mlb_data
EVIDENCE_PORT=3000
```

### 2. 데이터베이스 및 대시보드 시작

```bash
docker compose up -d
```

시작되는 서비스:
- **db** — 스키마 자동 초기화를 포함한 PostgreSQL 16
- **evidence** — [http://localhost:3000](http://localhost:3000)의 대시보드

### 3. 데이터 파이프라인 실행

추출 및 dbt 단계는 `pipeline` 프로필 하에서 일회성 작업입니다:

```bash
# MLB Stats API에서 데이터 추출 (첫 실행 시 시간이 걸립니다)
docker compose --profile pipeline run --rm extraction

# dbt 변환 실행 (raw → staging → intermediate → marts)
docker compose --profile pipeline run --rm dbt
```

Statcast 데이터(가장 느린 단계)를 건너뛰려면:

```bash
docker compose --profile pipeline run --rm extraction --skip statcast
```

### 4. 대시보드 접속

브라우저에서 [http://localhost:3000](http://localhost:3000)을 열어주세요. 대시보드는 dbt가 채운 marts 테이블에서 데이터를 읽습니다.

### 5. 서비스 중지

```bash
# 실행 중인 모든 서비스 중지
docker compose down

# 중지 및 데이터 볼륨 삭제 (완전 초기화)
docker compose down -v
```

### Docker 문제 해결

| 문제 | 해결 방법 |
|---|---|
| 데이터베이스 연결 거부 | 헬스체크 대기: `docker compose ps`에서 db가 "healthy"로 표시되어야 함 |
| 추출이 중간에 실패 | `docker compose --profile pipeline run --rm extraction`으로 재실행 (upsert는 멱등성 보장) |
| 대시보드에 데이터가 표시되지 않음 | 추출과 dbt가 완료되었는지 확인: `docker compose logs dbt`로 로그 확인 |
| 포트 5432가 이미 사용 중 | `.env`의 `POSTGRES_PORT` 변경 또는 로컬 PostgreSQL 중지 |
| 포트 3000이 이미 사용 중 | `.env`의 `EVIDENCE_PORT` 변경 |

---

## 로컬 개발 (Docker 없이)

### 사전 요구 사항

- Python 3.12+
- PostgreSQL 14+
- Node.js 18+ (Evidence용)
- [uv](https://docs.astral.sh/uv/) (Python 패키지 매니저)

## 설정

### 1. 데이터베이스

```bash
# 데이터베이스 및 스키마 생성
createdb mlb_data
psql mlb_data < db/schema.sql
```

### 2. Python 환경

```bash
uv sync
```

### 3. 설정 파일

PostgreSQL 자격증명에 맞게 `config.yml`을 편집하세요:

```yaml
database:
  host: localhost
  port: 5432
  dbname: mlb_data
  user: your_user
  password: your_password
```

## 사용법

### 데이터 추출

```bash
# 모든 추출 단계 실행 (의존 순서대로)
python main.py

# 특정 단계만 실행
python main.py --only teams players

# 특정 단계 건너뛰기
python main.py --skip statcast
```

추출 순서: `teams` → `players` → `schedule` → `games` → `batting_stats` → `pitching_stats` → `statcast`

### dbt 변환 실행

```bash
cd dbt_mlb

# dbt 패키지 설치
dbt deps

# 모든 모델 실행
dbt run

# 테스트 실행
dbt test
```

### 대시보드 시작

```bash
cd evidence_mlb

# 데이터베이스 자격증명 설정
export POSTGRES_USER=your_user
export POSTGRES_PASSWORD=your_password

# 의존성 설치 및 개발 서버 시작
npm install
npm run dev
```

## dbt 모델

### 스테이징 (뷰)

| 모델 | 설명 |
|---|---|
| `stg_teams` | 팀 마스터 데이터 |
| `stg_players` | 선수 기본 정보 |
| `stg_games` | 경기 결과 |
| `stg_schedule` | 시즌 일정 |
| `stg_batting_stats` | 시즌 타격 성적 |
| `stg_pitching_stats` | 시즌 투구 성적 |
| `stg_statcast` | 투구 레벨 Statcast 데이터 |

### 중간 (테이블)

| 모델 | 설명 |
|---|---|
| `int_player_season_batting` | wOBA 포함 선수-시즌 타격 집계 |
| `int_player_season_pitching` | FIP 포함 선수-시즌 투구 집계 |
| `int_game_results` | 언피벗된 경기 결과 (팀당 1행) |
| `int_team_standings` | 승률·게임차 포함 순위표 |
| `int_statcast_metrics` | Statcast 집계 (배럴률, 강타율, 평균 타구 속도) |

### 마트 (테이블)

| 모델 | 설명 |
|---|---|
| `dim_players` | 선수 디멘션 |
| `dim_teams` | 팀 디멘션 |
| `fct_batting_performance` | 타격 팩트: 기본 + 고급 지표 (wOBA, ISO, BABIP) + Statcast (xBA, xwOBA, 배럴률) |
| `fct_pitching_performance` | 투구 팩트: 기본 지표 + FIP + 피 Statcast 지표 |
| `fct_game_summary` | 투수 이름 및 파생 필드가 포함된 경기 요약 |
| `fct_statcast_leaders` | EV·배럴률·강타율·xwOBA 순위가 포함된 Statcast 리더보드 |
| `fct_team_season_summary` | 피타고라스 승률 예측이 포함된 팀 시즌 요약 |

## 대시보드 페이지

| 페이지 | 설명 |
|---|---|
| **개요** | KPI 카드, 팀 승률 막대 차트, 최근 경기, 득실차 산점도 |
| **타격 리더** | OPS·wOBA·HR·SB 리더보드 (포지션/팀 필터 포함) |
| **투구 리더** | ERA·FIP·WHIP·삼진 리더보드 (선발/불펜 필터 포함) |
| **팀 순위** | 지구별 순위, 팀 OPS/ERA 비교, 피타고라스 분석 |
| **Statcast 인사이트** | 타구 속도·배럴률·강타율 리더 (산점도 포함) |
| **선수 프로필** | 개별 선수 페이지 (성적·Statcast 지표·트렌드 차트) |

## 테스트

프로젝트에는 3개 레이어에 걸친 약 147개의 자동화 테스트가 포함되어 있습니다:

```bash
# dbt 스키마 + 단위 테스트 (~102개 테스트)
cd dbt_mlb && dbt test

# E2E 파이프라인 테스트 (45개 테스트)
cd .. && python -m pytest tests/test_e2e_pipeline.py -v
```

테스트 카테고리:
- **스키마 테스트** — 고유성, 비NULL, 허용 값, 참조 무결성
- **단위 테스트** — 타율 범위, ERA 유효성, OPS 일관성, 피타고라스 합리성
- **E2E 테스트** — raw에서 marts까지의 데이터 추적성, 계산 정확도, NULL 비율 임계값

## 라이선스

이 프로젝트는 **GNU General Public License v3.0 (GPL-3.0)** 하에 라이선스됩니다 — 자세한 내용은 [LICENSE](LICENSE) 파일을 참조하세요.

GPL-3.0은 [MLB-StatsAPI](https://github.com/toddrob99/MLB-StatsAPI) 의존성(GPL-3.0 카피레프트)으로 인해 필요합니다.

### 데이터 사용 제한

MLB Stats API를 통해 접근하는 MLB 데이터는 [MLB Advanced Media의 이용약관](http://gdx.mlb.com/components/copyright.txt)에 따라 **개인·비상업·비대량 사용**으로 제한됩니다. 상업적 사용은 MLBAM의 사전 서면 승인이 필요합니다.

제3자 귀속에 대한 전체 내용은 [NOTICE](NOTICE)를 참조하세요.
