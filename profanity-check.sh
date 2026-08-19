#!/usr/bin/env bash
# 🧪 Badword-CI-Check：不雅用语 / 脏话 / 数字骂人梗扫描，命中即 fail。
#
# 三份词库（均为纯文本，每行一词，`#` 开头为注释，可自行增删）：
#   badwords-sub.txt    子串词（长词/中文/英文根，容忍派生词）
#   badwords-word.txt   整词词（拼音缩写，独立成词才拦，防 usb/isby/abs 嵌入误报）
#   badwords-number.txt 数字骂人梗（独立 token 才拦，自动剔除 IP/版本号）
#
# 合规打码（f**k / sh*t / D****S 等含 `*` 形式）天然放行——词库不含打码形式。
#
# 用法：
#   bash profanity-check.sh                              # 扫描全部已跟踪文件
#   bash profanity-check.sh <base-sha>                   # 仅扫描 PR/分支相对 base 的改动（CI 用）
#   bash profanity-check.sh --files a.md b.md            # 扫描指定文件
#   bash profanity-check.sh --wordlists <dir> [args...]  # 使用自定义词库目录
#
# 可选：仓库根放 .profanity-ignore（每行一个 glob，匹配的文件跳过，`#` 开头为注释）
set -euo pipefail
# grep 需要可用的 locale（Git Bash 默认 locale 可能缺失）
export LC_ALL=C

# 词库目录：默认与脚本同目录（脚本可放在任意位置、被 action 引用），可用 --wordlists <dir> 覆盖为自定义词库
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
WL_DIR="$SCRIPT_DIR"
if [ "${1:-}" = "--wordlists" ] && [ -n "${2:-}" ]; then WL_DIR="$2"; shift 2; fi

# tr -d '\r'：兼容 Windows git autocrlf（工作区文件 CRLF，词条/ignore 行尾带 \r 会破坏匹配）
SUB_LIST="$(grep -vE '^\s*(#|$)' "$WL_DIR/badwords-sub.txt" | tr -d '\r')"
WORD_RE="$(grep -vE '^\s*(#|$)' "$WL_DIR/badwords-word.txt" | tr -d '\r' | paste -sd'|')"
NUM_RE="$(grep -vE '^\s*(#|$)' "$WL_DIR/badwords-number.txt" | tr -d '\r' | paste -sd'|')"

# 待检查文件：--files 显式指定 / PR 改动（diff-filter=ACM）/ 全部已跟踪文件
case "${1:-}" in
  --files) shift; FILES="$*"; COUNT=$# ;;
  "")      FILES="$(git ls-files)"; COUNT="$(printf '%s\n' "$FILES" | grep -c . || true)" ;;
  *)       FILES="$(git diff --name-only --diff-filter=ACM "$1"...HEAD 2>/dev/null || true)"; COUNT="$(printf '%s\n' "$FILES" | grep -c . || true)" ;;
esac

TEXT_RE='\.(md|txt|js|mjs|ts|json|yaml|yml|html|css|xml|vue|sh)$'
SKIP_RE='(^|/)(\.git|node_modules|dist|public|docs/\.vitepress/dist)/'

hits=0
ignored() { # $1=文件路径，命中 .profanity-ignore 返回 0
  [ -f .profanity-ignore ] || return 1
  while IFS= read -r pat; do
    pat="${pat%$'\r'}" # 兼容 CRLF 行尾
    [ -z "$pat" ] && continue
    case "$pat" in \#*) continue ;; esac
    case "$1" in $pat) return 0 ;; esac
  done < .profanity-ignore
  return 1
}

check() { # $1=文件
  local f="$1"
  if ! echo "$f" | grep -qE "$TEXT_RE"; then return 0; fi
  if echo "$f" | grep -qE "$SKIP_RE"; then return 0; fi
  if ignored "$f"; then return 0; fi
  # 子串词：-H 文件名 -n 行号 -F 固定串 -f 词表（容忍派生词）
  if grep -HnFf <(printf '%s\n' "$SUB_LIST") "$f"; then hits=1; fi
  # 整词词：-w 词边界（中文两侧也算边界），-i 忽略大小写
  if [ -n "$WORD_RE" ] && grep -HnwiE "$WORD_RE" "$f"; then hits=1; fi
  # 数字梗：先剔除 IP 地址与版本号（防 13.56.91.48 / 208.91.196.94 / 1.13.5 误报），再独立 token 匹配。
  # 注意 awk 无命中也返回 0，须捕获输出判断，不能直接当 if 条件。
  if [ -n "$NUM_RE" ]; then
    local hit
    hit="$(awk -v re="$NUM_RE" -v fn="$f" '
      {
        line = $0;
        gsub(/([0-9]{1,3}\.){3}[0-9]{1,3}/, "IP", line);
        gsub(/[0-9]+([.][0-9]+)+/, "VER", line);
        if (line ~ "(^|[^0-9])(" re ")($|[^0-9])") print fn ":" NR ": " $0;
      }' "$f")"
    if [ -n "$hit" ]; then echo "$hit"; hits=1; fi
  fi
  return 0
}

for f in $FILES; do
  if [ -f "$f" ]; then check "$f"; fi
done

if [ "$hits" -eq 1 ]; then
  echo ""
  echo "❌ 检测到不雅用语（明文 / 绕过变体 / 数字骂人梗）。请按合规流程打码：如 f**k / sh*t / D****S（含 * 形式），或加入 .profanity-ignore 排除误报文件。"
  exit 1
fi

echo "✅ 通过（共 ${COUNT:-0} 个文件，未发现不雅用语）"
