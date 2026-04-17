# Upstream 同步 SOP

> 當 `scripts/check-upstream.sh` 偵測到新版時，Claude 讀這份 SOP 執行翻譯同步。
> 觸發來源：scheduled-tasks 每週一 08:00、或手動執行 `bash scripts/check-upstream.sh`。

---

## 前置狀態

執行前專案應有：

- `tmp/upstream-latest.html` — 最新 upstream HTML（由 check-upstream.sh 產生）
- `tmp/sync-meta.env` — 內含 `upstream_version=`、`current_version=`
- 本地 `index.html` 為繁中版（只有**內容文字**是中文，結構 / class / 資料屬性與原站一致）

如果 `tmp/` 空的 → 先跑 `bash scripts/check-upstream.sh`。
如果 exit 0（版本一致）→ 本輪無需動作，結束。

---

## 執行流程

### 1. 讀兩個版本號

```bash
cat tmp/sync-meta.env
```

記下 `upstream_version`（例：`v2.1.112`）與 `current_version`（例：`v2.1.101`）。

### 2. 用 diff 找出變動區塊

```bash
diff tmp/upstream-latest.html index.html > tmp/upstream.diff || true
wc -l tmp/upstream.diff
```

- 差異一般集中在：版本號字串、新增的指令 / 旗標 / env var、cheat sheet 的章節條目。
- **忽略**以下已知差異（這些是我們刻意改過的，不要還原成英文）：
  - `<html lang="zh-Hant">` vs `en`
  - `<title>`、`<meta description/keywords>`、Open Graph、Twitter meta 全是中文
  - `--font-sans` 加了 `'Noto Sans TC'`
  - `font-size`、`padding`、`max-width` 等 CSS 排版（雷蒙版是**滿版設計**，原站是 A4 列印）
  - `.header-left` / `.header-buttons` / `.header-btn` / `.header-right` 區塊是繁中版獨有
  - `@page { size: A4 landscape }` 在原站有，繁中版刻意移除
  - 作者署名：`<meta name="author" content="雷蒙三十">`
  - favicon：繁中版只用 emoji SVG，不引 `/favicon.png`
  - `og:url` / `canonical` / `hreflang` 指向 `cc.storyfox.cz`，繁中版不抄

### 3. 鎖定真正需要翻譯的內容變動

用 `grep -n` 在 diff 中找：

- 新的指令字串（如 `/rewind`、`ctrl-shift-s`、新的 MCP 範例）
- 新的條目 `<li>` / `<tr>` / `<div class="kbd-row">`
- 版本號字樣 `Claude Code v...`
- `<div class="updated">` / 「Updated: YYYY-MM-DD」
- changelog 連結變更

### 4. 用 Edit 工具逐段同步

**原則**：只改變動處，保留繁中翻譯結構。

- 英文新條目 → 翻成繁中，語氣與既有翻譯一致（簡潔、技術用語保留原文，說明繁中化）。
- `<code>` / `<kbd>` 內容保持原文（指令、旗標、shortcut、env var 名稱一律不翻）。
- 新增 class / data-\* 屬性照抄。

翻譯風格對照現有 index.html 抽樣：
- 「Keyboard Shortcuts」→「鍵盤快捷鍵」
- 「Slash Commands」→「斜線指令」
- 「Memory Files」→「記憶檔案」
- 「Environment Variables」→「環境變數」
- 動詞用短句，如「Interrupt current action」→「中斷目前動作」

### 5. 更新版本號三處

都改成 `${upstream_version}`：

1. `index.html` 顯示版本字樣（搜尋 `Claude Code v`）
2. `index.html` 的 `Updated: YYYY-MM-DD` → 改成今日日期（Asia/Taipei）
3. `README.md` 的「對齊版本」與「最後更新」表格

### 6. 自我驗證

```bash
# 版本號應該一致
grep -oE 'Claude Code v[0-9.]+' index.html | head -1
grep -oE 'Claude Code v[0-9.]+' README.md | head -1
# check-upstream.sh 應回傳 0
bash scripts/check-upstream.sh && echo "✅ 同步完成"
```

如果 `check-upstream.sh` 回傳 0 才算成功。

### 7. Commit + Push

```bash
git add index.html README.md
git commit -m "sync: 同步原站更新至 Claude Code ${upstream_version}"
git push
```

推送後：

- `.github/workflows/auto-release.yml` 會**自動發 Release**（讀 README 版本號建 tag）。
- `.github/workflows/check-upstream.yml` 下一輪（隔天 00:00 UTC+8）版本比對就會一致，不再開新 issue。

### 8. 關閉已解決的 upstream-update issue

```bash
# 列出所有 open 的 upstream-update issue
gh issue list --state open --label upstream-update --json number,title
```

對 title 中版本 ≤ `${upstream_version}` 的 issue 全部關閉：

```bash
gh issue close <number> --comment "已同步至 ${upstream_version}（見 Release ${upstream_version}）"
```

### 9. 清理

```bash
rm -rf tmp/upstream-latest.html tmp/upstream.diff tmp/sync-meta.env
```

---

## 故障排查

| 現象 | 處理 |
|:--|:--|
| `curl` 抓 upstream 失敗 | 檢查網路、重試一次；原站真的掛掉就略過本輪 |
| `diff` 出來數百行全是 CSS 重排 | 原站改了版面，評估是否跟進（通常不跟，繁中版是滿版客製） |
| 翻譯後 `check-upstream.sh` 還是 exit 1 | 確認 README 版本號真的改了 |
| auto-release 沒發 Release | 看 GitHub Actions log；通常是 `gh release view` 已存在，檢查 tag 列表 |
| issue 關不掉 | 確認 gh 已登入 `gh auth status` |

---

## 不做的事

- **不**從頭抓 upstream 全文覆蓋本地 index.html（會丟失繁中翻譯與版面客製）
- **不**建新的 branch / PR（直接 push master，Release 靠 tag 觸發）
- **不**翻譯 `<code>` / `<kbd>` 內指令
- **不**加任何中文註解到 HTML / JS 內（維持原站結構便於下次 diff）
