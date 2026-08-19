# Badword-CI-Check

🧪 轻量不雅用语 / 脏话 / 数字骂人梗扫描工具，grep + 词库实现，无外部依赖，可作为 PR 的 CI 检查。

本工具从 [Cloudflare-Workers-Chat](https://github.com/MEMZ-CHROER/Cloudflare-Workers-Chat) 的敏感词库出发，针对**文档/内容仓库**场景定制：
合规打码（`f**k` / `sh*t` / `D****S` 等含 `*` 形式）天然放行，**IP 地址与版本号中的数字段不会误报**。

## 特性

- 🚫 **拦截**：中英文脏话、拼音缩写（独立成词才拦，防 `usb`/`isby` 误报）、绕过变体（数字插入、全角、希腊字母等 leetspeak 形态）、数字骂人梗（详见 `badwords-number.txt`）
- **测试**：详见[PR #1](https://github.com/MEMZ-CHROER/Badword-CI-Check/pull/1) **注意** 观察commit，而不是`MERGE`结果
- **实测**：见[PR #2](https://github.com/MEMZ-CHROER/Badword-CI-Check/pull/2) **这是小号fork然后`contribute`的真实测试，永不合并**
- ✅ **放行**：合规打码（`f**k` 等含 `*`）、IP 地址（如 `13.56.91.48`，含数字梗段）、版本号（如 `1.13.5`）
- 📍 **定位**：命中输出 `文件:行号:内容`，直接指向 PR 改动位置
- 🔧 **可配置**：三份纯文本词库随意增删；`.profanity-ignore` 按 glob 排除文件

## 快速开始

```bash
# 扫描全部已跟踪文件
bash profanity-check.sh

# 仅扫描 PR / 分支相对 base 的改动（CI 用法）
bash profanity-check.sh <base-sha>

# 指定文件
bash profanity-check.sh --files docs/a.md docs/b.md
```

命中时退出码为 1，并在 stdout 列出所有命中位置。

### GitHub Actions（PR 检查）

推荐直接用已发布的 Action（自动带上内置词库，无需复制任何文件）：

```yaml
name: Badword Check
on:
  pull_request:
    types: [opened, synchronize, reopened]
jobs:
  badword:
    runs-on: ubuntu-latest
    steps:
      - uses: actions/checkout@v7
        with:
          fetch-depth: 0
      - uses: MEMZ-CHROER/Badword-CI-Check@v1
        with:
          base: ${{ github.event.pull_request.base.sha }}
```

不想用 Action，直接跑脚本也可以（脚本会用同目录内置词库，`--wordlists <dir>` 可换成自定义词库）：

```yaml
      - name: 扫描 PR 改动
        run: bash profanity-check.sh ${{ github.event.pull_request.base.sha }}
```

**Action 输入**：

| 输入 | 说明 |
|---|---|
| `base` | 相对 base SHA 的改动（PR 场景） |
| `files` | 空格分隔的文件列表（覆盖 `base`） |
| `wordlists` | 自定义词库所在目录（缺省用内置） |

## 词库

| 文件 | 匹配方式 | 内容 |
|---|---|---|
| `badwords-sub.txt` | 子串（容忍派生词） | 中英文脏话词根、中文脏话短语、常见绕过变体（全角/数字插入等），详见词库文件 |
| `badwords-word.txt` | 整词（独立成词才拦） | 拼音缩写，防 `usb`/`isby` 嵌入误报 |
| `badwords-number.txt` | 独立数字 token（剔除 IP/版本） | 数字骂人梗，独立 token 才拦，自动剔除 IP/版本号 |

每行一个词，`#` 开头为注释。可直接增删词条定制。

### 数字梗误报规避

数字骂人梗仅匹配**独立数字 token**（两侧非数字），且在匹配前自动剔除 IP 地址（`\d{1,3}.\d{1,3}.\d{1,3}.\d{1,3}`）与版本号（`\d+.\d+...`）——因此 `13.56.91.48`、`208.91.196.94`、`1.13.5` 都不会误报。

### 排除文件

仓库根放 `.profanity-ignore`，每行一个 glob，匹配的文件跳过（`#` 注释）：

```
# 该页大量使用坐标数值，撞上数字梗
docs/locations.md
generated/*.json
```

## 自测

```bash
bash test/run-tests.sh
```

覆盖：明文/变体/缩写/数字梗必须拦截；打码/IP/版本/正常词必须放行；`.profanity-ignore` 生效。

## 许可证

[MIT](LICENSE) © 2026 MEMZ-CHROER
