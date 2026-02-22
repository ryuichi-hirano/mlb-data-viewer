# MLB Data Viewer

[English](README.md) | [日本語](README.ja.md) | [Español](README.es.md) | [한국어](README.ko.md)

MLB Stats APIとBaseball Savantからデータを抽出し、dbtデータウェアハウスで変換し、Evidenceによるインタラクティブなダッシュボードを提供するエンドツーエンドのMLB分析パイプラインです。

## アーキテクチャ

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

**データソース:**
- [MLB Stats API](https://statsapi.mlb.com) — チーム、選手、試合、スケジュール、打撃/投球シーズン統計
- [Baseball Savant](https://baseballsavant.mlb.com) (pybaseballを使用) — 投球レベルのStatcastデータ（打球速度、打球角度、スピン率など）

## 主な機能

- **7つの抽出スクリプト** — チーム、選手、スケジュール、試合、打撃成績、投球成績、Statcastデータを収集
- **19のdbtモデル** — 3つのレイヤー（ステージング、中間、マーツ）にわたり、高度な指標（wOBA、FIP、ピタゴラス勝率、バレル率）を算出
- **6ページのEvidenceダッシュボード** — インタラクティブなフィルター、リーダーボード、ビジュアライゼーション
- **約147の自動テスト** — dbtスキーマテスト、単体テスト、E2Eパイプラインテスト

## プロジェクト構成

```
mlb_data_viewer/
├── config.yml                  # データベース・抽出設定
├── config.docker.yml           # Docker設定（host: db）
├── docker-compose.yml          # マルチコンテナオーケストレーション
├── .env.example                # 環境変数テンプレート
├── pyproject.toml              # Python依存関係（uv）
├── main.py                     # エントリーポイント
│
├── docker/                     # Dockerビルドコンテキスト
│   ├── db/init.sql             # DB初期化（スキーマ＋シードデータ）
│   ├── extraction/Dockerfile   # Python抽出コンテナ
│   ├── dbt/Dockerfile          # dbt変換コンテナ
│   └── evidence/Dockerfile     # Evidenceダッシュボードコンテナ
│
├── db/
│   └── schema.sql              # PostgreSQL DDL（7つのrawテーブル、インデックス）
│
├── scripts/                    # Python抽出スクリプト
│   ├── utils.py                # DB接続、ログ、リトライデコレータ
│   ├── extract_teams.py        # → raw_mlb.raw_teams
│   ├── extract_players.py      # → raw_mlb.raw_players
│   ├── extract_schedule.py     # → raw_mlb.raw_schedule
│   ├── extract_games.py        # → raw_mlb.raw_games
│   ├── extract_batting_stats.py  # → raw_mlb.raw_batting_stats
│   ├── extract_pitching_stats.py # → raw_mlb.raw_pitching_stats
│   ├── extract_statcast.py     # → raw_mlb.raw_statcast（pybaseball）
│   └── run_extraction.py       # オーケストレーター（--skip / --onlyフラグ）
│
├── dbt_mlb/                    # dbtプロジェクト
│   ├── dbt_project.yml
│   ├── profiles.yml
│   ├── models/
│   │   ├── staging/            # 7ビュー — rawカラムのクリーニングとリネーム
│   │   ├── intermediate/       # 5テーブル — ビジネスロジックと集計
│   │   └── marts/              # 7テーブル — 分析用ディメンションとファクト
│   └── tests/                  # 8つの単体SQLテスト
│
├── evidence_mlb/               # Evidenceダッシュボード
│   ├── evidence.config.yaml
│   ├── sources/mlb/            # PostgreSQL接続
│   └── pages/                  # 6ダッシュボードページ
│
├── tests/
│   └── test_e2e_pipeline.py    # 45のE2Eテスト（6テストクラス）
│
└── docs/
    ├── api_endpoints.md        # MLB APIドキュメント
    └── qa_report.md            # QAテストカバレッジレポート
```

## クイックスタート（Docker）

Docker Composeを使うのが最も簡単な方法です。PostgreSQLのセットアップ、データパイプラインの実行、ダッシュボードの起動をすべて自動で行います。

### 前提条件

- [Docker](https://docs.docker.com/get-docker/)（20.10以上）
- [Docker Compose](https://docs.docker.com/compose/install/)（v2以上）

### 1. 環境設定

```bash
cp .env.example .env
```

必要に応じて `.env` を編集してください（デフォルト値でそのまま動作します）:

```env
POSTGRES_USER=mlb_user
POSTGRES_PASSWORD=mlb_password
POSTGRES_DB=mlb_data
EVIDENCE_PORT=3000
```

### 2. データベースとダッシュボードの起動

```bash
docker compose up -d
```

起動されるサービス:
- **db** — スキーマ自動初期化付きPostgreSQL 16
- **evidence** — ダッシュボード（[http://localhost:3000](http://localhost:3000)）

### 3. データパイプラインの実行

抽出とdbtのステップは `pipeline` プロファイル配下のワンショットジョブです:

```bash
# MLB Stats APIからデータを抽出（初回は時間がかかります）
docker compose --profile pipeline run --rm extraction

# dbt変換を実行（raw → staging → intermediate → marts）
docker compose --profile pipeline run --rm dbt
```

Statcastデータ（最も時間がかかるステップ）をスキップする場合:

```bash
docker compose --profile pipeline run --rm extraction --skip statcast
```

### 4. ダッシュボードへのアクセス

ブラウザで [http://localhost:3000](http://localhost:3000) を開いてください。ダッシュボードはdbtが生成したmartsテーブルからデータを読み込みます。

### 5. サービスの停止

```bash
# 実行中のサービスをすべて停止
docker compose down

# 停止してデータボリュームも削除（完全リセット）
docker compose down -v
```

### Dockerトラブルシューティング

| 問題 | 解決方法 |
|---|---|
| データベース接続が拒否される | ヘルスチェックを待つ: `docker compose ps` でdbが"healthy"になっていることを確認 |
| 抽出が途中で失敗する | `docker compose --profile pipeline run --rm extraction` で再実行（アップサートは冪等） |
| ダッシュボードにデータが表示されない | 抽出とdbtが完了していることを確認: `docker compose logs dbt` でログを確認 |
| ポート5432がすでに使用中 | `.env` の `POSTGRES_PORT` を変更するか、ローカルのPostgreSQLを停止 |
| ポート3000がすでに使用中 | `.env` の `EVIDENCE_PORT` を変更 |

---

## ローカル開発（Dockerなし）

### 前提条件

- Python 3.12以上
- PostgreSQL 14以上
- Node.js 18以上（Evidence用）
- [uv](https://docs.astral.sh/uv/)（Pythonパッケージマネージャー）

## セットアップ

### 1. データベース

```bash
# データベースとスキーマを作成
createdb mlb_data
psql mlb_data < db/schema.sql
```

### 2. Python環境

```bash
uv sync
```

### 3. 設定

`config.yml` をPostgreSQL認証情報に合わせて編集:

```yaml
database:
  host: localhost
  port: 5432
  dbname: mlb_data
  user: your_user
  password: your_password
```

## 使い方

### データの抽出

```bash
# すべての抽出ステップを実行（依存順）
python main.py

# 特定のステップのみ実行
python main.py --only teams players

# 特定のステップをスキップ
python main.py --skip statcast
```

抽出順序: `teams` → `players` → `schedule` → `games` → `batting_stats` → `pitching_stats` → `statcast`

### dbt変換の実行

```bash
cd dbt_mlb

# dbtパッケージのインストール
dbt deps

# すべてのモデルを実行
dbt run

# テストの実行
dbt test
```

### ダッシュボードの起動

```bash
cd evidence_mlb

# データベース認証情報を設定
export POSTGRES_USER=your_user
export POSTGRES_PASSWORD=your_password

# 依存関係のインストールと開発サーバーの起動
npm install
npm run dev
```

## dbtモデル

### ステージング（ビュー）

| モデル | 説明 |
|---|---|
| `stg_teams` | チームマスターデータ |
| `stg_players` | 選手の基本情報 |
| `stg_games` | 試合結果 |
| `stg_schedule` | シーズンスケジュール |
| `stg_batting_stats` | シーズン打撃成績 |
| `stg_pitching_stats` | シーズン投球成績 |
| `stg_statcast` | 投球レベルのStatcastデータ |

### 中間（テーブル）

| モデル | 説明 |
|---|---|
| `int_player_season_batting` | wOBA付き選手シーズン打撃集計 |
| `int_player_season_pitching` | FIP付き選手シーズン投球集計 |
| `int_game_results` | アンピボット済み試合結果（チームごと1行） |
| `int_team_standings` | 勝率・ゲーム差付き順位表 |
| `int_statcast_metrics` | Statcast集計（バレル率、ハードヒット率、平均打球速度） |

### マーツ（テーブル）

| モデル | 説明 |
|---|---|
| `dim_players` | 選手ディメンション |
| `dim_teams` | チームディメンション |
| `fct_batting_performance` | 打撃ファクト: 基本指標＋上級指標（wOBA、ISO、BABIP）＋Statcast（xBA、xwOBA、バレル率） |
| `fct_pitching_performance` | 投球ファクト: 基本指標＋FIP＋被Statcast指標 |
| `fct_game_summary` | 投手名と派生フィールド付きの試合サマリー |
| `fct_statcast_leaders` | 打球速度・バレル率・ハードヒット率・xwOBAによるランキング付きStatcastリーダーボード |
| `fct_team_season_summary` | ピタゴラス勝率予測付きチームシーズンサマリー |

## ダッシュボードページ

| ページ | 説明 |
|---|---|
| **概要** | KPIカード、チーム勝率棒グラフ、直近の試合、得失点差散布図 |
| **打撃リーダー** | OPS・wOBA・HR・SBリーダーボード（ポジション・チームフィルター付き） |
| **投球リーダー** | ERA・FIP・WHIP・奪三振リーダーボード（先発・リリーフフィルター付き） |
| **チーム順位** | 地区順位、チームOPS/ERA比較、ピタゴラス分析 |
| **Statcastインサイト** | 打球速度・バレル率・ハードヒット率リーダー（散布図付き） |
| **選手プロフィール** | 個別選手ページ（成績・Statcast指標・トレンドチャート） |

## テスト

プロジェクトには3つのレイヤーにわたる約147の自動テストが含まれています:

```bash
# dbtスキーマ＋単体テスト（約102テスト）
cd dbt_mlb && dbt test

# E2Eパイプラインテスト（45テスト）
cd .. && python -m pytest tests/test_e2e_pipeline.py -v
```

テストの種類:
- **スキーマテスト** — 一意性、非NULL、許容値、参照整合性
- **単体テスト** — 打率範囲、ERA妥当性、OPS整合性、ピタゴラス妥当性
- **E2Eテスト** — rawからmartsへのデータ追跡可能性、計算精度、NULL率閾値

## ライセンス

このプロジェクトは **GNU General Public License v3.0 (GPL-3.0)** のもとでライセンスされています — 詳細は [LICENSE](LICENSE) ファイルを参照してください。

GPL-3.0は [MLB-StatsAPI](https://github.com/toddrob99/MLB-StatsAPI) 依存関係（GPL-3.0コピーレフト）によって必要とされます。

### データ利用規約

MLB Stats APIを通じてアクセスするMLBデータは、[MLB Advanced Mediaの利用規約](http://gdx.mlb.com/components/copyright.txt)に基づき、**個人・非商用・非大量利用**に限定されています。商用利用にはMLBAMからの事前書面による承認が必要です。

サードパーティの帰属については [NOTICE](NOTICE) を参照してください。
