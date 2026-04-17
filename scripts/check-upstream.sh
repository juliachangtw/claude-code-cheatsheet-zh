#!/usr/bin/env bash
# 檢查 upstream (cc.storyfox.cz) 是否有新版
# 用法：bash scripts/check-upstream.sh
#   exit 0 → 版本一致，無需動作
#   exit 1 → 偵測到新版，HTML 已存入 tmp/upstream-latest.html，接著由 Claude 執行 sync-upstream.md
#   exit 2 → 抓取 / 解析失敗

set -euo pipefail

UPSTREAM_URL="https://cc.storyfox.cz"
ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
cd "$ROOT"

UPSTREAM_HTML="$(curl -fsSL "$UPSTREAM_URL")" || { echo "❌ 抓取 upstream 失敗" >&2; exit 2; }

UPSTREAM_VER="$(echo "$UPSTREAM_HTML" | grep -oE 'Claude Code v[0-9.]+' | head -1 | sed 's/Claude Code //')"
CURRENT_VER="$(grep -oE 'Claude Code v[0-9.]+' README.md | head -1 | sed 's/Claude Code //')"

if [[ -z "$UPSTREAM_VER" || -z "$CURRENT_VER" ]]; then
  echo "❌ 版本號解析失敗 (upstream='$UPSTREAM_VER' current='$CURRENT_VER')" >&2
  exit 2
fi

echo "Upstream : $UPSTREAM_VER"
echo "Current  : $CURRENT_VER"

if [[ "$UPSTREAM_VER" == "$CURRENT_VER" ]]; then
  echo "✅ 版本一致，無需同步"
  exit 0
fi

mkdir -p tmp
echo "$UPSTREAM_HTML" > tmp/upstream-latest.html
{
  echo "upstream_version=$UPSTREAM_VER"
  echo "current_version=$CURRENT_VER"
  echo "fetched_at=$(date -u +"%Y-%m-%dT%H:%M:%SZ")"
} > tmp/sync-meta.env

echo "⚠️  偵測到新版：$CURRENT_VER → $UPSTREAM_VER"
echo "   已存 upstream HTML → tmp/upstream-latest.html"
echo "   下一步：讓 Claude 讀 scripts/sync-upstream.md 執行同步"
exit 1
