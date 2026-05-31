#  SCU-2026春-杨凯-软件项目管理課程項目 AutoGrader(Beta) 聯調倉庫

本倉庫用於整合 AutoGrader 課程項目的四個子模塊，統一管理版本、啟動腳本和聯調測試。四個模塊分別存放在獨立的 Git 倉庫中，本倉庫通過 Git submodule 固定每個模塊使用的版本。

## 模塊說明

| 模塊 | 目錄 | 主要職責 | 默認地址 |
| --- | --- | --- | --- |
| B1 | `B1/` | 前端頁面：登錄、課程、作業提交、題庫和成績展示 | <http://127.0.0.1:5173> |
| B2 | `B2/` | 提交接收與評測調度：保存代碼、靜態檢查、調用 B3、回寫結果 | <http://127.0.0.1:8002/docs> |
| B3 | `B3/` | 題庫與判題引擎：題目規則、測試用例、沙箱執行和評測結果 | <http://127.0.0.1:8003/docs> |
| B4 | `B4/autograder_api/` | 業務後端：用戶、課程、班級、作業、提交和成績數據 | <http://127.0.0.1:8000/docs> |

根目錄中的 [start_all.sh](./start_all.sh) 用於一次啟動四個模塊，`httpie_*.sh` 用於接口聯調檢查。

## 環境要求

開始前請準備：

- Git
- Node.js 和 npm
- Python 3 和 `venv`
- MySQL
- 可選：Docker。B3 可使用 Docker 沙箱執行待測代碼。
- 可選：HTTPie 和 `jq`。運行接口聯調腳本時需要。
- 可選：`cloc`。更新代碼統計時需要。

## 克隆倉庫

推薦在克隆時一併拉取所有子模塊：

```bash
git clone --recurse-submodules https://github.com/Foggyforest114514/AutoGrader--.git
cd AutoGrader--
```

如果已經克隆了根倉庫，但子模塊目錄為空，執行：

```bash
git submodule update --init --recursive
```

## 首次安裝

### 1. 安裝 B1 前端依賴

```bash
cd B1
npm install
```

### 2. 安裝 B2 依賴

B2 目前沒有獨立的 `requirements.txt`，可直接安裝以下依賴：

```bash
cd ../B2
python3 -m venv .venv
source .venv/bin/activate
pip install fastapi "uvicorn[standard]" httpx pydantic
deactivate
```

### 3. 安裝並配置 B3

```bash
cd ../B3
python3 -m venv .venv
source .venv/bin/activate
pip install -r requirements.txt
cp .env.example .env
deactivate
```

修改 `B3/.env` 中的 `DATABASE_URL`，使其指向本地 MySQL 數據庫。B3 的沙箱配置也在該文件中。

### 4. 安裝並配置 B4

```bash
cd ../B4/autograder_api
python3 -m venv .venv
source .venv/bin/activate
pip install -r requirements.txt
cp .env.example .env
deactivate
```

修改 `B4/autograder_api/.env` 中的 `DATABASE_URL` 和 `SECRET_KEY`。啟動前請確認 MySQL 數據庫已經建立。

## 啟動項目

回到根目錄後執行：

```bash
cd ../..
./start_all.sh
```

腳本只負責啟動服務，不會自動安裝依賴或建立數據庫。運行日誌保存在 `logs/` 目錄。按 `Ctrl-C` 可停止全部服務。

啟動後可訪問：

| 服務 | 地址 |
| --- | --- |
| B1 前端 | <http://127.0.0.1:5173> |
| B2 API 文檔 | <http://127.0.0.1:8002/docs> |
| B3 API 文檔 | <http://127.0.0.1:8003/docs> |
| B4 API 文檔 | <http://127.0.0.1:8000/docs> |

## 接口聯調檢查

服務啟動後，可在另一個終端執行：

```bash
./httpie_smoke_all.sh
```

該腳本會依次運行 B3、B4 和 B2 的 HTTP 接口檢查。也可以單獨執行某個模塊的腳本：

```bash
./httpie_b3_tests.sh
./httpie_b4_tests.sh
./httpie_b4_extended_tests.sh
./httpie_b2_tests.sh
```

## 子模塊版本管理

### 拉取根倉庫更新後

根倉庫記錄的是每個子模塊的指定 commit。拉取根倉庫更新後，執行以下命令同步子模塊版本：

```bash
git submodule update --init --recursive
```

子模塊中出現 detached `HEAD` 是正常現象，表示當前代碼正固定在根倉庫記錄的 commit。

### 主動更新所有子模塊

如需將四個子模塊更新到各自 `main` 分支的最新版本，執行：

```bash
git submodule update --remote --merge --recursive
```

更新後，根倉庫中的子模塊指針也需要提交：

```bash
git add B1 B2 B3 B4
git commit -m "Update submodules"
```

這樣其他成員拉取根倉庫後，才能得到一致的模塊版本。

## 代碼統計

以下數據生成於 2026-05-31。統計命令只計算 Git 已追蹤的文件：

```bash
for d in ./*/ ; do (cd "$d" && echo "$d" && cloc --vcs git); done;
```

| 模塊 | 文件數 | 空行 | 註釋行 | 代碼行 |
| --- | ---: | ---: | ---: | ---: |
| B1 | 75 | 2,064 | 330 | 18,907 |
| B2 | 77 | 352 | 79 | 1,069 |
| B3 | 31 | 764 | 362 | 6,504 |
| B4 | 44 | 1,003 | 14 | 6,113 |
| **合計** | **227** | **4,183** | **785** | **32,593** |

<details>
<summary>查看各模塊的語言明細</summary>

### B1

| 語言 | 文件數 | 空行 | 註釋行 | 代碼行 |
| --- | ---: | ---: | ---: | ---: |
| Vuejs Component | 24 | 1,684 | 149 | 12,778 |
| JSON | 4 | 2 | 0 | 3,130 |
| TypeScript | 31 | 247 | 155 | 2,385 |
| CSS | 1 | 58 | 26 | 298 |
| Markdown | 2 | 66 | 0 | 220 |
| Text | 10 | 1 | 0 | 55 |
| Bourne Shell | 1 | 3 | 0 | 18 |
| HTML | 1 | 0 | 0 | 13 |
| JavaScript | 1 | 3 | 0 | 10 |

### B2

| 語言 | 文件數 | 空行 | 註釋行 | 代碼行 |
| --- | ---: | ---: | ---: | ---: |
| Python | 53 | 266 | 79 | 851 |
| Markdown | 24 | 86 | 0 | 218 |

### B3

| 語言 | 文件數 | 空行 | 註釋行 | 代碼行 |
| --- | ---: | ---: | ---: | ---: |
| JSON | 3 | 0 | 0 | 3,236 |
| Python | 20 | 578 | 362 | 2,750 |
| Markdown | 2 | 142 | 0 | 365 |
| Text | 2 | 23 | 0 | 84 |
| INI | 2 | 9 | 0 | 33 |
| Dockerfile | 1 | 4 | 0 | 18 |
| Mako | 1 | 8 | 0 | 18 |

### B4

| 語言 | 文件數 | 空行 | 註釋行 | 代碼行 |
| --- | ---: | ---: | ---: | ---: |
| Python | 36 | 871 | 14 | 5,499 |
| Markdown | 4 | 119 | 0 | 521 |
| DOS Batch | 2 | 8 | 0 | 46 |
| Bourne Shell | 1 | 5 | 0 | 32 |
| Text | 1 | 0 | 0 | 15 |

</details>

`logs/` 和 `weekly_report_B4/` 也會被統計命令遍歷，但它們不是應用模塊，因此未納入上表。
