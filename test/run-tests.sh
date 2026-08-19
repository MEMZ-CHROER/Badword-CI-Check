#!/usr/bin/env bash
# 🧪 Badword-CI-Check 自测：坏文件必须拦截、好文件必须放行、.profanity-ignore 生效、自身不被拦。
# 用法：bash test/run-tests.sh
set -euo pipefail
cd "$(dirname "$0")/.."

fail=0
run() { # $1=描述 $2=期望(0放行/1拦截) $3+ 文件
  local desc="$1" expect="$2" got
  shift 2
  if bash profanity-check.sh --files "$@" >/dev/null 2>&1; then got=0; else got=1; fi
  if [ "$got" -eq "$expect" ]; then
    echo "✅ $desc"
  else
    echo "❌ $desc（期望=${expect}，实际=${got}）"
    fail=1
  fi
}

# 先临时移走 .profanity-ignore，用"无忽略"验证核心拦截逻辑
HAD_IGNORE=0
[ -f .profanity-ignore ] && { HAD_IGNORE=1; mv .profanity-ignore .profanity-ignore.bak; }

run "bad.md：明文/绕过变体/缩写/数字梗全部拦截" 1 test/bad.md
run "ok.md：打码/IP/版本/正常词全部放行" 0 test/ok.md

# 恢复自带 ignore，验证"自身不被拦"（词库/样本被排除）
if [ "$HAD_IGNORE" -eq 1 ]; then mv .profanity-ignore.bak .profanity-ignore; fi
if [ -f .profanity-ignore ]; then
  run "词库文件被 .profanity-ignore 排除（自身不被拦）" 0 badwords-sub.txt badwords-word.txt badwords-number.txt
  run "test/bad.md 样本被排除" 0 test/bad.md
fi

# .profanity-ignore 排除任意文件
printf '137891 恶搞行\n' > test/ignore.md
[ -f .profanity-ignore ] && cp .profanity-ignore .profanity-ignore.bak
echo 'test/ignore.md' >> .profanity-ignore
run "test/ignore.md 被 .profanity-ignore 排除" 0 test/ignore.md
rm -f .profanity-ignore test/ignore.md
[ -f .profanity-ignore.bak ] && mv .profanity-ignore.bak .profanity-ignore

if [ "$fail" -eq 0 ]; then
  echo "全部自测通过 ✓"
  exit 0
fi
echo "存在失败用例 ✗"
exit 1
