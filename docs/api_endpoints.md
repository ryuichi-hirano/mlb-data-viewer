# MLB Stats API / Statcast API エンドポイント調査ドキュメント

> 調査日: 2026-02-08
> 対象: MLB Stats API (statsapi.mlb.com) および Baseball Savant Statcast データ

---

## 目次

1. [API概要](#1-api概要)
2. [MLB Stats API エンドポイント一覧](#2-mlb-stats-api-エンドポイント一覧)
3. [Baseball Savant / Statcast API](#3-baseball-savant--statcast-api)
4. [Pythonライブラリ](#4-pythonライブラリ)
5. [レート制限・ページネーション](#5-レート制限ページネーション)
6. [推奨データ取得戦略](#6-推奨データ取得戦略)

---

## 1. API概要

### MLB Stats API

| 項目 | 詳細 |
|------|------|
| Base URL | `https://statsapi.mlb.com/api/v1/` |
| 認証 | 不要（公開API） |
| レスポンス形式 | JSON |
| APIバージョン | v1（一部エンドポイントは v1.1） |
| 公式ドキュメント | https://docs.statsapi.mlb.com/ （ログイン必要） |

### Baseball Savant (Statcast)

| 項目 | 詳細 |
|------|------|
| Base URL | `https://baseballsavant.mlb.com/` |
| 認証 | 不要 |
| レスポンス形式 | CSV |
| データ開始年 | 2008年（Statcast導入）/ 2015年〜（launch angle等の完全データ） |
| 行数上限 | 1クエリあたり最大 25,000〜30,000行 |

---

## 2. MLB Stats API エンドポイント一覧

### 2.1 選手 (People/Person)

#### 選手一覧取得
```
GET /api/v1/people?personIds={id1,id2,...}
```

| パラメータ | 必須 | 説明 |
|-----------|------|------|
| `personIds` | Yes | カンマ区切りの選手ID |
| `hydrate` | No | 追加データ取得（例: `stats`, `currentTeam`） |
| `fields` | No | 返却フィールドの絞り込み |

**レスポンス構造:**
```json
{
  "copyright": "...",
  "people": [
    {
      "id": 660271,
      "fullName": "Shohei Ohtani",
      "firstName": "Shohei",
      "lastName": "Ohtani",
      "primaryNumber": "17",
      "birthDate": "1994-07-05",
      "currentAge": 31,
      "birthCity": "Oshu",
      "birthCountry": "Japan",
      "height": "6' 4\"",
      "weight": 210,
      "active": true,
      "primaryPosition": {
        "code": "Y",
        "name": "Two-Way Player",
        "type": "TWP",
        "abbreviation": "TWP"
      },
      "useName": "Shohei",
      "batSide": {"code": "L", "description": "Left"},
      "pitchHand": {"code": "R", "description": "Right"},
      "currentTeam": {"id": 119, "name": "Los Angeles Dodgers"},
      "mlbDebutDate": "2018-03-29",
      "draftYear": null
    }
  ]
}
```

#### 個別選手取得
```
GET /api/v1/people/{personId}
```

| パラメータ | 必須 | 説明 |
|-----------|------|------|
| `personId` | Yes (path) | 選手のMLB ID |
| `hydrate` | No | 追加データ（例: `stats(group=[hitting],type=[career])`） |

#### 選手成績（特定試合）
```
GET /api/v1/people/{personId}/stats/game/{gamePk}
```

#### 選手変更履歴
```
GET /api/v1/people/changes?updatedSince={timestamp}
```

#### フリーエージェント一覧
```
GET /api/v1/people/freeAgents?leagueId={leagueId}
```

---

### 2.2 チーム (Teams)

#### チーム一覧
```
GET /api/v1/teams?sportId=1
```

| パラメータ | 必須 | 説明 |
|-----------|------|------|
| `sportId` | No | スポーツID（1 = MLB） |
| `season` | No | シーズン年度 |
| `activeStatus` | No | アクティブ状態フィルタ |
| `leagueIds` | No | リーグIDフィルタ |
| `hydrate` | No | 追加データ |

**レスポンス構造:**
```json
{
  "copyright": "...",
  "teams": [
    {
      "id": 133,
      "name": "Oakland Athletics",
      "link": "/api/v1/teams/133",
      "season": 2025,
      "venue": {
        "id": 10,
        "name": "Oakland Coliseum",
        "link": "/api/v1/venues/10"
      },
      "teamCode": "oak",
      "fileCode": "oak",
      "abbreviation": "OAK",
      "teamName": "Athletics",
      "locationName": "Oakland",
      "shortName": "Oakland",
      "league": {"id": 103, "name": "American League"},
      "division": {"id": 200, "name": "American League West"},
      "sport": {"id": 1, "name": "Major League Baseball"},
      "active": true
    }
  ]
}
```

#### 個別チーム
```
GET /api/v1/teams/{teamId}
```

#### チームロスター
```
GET /api/v1/teams/{teamId}/roster
```

| パラメータ | 必須 | 説明 |
|-----------|------|------|
| `teamId` | Yes (path) | チームID |
| `rosterType` | No | ロスター種別（`40Man`, `active`, `fullSeason` 等） |
| `season` | No | シーズン年度 |
| `date` | No | 日付指定 |

#### チーム成績
```
GET /api/v1/teams/{teamId}/stats
```

| パラメータ | 必須 | 説明 |
|-----------|------|------|
| `teamId` | Yes (path) | チームID |
| `season` | Yes | シーズン年度 |
| `group` | Yes | 統計グループ（`hitting`, `pitching`, `fielding`） |
| `stats` | No | 統計タイプ |

#### チームリーダー
```
GET /api/v1/teams/{teamId}/leaders
```

#### チームコーチ
```
GET /api/v1/teams/{teamId}/coaches
```

#### チーム履歴
```
GET /api/v1/teams/history?teamIds={ids}
```

#### チーム傘下組織
```
GET /api/v1/teams/affiliates?teamIds={ids}
```

---

### 2.3 試合 (Game)

#### ライブフィード（全試合データ）
```
GET /api/v1.1/game/{gamePk}/feed/live
```

| パラメータ | 必須 | 説明 |
|-----------|------|------|
| `gamePk` | Yes (path) | ゲームの一意ID |
| `timecode` | No | 特定時点のデータ取得 |
| `hydrate` | No | 追加データ |

**レスポンス構造（主要キー）:**
```json
{
  "copyright": "...",
  "gamePk": 718590,
  "link": "/api/v1.1/game/718590/feed/live",
  "metaData": {
    "wait": 10,
    "timeStamp": "20250401_123456",
    "gameEvents": ["strikeout", "home_run"],
    "logicalEvents": ["midInning", "countChange"]
  },
  "gameData": {
    "game": {"pk": 718590, "type": "R", "season": "2025"},
    "datetime": {"dateTime": "2025-04-01T17:10:00Z", "officialDate": "2025-04-01"},
    "status": {"detailedState": "In Progress", "statusCode": "I"},
    "teams": {
      "away": {"id": 147, "name": "New York Yankees", "abbreviation": "NYY"},
      "home": {"id": 111, "name": "Boston Red Sox", "abbreviation": "BOS"}
    },
    "players": {"ID660271": {"id": 660271, "fullName": "Shohei Ohtani", ...}},
    "venue": {"id": 3, "name": "Fenway Park"},
    "weather": {"condition": "Clear", "temp": "72", "wind": "10 mph, Out To CF"}
  },
  "liveData": {
    "plays": {
      "allPlays": [...],
      "currentPlay": {...},
      "scoringPlays": [0, 3, 7]
    },
    "linescore": {
      "currentInning": 5,
      "inningHalf": "Top",
      "innings": [{"num": 1, "home": {"runs": 1}, "away": {"runs": 0}}],
      "teams": {
        "home": {"runs": 3, "hits": 7, "errors": 0},
        "away": {"runs": 2, "hits": 5, "errors": 1}
      }
    },
    "boxscore": {
      "teams": {
        "away": {"players": {...}, "battingOrder": [...], "stats": {...}},
        "home": {"players": {...}, "battingOrder": [...], "stats": {...}}
      }
    },
    "decisions": {
      "winner": {"id": 123456, "fullName": "..."},
      "loser": {"id": 654321, "fullName": "..."}
    }
  }
}
```

#### ボックススコア
```
GET /api/v1/game/{gamePk}/boxscore
```

#### ラインスコア
```
GET /api/v1/game/{gamePk}/linescore
```

#### プレイバイプレイ
```
GET /api/v1/game/{gamePk}/playByPlay
```

**playByPlay レスポンスの主要構造:**
```json
{
  "allPlays": [
    {
      "result": {
        "type": "atBat",
        "event": "Strikeout",
        "eventType": "strikeout",
        "description": "...",
        "rbi": 0,
        "awayScore": 0,
        "homeScore": 0
      },
      "about": {
        "atBatIndex": 0,
        "halfInning": "top",
        "inning": 1,
        "startTime": "2025-04-01T17:12:00Z",
        "endTime": "2025-04-01T17:15:30Z",
        "isComplete": true
      },
      "count": {"balls": 1, "strikes": 3, "outs": 1},
      "matchup": {
        "batter": {"id": 660271, "fullName": "..."},
        "pitcher": {"id": 543037, "fullName": "..."},
        "batSide": {"code": "L"},
        "pitchHand": {"code": "R"}
      },
      "pitchIndex": [0, 1, 2, 3],
      "actionIndex": [],
      "runnerIndex": [],
      "runners": [...],
      "playEvents": [
        {
          "details": {
            "call": {"code": "S", "description": "Called Strike"},
            "description": "Called Strike",
            "ballColor": "rgba(170, 21, 11, 1.0)",
            "isInPlay": false,
            "isStrike": true,
            "isBall": false,
            "type": {"code": "FF", "description": "Four-Seam Fastball"}
          },
          "count": {"balls": 0, "strikes": 1, "outs": 0},
          "pitchData": {
            "startSpeed": 96.5,
            "endSpeed": 88.2,
            "zone": 5,
            "coordinates": {"x": 100.5, "y": 160.3},
            "breaks": {"breakAngle": 25.2, "spinRate": 2350}
          },
          "index": 0,
          "isPitch": true,
          "type": "pitch"
        }
      ]
    }
  ]
}
```

#### 勝率推移
```
GET /api/v1/game/{gamePk}/winProbability
```

#### コンテキスト指標
```
GET /api/v1/game/{gamePk}/contextMetrics
```

#### 試合コンテンツ（ハイライト等）
```
GET /api/v1/game/{gamePk}/content
```

#### 差分取得（ライブ更新用）
```
GET /api/v1.1/game/{gamePk}/feed/live/diffPatch
    ?startTimecode={start}&endTimecode={end}
```

#### タイムスタンプ取得
```
GET /api/v1.1/game/{gamePk}/feed/live/timestamps
```

---

### 2.4 スケジュール (Schedule)

#### 日程取得
```
GET /api/v1/schedule?sportId=1
```

| パラメータ | 必須 | 説明 |
|-----------|------|------|
| `sportId` | Yes* | スポーツID（1 = MLB）。gamePk/gamePks指定時は不要 |
| `date` | No | 単一日付（MM/DD/YYYY） |
| `startDate` | No | 期間開始日 |
| `endDate` | No | 期間終了日 |
| `season` | No | シーズン年度 |
| `teamId` | No | チームIDフィルタ |
| `gameTypes` | No | 試合種別（R, S, P, W 等） |
| `hydrate` | No | 追加データ（例: `team,linescore,decisions`） |

**レスポンス構造:**
```json
{
  "copyright": "...",
  "totalItems": 15,
  "totalEvents": 0,
  "totalGames": 15,
  "totalGamesInProgress": 2,
  "dates": [
    {
      "date": "2025-04-01",
      "totalItems": 15,
      "totalEvents": 0,
      "totalGames": 15,
      "games": [
        {
          "gamePk": 718590,
          "link": "/api/v1.1/game/718590/feed/live",
          "gameType": "R",
          "season": "2025",
          "gameDate": "2025-04-01T17:10:00Z",
          "officialDate": "2025-04-01",
          "status": {
            "abstractGameState": "Final",
            "codedGameState": "F",
            "detailedState": "Final",
            "statusCode": "F"
          },
          "teams": {
            "away": {
              "score": 3,
              "team": {"id": 147, "name": "New York Yankees"},
              "isWinner": true
            },
            "home": {
              "score": 2,
              "team": {"id": 111, "name": "Boston Red Sox"},
              "isWinner": false
            }
          },
          "venue": {"id": 3, "name": "Fenway Park"}
        }
      ]
    }
  ]
}
```

#### ポストシーズン日程
```
GET /api/v1/schedule/postseason
GET /api/v1/schedule/postseason/series
```

#### タイゲーム
```
GET /api/v1/schedule/games/tied?season={year}
```

---

### 2.5 成績・統計 (Stats)

#### リーグ統計
```
GET /api/v1/stats?stats={statType}&group={group}
```

| パラメータ | 必須 | 説明 |
|-----------|------|------|
| `stats` | Yes | 統計タイプ（下記参照） |
| `group` | Yes | 統計グループ（`hitting`, `pitching`, `fielding`） |
| `season` | No | シーズン年度 |
| `gameType` | No | 試合種別 |
| `playerPool` | No | `all`, `qualified`, `rookies` |
| `sportIds` | No | スポーツID |
| `limit` | No | 返却件数上限 |
| `offset` | No | オフセット（ページネーション） |
| `sortStat` | No | ソート対象の統計項目 |
| `order` | No | ソート順（`asc`, `desc`） |
| `personId` | No | 特定選手の統計 |
| `teamId` | No | チームフィルタ |
| `startDate` | No | 期間開始日 |
| `endDate` | No | 期間終了日 |

**利用可能な statType（主要なもの）:**
- `season` — シーズン成績
- `career` — 通算成績
- `byDateRange` — 日付範囲指定
- `byMonth` — 月別
- `byDayOfWeek` — 曜日別
- `statsSingleSeason` — 単シーズン（リーダー取得時に使用）
- `hotColdZones` — ゾーン別打撃データ
- `expectedStatistics` — 予想統計（xBA, xSLG等）
- `sapiPitchingMetrics` — 投球指標
- `sapiFieldingMetrics` — 守備指標

**利用可能な group:**
- `hitting` — 打撃
- `pitching` — 投球
- `fielding` — 守備
- `catching` — 捕手指標
- `running` — 走塁

> **メタデータ取得:** 有効な値は `/api/v1/statTypes` および `/api/v1/statGroups` から取得可能

#### リーダーボード
```
GET /api/v1/stats/leaders?leaderCategories={category}
```

| パラメータ | 必須 | 説明 |
|-----------|------|------|
| `leaderCategories` | Yes | カテゴリ名（例: `homeRuns`, `earnedRunAverage`） |
| `season` | No | シーズン |
| `leaderGameTypes` | No | 試合種別 |
| `statGroup` | No | 統計グループ |
| `limit` | No | 返却件数 |

#### ストリーク
```
GET /api/v1/stats/streaks?streakType={type}&streakSpan={span}&season={year}&sportId=1&limit={n}
```

---

### 2.6 順位表 (Standings)

```
GET /api/v1/standings?leagueId={id}
```

| パラメータ | 必須 | 説明 |
|-----------|------|------|
| `leagueId` | Yes | リーグID（103=AL, 104=NL） |
| `season` | No | シーズン |
| `standingsTypes` | No | 種別（`regularSeason`, `wildCard`, `springTraining`等） |
| `date` | No | 特定日付時点の順位 |
| `hydrate` | No | 追加データ |

**レスポンス構造:**
```json
{
  "copyright": "...",
  "records": [
    {
      "standingsType": "regularSeason",
      "league": {"id": 103, "name": "American League"},
      "division": {"id": 201, "name": "American League East"},
      "teamRecords": [
        {
          "team": {"id": 147, "name": "New York Yankees"},
          "season": "2025",
          "wins": 95,
          "losses": 67,
          "winningPercentage": ".586",
          "gamesBack": "-",
          "wildCardGamesBack": "-",
          "divisionRank": "1",
          "leagueRank": "2",
          "streak": {"streakCode": "W3"},
          "runsScored": 780,
          "runsAllowed": 650,
          "runDifferential": 130,
          "records": {
            "splitRecords": [
              {"type": "home", "wins": 50, "losses": 31},
              {"type": "away", "wins": 45, "losses": 36},
              {"type": "lastTen", "wins": 7, "losses": 3}
            ]
          }
        }
      ]
    }
  ]
}
```

---

### 2.7 リーグ・ディビジョン・シーズン

#### リーグ
```
GET /api/v1/league?sportId=1
```

#### ディビジョン
```
GET /api/v1/divisions?sportId=1
```

#### シーズン情報
```
GET /api/v1/seasons/all?sportId=1
GET /api/v1/seasons/{seasonId}?sportId=1
```

---

### 2.8 その他のエンドポイント

#### トランザクション（移籍・DFA等）
```
GET /api/v1/transactions?startDate={start}&endDate={end}
```

#### ドラフト
```
GET /api/v1/draft/{year}
GET /api/v1/draft/prospects/{year}
```

#### アワード
```
GET /api/v1/awards?awardId={id}&season={year}
```

#### 球場情報
```
GET /api/v1/venues?venueIds={ids}
```

#### 審判・職員
```
GET /api/v1/jobs/umpires
GET /api/v1/jobs/datacasters
```

#### ゲームペース
```
GET /api/v1/gamePace?season={year}
```

#### 出席者数
```
GET /api/v1/attendance?teamId={id}&season={year}
```

#### メタデータ（有効値リスト）
```
GET /api/v1/{type}
```

利用可能な type:
`awards`, `baseballStats`, `eventTypes`, `gameStatus`, `gameTypes`, `hitTrajectories`, `jobTypes`, `languages`, `leagueLeaderTypes`, `logicalEvents`, `metrics`, `pitchCodes`, `pitchTypes`, `platforms`, `positions`, `reviewReasons`, `rosterTypes`, `scheduleEventTypes`, `situationCodes`, `sky`, `standingsTypes`, `statGroups`, `statTypes`, `windDirection`

---

### 2.9 hydrate パラメータ

`hydrate` パラメータを使用すると、1回のAPIコールで関連データを追加取得できる。

**使用例:**
```
GET /api/v1/people/660271?hydrate=stats(group=[hitting],type=[career]),currentTeam
GET /api/v1/schedule?sportId=1&date=04/01/2025&hydrate=team,linescore,decisions,probablePitcher
GET /api/v1/teams/147?hydrate=roster(season=2025)
```

**利用可能なハイドレーション一覧の取得:**
```
GET /api/v1/{endpoint}?hydrate=hydrations
```

---

### 2.10 主要チーム・リーグID一覧

**リーグID:**

| リーグ | ID |
|--------|-----|
| American League | 103 |
| National League | 104 |

**主要チームID（抜粋）:**

| チーム | ID | 略称 |
|--------|-----|------|
| Los Angeles Dodgers | 119 | LAD |
| New York Yankees | 147 | NYY |
| Boston Red Sox | 111 | BOS |
| Chicago Cubs | 112 | CHC |
| San Francisco Giants | 137 | SF |
| Houston Astros | 117 | HOU |
| Atlanta Braves | 144 | ATL |
| Philadelphia Phillies | 143 | PHI |
| San Diego Padres | 135 | SD |
| Texas Rangers | 140 | TEX |

> 全チーム一覧は `GET /api/v1/teams?sportId=1` で取得可能

**試合種別 (gameType):**

| コード | 説明 |
|--------|------|
| S | Spring Training |
| R | Regular Season |
| F | Wild Card |
| D | Division Series |
| L | Championship Series |
| W | World Series |
| E | Exhibition |
| A | All-Star Game |

---

## 3. Baseball Savant / Statcast API

### 3.1 Statcast Search CSV エンドポイント

#### ベースURL
```
https://baseballsavant.mlb.com/statcast_search/csv?all=true
```

#### クエリパラメータ

| パラメータ | 説明 | 例 |
|-----------|------|-----|
| `hfPT` | 投球種別フィルタ | `FF|SL|` (Four-seam, Slider) |
| `hfAB` | 打席結果フィルタ | `single|double|home_run|` |
| `hfBBT` | 打球種別フィルタ | `fly_ball|line_drive|` |
| `hfPR` | 投球結果フィルタ | `` |
| `hfZ` | ゾーンフィルタ | `` |
| `hfGT` | 試合種別 | `R|`（レギュラーシーズン） |
| `hfSea` | シーズン | `2025|` |
| `hfSit` | シチュエーション | `` |
| `player_type` | `pitcher` or `batter` | `pitcher` |
| `hfOuts` | アウトカウント | `` |
| `pitcher_throws` | 投手の利き手 | `R` or `L` |
| `batter_stands` | 打者の打席 | `R` or `L` |
| `game_date_gt` | 開始日 | `2025-04-01` |
| `game_date_lt` | 終了日 | `2025-10-01` |
| `team` | チーム略称 | `LAD` |
| `position` | ポジション | `` |
| `min_pitches` | 最少投球数 | `0` |
| `min_results` | 最少打席結果 | `0` |
| `group_by` | グループ化 | `name`, `name-event` |
| `sort_col` | ソートカラム | `pitches`, `xba` |
| `sort_order` | ソート順 | `desc` |
| `type` | 出力タイプ | `details`（投球レベル） |

**クエリ例（投手別の全投球データ）:**
```
https://baseballsavant.mlb.com/statcast_search/csv?all=true
  &hfPT=
  &hfAB=
  &hfGT=R|
  &hfSea=2025|
  &player_type=pitcher
  &game_date_gt=2025-04-01
  &game_date_lt=2025-04-30
  &min_pitches=0
  &min_results=0
  &group_by=name
  &sort_col=pitches
  &sort_order=desc
  &type=details
```

### 3.2 Statcast CSVフィールド一覧

#### 投球データ (Pitch-Level)

| フィールド名 | 説明 | データ型 |
|-------------|------|---------|
| `pitch_type` | Statcast由来の投球種別コード | str |
| `pitch_name` | 投球種別名称 | str |
| `game_date` | 試合日 | date |
| `release_speed` | リリースポイントでの球速 (mph) | float |
| `release_pos_x` | 水平リリース位置 (ft) | float |
| `release_pos_y` | 前後リリース位置 (ft) | float |
| `release_pos_z` | 垂直リリース位置 (ft) | float |
| `release_spin` | スピンレート (rpm) | int |
| `release_extension` | リリースエクステンション (ft) | float |
| `spin_axis` | スピン軸 (0-360度) | float |
| `effective_speed` | エクステンション考慮の実効球速 | float |
| `pfx_x` | 水平変化量 (ft) | float |
| `pfx_z` | 垂直変化量 (ft) | float |
| `plate_x` | ホームプレート通過時の水平位置 (ft) | float |
| `plate_z` | ホームプレート通過時の垂直位置 (ft) | float |
| `zone` | ストライクゾーンの区画番号 | int |
| `vx0` | 投球速度 x成分 (ft/s, y=50ft地点) | float |
| `vy0` | 投球速度 y成分 (ft/s) | float |
| `vz0` | 投球速度 z成分 (ft/s) | float |
| `ax` | 投球加速度 x成分 (ft/s²) | float |
| `ay` | 投球加速度 y成分 (ft/s²) | float |
| `az` | 投球加速度 z成分 (ft/s²) | float |

#### 打球データ (Batted Ball)

| フィールド名 | 説明 | データ型 |
|-------------|------|---------|
| `launch_speed` | 打球速度 (mph) | float |
| `launch_angle` | 打球角度 (度) | float |
| `launch_speed_angle` | 速度×角度ゾーン（1-6） | int |
| `hit_distance` | 推定飛距離 (ft) | float |
| `bb_type` | 打球種別 (`ground_ball`, `line_drive`, `fly_ball`, `popup`) | str |
| `hc_x` | 打球着弾X座標 | float |
| `hc_y` | 打球着弾Y座標 | float |
| `hit_location` | 最初に触球した野手番号 | int |
| `estimated_ba_using_speedangle` | xBA（予想打率） | float |
| `estimated_woba_using_speedangle` | xwOBA（予想wOBA） | float |

#### 試合情報 (Game Context)

| フィールド名 | 説明 | データ型 |
|-------------|------|---------|
| `game_pk` | 試合の一意ID | int |
| `game_year` | シーズン年度 | int |
| `game_type` | 試合種別 (R/S/E/D/L/W/A) | str |
| `player_name` | 選手名 | str |
| `batter` | 打者のMLB ID | int |
| `pitcher` | 投手のMLB ID | int |
| `events` | 打席結果イベント | str |
| `description` | 投球結果の説明 | str |
| `des` | 打席全体の説明 | str |
| `stand` | 打者の打席（L/R） | str |
| `p_throws` | 投手の利き手（L/R） | str |
| `home_team` | ホームチーム略称 | str |
| `away_team` | アウェイチーム略称 | str |
| `type` | 投球結果（B=ボール, S=ストライク, X=インプレー） | str |
| `balls` | 投球前のボールカウント | int |
| `strikes` | 投球前のストライクカウント | int |
| `outs_when_up` | 投球前のアウトカウント | int |
| `inning` | イニング番号 | int |
| `inning_topbot` | 表裏 (Top/Bot) | str |
| `at_bat_number` | 試合内の打席番号 | int |
| `pitch_number` | 打席内の投球番号 | int |

#### 走者・得点 (Runners/Scoring)

| フィールド名 | 説明 | データ型 |
|-------------|------|---------|
| `on_1b` | 一塁走者のMLB ID | int/null |
| `on_2b` | 二塁走者のMLB ID | int/null |
| `on_3b` | 三塁走者のMLB ID | int/null |
| `home_score` | ホームチームの得点（投球前） | int |
| `away_score` | アウェイチームの得点（投球前） | int |
| `bat_score` | 攻撃チームの得点（投球前） | int |
| `fld_score` | 守備チームの得点（投球前） | int |
| `post_home_score` | 投球後のホーム得点 | int |
| `post_away_score` | 投球後のアウェイ得点 | int |
| `post_bat_score` | 投球後の攻撃チーム得点 | int |

#### セイバーメトリクス (Sabermetrics)

| フィールド名 | 説明 | データ型 |
|-------------|------|---------|
| `woba_value` | wOBA値 | float |
| `woba_denom` | wOBA分母 | float |
| `babip_value` | BABIP値 | float |
| `iso_value` | ISO値 | float |
| `delta_home_win_exp` | 勝率期待値の変化 | float |
| `delta_run_exp` | 得点期待値の変化 | float |

#### 守備配置 (Fielding Alignment)

| フィールド名 | 説明 | データ型 |
|-------------|------|---------|
| `if_fielding_alignment` | 内野シフト配置 | str |
| `of_fielding_alignment` | 外野シフト配置 | str |
| `fielder_2` 〜 `fielder_9` | 各ポジション選手のMLB ID | int |
| `sz_top` | ストライクゾーン上端 | float |
| `sz_bot` | ストライクゾーン下端 | float |

---

## 4. Pythonライブラリ

### 4.1 MLB-StatsAPI (推奨: MLB Stats API用)

```
pip install MLB-StatsAPI
```

| 項目 | 詳細 |
|------|------|
| PyPI | https://pypi.org/project/MLB-StatsAPI/ |
| GitHub | https://github.com/toddrob99/MLB-StatsAPI |
| バージョン | 1.9.0 (2025-04-04) |

**主な関数:**
```python
import statsapi

# スケジュール
statsapi.schedule(date='04/01/2025', team=147)

# 選手検索
statsapi.lookup_player('ohtani')

# ロスター
statsapi.roster(147, rosterType='active', season=2025)

# ボックススコア
statsapi.boxscore(718590)

# 順位表
statsapi.standings(leagueId=103, season=2025)

# 選手成績
statsapi.player_stat_data(660271, group='hitting', type='career')
```

### 4.2 pybaseball (推奨: Statcast / FanGraphs / Baseball Reference用)

```
pip install pybaseball
```

| 項目 | 詳細 |
|------|------|
| PyPI | https://pypi.org/project/pybaseball/ |
| GitHub | https://github.com/jldbc/pybaseball |

**主な関数:**

```python
from pybaseball import (
    statcast,                    # Statcast全データ（日付範囲）
    statcast_pitcher,            # 投手別Statcastデータ
    statcast_batter,             # 打者別Statcastデータ
    playerid_lookup,             # 選手ID検索
    pitching_stats,              # FanGraphs投手成績（シーズン）
    batting_stats,               # FanGraphs打者成績（シーズン）
    pitching_stats_bref,         # Baseball Reference投手成績
    batting_stats_bref,          # Baseball Reference打者成績
    pitching_stats_range,        # 日付範囲指定投手成績
    batting_stats_range,         # 日付範囲指定打者成績
    schedule_and_record,         # チーム日程・成績
    standings,                   # 順位表
    cache,                       # キャッシュ管理
)

# キャッシュ有効化（推奨）
cache.enable()

# Statcast全データ（日付範囲）
data = statcast('2025-04-01', '2025-04-07')

# 特定選手のStatcast
data = statcast_batter('2025-04-01', '2025-10-01', player_id=660271)
data = statcast_pitcher('2025-04-01', '2025-10-01', player_id=543037)

# チーム指定
data = statcast('2025-04-01', '2025-04-30', team='LAD')

# 選手ID検索
lookup = playerid_lookup('Ohtani', 'Shohei')
# => key_mlbam列がMLB Stats APIのpersonIdに対応

# シーズン成績
batting = batting_stats(2025)
pitching = pitching_stats(2025)
```

**pybaseball パラメータ詳細:**

| 関数 | パラメータ | 説明 |
|------|-----------|------|
| `statcast()` | `start_dt` | 開始日 (YYYY-MM-DD) |
| | `end_dt` | 終了日 (YYYY-MM-DD) |
| | `team` | チーム略称（任意） |
| | `verbose` | 進捗表示 (bool, default=True) |
| | `parallel` | 並列リクエスト (bool, default=True) |
| `statcast_batter()` | `start_dt`, `end_dt` | 日付範囲 |
| | `player_id` | MLB Advanced Media選手ID |
| `statcast_pitcher()` | `start_dt`, `end_dt` | 日付範囲 |
| | `player_id` | MLB Advanced Media選手ID |
| `batting_stats()` | `start_season` | 開始シーズン |
| | `end_season` | 終了シーズン（任意） |
| `pitching_stats()` | `start_season` | 開始シーズン |
| | `end_season` | 終了シーズン（任意） |

### 4.3 python-mlb-statsapi（型付きラッパー）

```
pip install python-mlb-statsapi
```

| 項目 | 詳細 |
|------|------|
| GitHub | https://github.com/zero-sum-seattle/python-mlb-statsapi |
| 特徴 | snake_case命名、型付きレスポンスオブジェクト |

**主な関数:**
```python
from mlbstatsapi import Mlb

mlb = Mlb()

# チーム
teams = mlb.get_teams()
team = mlb.get_team(147)
roster = mlb.get_team_roster(147)
coaches = mlb.get_team_coaches(147)

# 選手
person = mlb.get_person(660271)
people = mlb.get_people([660271, 543037])
player_id = mlb.get_people_id("Shohei Ohtani")

# 成績
stats = mlb.get_player_stats(660271, stats=['season'], groups=['hitting'])
team_stats = mlb.get_team_stats(147, stats=['season'], groups=['hitting'])

# ドラフト
draft = mlb.get_draft(2025)

# ボックススコア
boxscore = mlb.get_game_box_score(718590)
```

---

## 5. レート制限・ページネーション

### 5.1 MLB Stats API (statsapi.mlb.com)

| 項目 | 詳細 |
|------|------|
| 認証 | 不要（公開API） |
| 明示的レート制限 | 公式ドキュメント非公開のため不明確 |
| 実用的ガイドライン | リクエスト間に0.5〜1秒の間隔を推奨 |
| ページネーション | `limit` + `offset` パラメータ（`stats` エンドポイント等） |
| フィールド絞り込み | `fields` パラメータで不要フィールドを除外可能 |

**注意事項:**
- 公式レート制限は文書化されていないが、過剰なリクエストはIPブロックの可能性あり
- バッチ処理時は適切な間隔（1秒以上）を設けること
- `fields` パラメータで必要なデータのみ取得し、帯域を節約

### 5.2 Baseball Savant (Statcast)

| 項目 | 詳細 |
|------|------|
| 行数上限 | 1クエリあたり **25,000〜30,000行** |
| 注意 | 結果が25,000行ちょうどの場合、データが切り詰められている可能性 |
| 対策 | 日付範囲を狭めて複数回に分割してクエリ |
| pybaseball自動分割 | 5日以上の範囲は自動的に分割リクエスト |
| リクエスト間隔 | 1〜2秒推奨（大量取得時） |

### 5.3 ページネーション方式

**MLB Stats API:**
```
GET /api/v1/stats?stats=season&group=hitting&limit=50&offset=0
GET /api/v1/stats?stats=season&group=hitting&limit=50&offset=50
```

**Baseball Savant:**
- 明示的なページネーションなし
- 日付範囲で分割してデータ取得
- pybaseballは自動的に日付範囲を分割してリクエスト

---

## 6. 推奨データ取得戦略

### 6.1 取得対象データの範囲

| データカテゴリ | 推奨取得範囲 | データソース | 更新頻度 |
|-------------|-------------|-------------|---------|
| 選手マスタ | 全MLB選手（アクティブ） | Stats API `/people` | シーズン開始時 + 週次 |
| チームマスタ | 30球団 | Stats API `/teams` | シーズン開始時 |
| シーズン日程 | 対象シーズン全試合 | Stats API `/schedule` | シーズン開始時 + 日次 |
| 試合結果 | 対象シーズン全試合 | Stats API `/game/{id}/boxscore` | 試合終了後 |
| 打撃成績 | 対象シーズン | Stats API `/stats` | 日次 |
| 投球成績 | 対象シーズン | Stats API `/stats` | 日次 |
| Statcast投球データ | 対象シーズン全投球 | Baseball Savant CSV | 試合終了後（翌日） |
| 順位表 | 対象シーズン | Stats API `/standings` | 日次 |

### 6.2 推奨取得フロー

```
1. マスタデータ取得（初回 / シーズン開始時）
   ├── チーム一覧: GET /api/v1/teams?sportId=1&season=2025
   ├── 各チームロスター: GET /api/v1/teams/{id}/roster?season=2025
   └── 選手詳細: GET /api/v1/people?personIds={ids}

2. 日程データ取得（シーズン開始時 + 日次差分）
   └── GET /api/v1/schedule?sportId=1&season=2025&gameTypes=R

3. 試合データ取得（日次バッチ）
   ├── ボックススコア: GET /api/v1/game/{gamePk}/boxscore
   ├── ラインスコア: GET /api/v1/game/{gamePk}/linescore
   └── プレイバイプレイ: GET /api/v1/game/{gamePk}/playByPlay（任意）

4. Statcastデータ取得（日次バッチ）
   └── pybaseball.statcast(start_dt, end_dt)
       ※ 1日単位での取得を推奨

5. 集計成績取得（週次 or オンデマンド）
   ├── 打撃リーダー: GET /api/v1/stats?stats=season&group=hitting&season=2025
   ├── 投球リーダー: GET /api/v1/stats?stats=season&group=pitching&season=2025
   └── 順位表: GET /api/v1/standings?leagueId=103,104&season=2025
```

### 6.3 データ粒度の推奨

| 分析目的 | 推奨粒度 | データソース |
|---------|---------|-------------|
| チーム成績概要 | シーズン/月次集計 | Stats API |
| 選手成績比較 | シーズン集計 | Stats API / FanGraphs (pybaseball) |
| 投球分析 | 投球レベル（pitch-by-pitch） | Statcast (Baseball Savant) |
| 打球分析 | 打球レベル（batted ball） | Statcast (Baseball Savant) |
| 試合ハイライト | 打席レベル（at-bat） | Stats API playByPlay |
| 勝敗予測 | 投球レベル + ゲームコンテキスト | Statcast + Stats API |

### 6.4 注意事項

1. **Statcastデータ量:** 1シーズンで約70万〜80万投球。全量取得には日付分割で数時間かかる
2. **ID体系の統一:** MLB Stats APIの`personId`とStatcastの`pitcher`/`batter`は同一ID体系
3. **`gamePk`の統一:** MLB Stats APIとStatcastの`game_pk`は同一ID体系
4. **データ遅延:** Statcastデータは試合終了後数時間〜翌日に反映
5. **過去データ:** Statcastは2015年以降が完全データ（2008-2014は部分的）
6. **キャッシュ活用:** pybaseballのcache機能やローカルDBへの保存を強く推奨

---

## 参考リンク

- [MLB Stats API 公式](https://statsapi.mlb.com/)
- [MLB Stats API 公式ドキュメント (要ログイン)](https://docs.statsapi.mlb.com/)
- [MLB-StatsAPI Python Wrapper (GitHub)](https://github.com/toddrob99/MLB-StatsAPI)
- [MLB-StatsAPI Endpoints Wiki](https://github.com/toddrob99/MLB-StatsAPI/wiki/Endpoints)
- [python-mlb-statsapi (GitHub)](https://github.com/zero-sum-seattle/python-mlb-statsapi)
- [pybaseball (GitHub)](https://github.com/jldbc/pybaseball)
- [pybaseball Statcast ドキュメント](https://github.com/jldbc/pybaseball/blob/master/docs/statcast.md)
- [Baseball Savant Statcast Search](https://baseballsavant.mlb.com/statcast_search)
- [Baseball Savant CSV ドキュメント](https://baseballsavant.mlb.com/csv-docs)
