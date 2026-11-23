# arxiv-export

> 把 Markdown 学术论文导出为 **arXiv 级可重编译的 LaTeX 投稿包**——附本地 PDF 校样。

一个 Claude Code skill，把写好的 Markdown 论文（如 `academic-paper` /
`writing-editorial` 的产出）转成**能在 arXiv 的 TeXLive 上干净重编译**的 LaTeX
源码，并产出可直接上传的 `submission.tar.gz`。

[English](README.md)

## 为什么需要专门的 skill

Markdown 作者几乎总会踩两个坑，naive 的 `pandoc file.md -o out.pdf` 会直接失败或排版劣质：

1. **数学没有 `$` 定界**：作者把公式当普通文字写（如 `φ(p) = A(p) − B⁺(p)`），
   LaTeX 不进数学模式 → 间距/斜体全错，`⟺ ⊆ ⁺ ₀` 等字形在标准字体缺失。
2. **引用是 Markdown 列表不是 BibTeX**、定理没有 amsthm 环境、章节分散在多个 `ch*.md`。

本 skill 把这些当作**一等场景**处理：核心难点（数学定界 + unicode 转换）由按块 Agent
完成并带强制抽检闭环，确定性部分由脚本完成。

## 六阶段流水线

```
Markdown 终稿
   │
   ▼
 Phase 0  Preflight：工具链体检 + 源盘点 + 难点量化
   │        （无 pandoc/tectonic → 征得同意后 brew 安装）
   ▼
 Phase 1  数学定界 + unicode→LaTeX（按块 Agent，最关键）
   │        [MUST] 抽检闭环，防数学被改
   ▼
 Phase 2  结构→LaTeX（preamble + amsthm 定理环境）
   │
   ▼
 Phase 3  引用→参考文献（BibTeX/\cite，或内嵌 thebibliography）
   │
   ▼
 Phase 4  编译验证（tectonic / XeLaTeX / pdfLaTeX，迭代 ≤3 轮）
   │
   ▼
 Phase 5  arXiv 打包（.bbl 或内嵌 bib、00README、扁平化、tar.gz、终检清单）
```

### 安全护栏

- **系统变更必先征求同意**：Phase 0 安装任何工具链组件前会停下询问。
- **数学保真神圣不可侵**：Phase 1 的 `[MUST]` 抽检随机比对原文↔产物，确认无数学内容、
  符号方向、上下标漂移；不通过则重做该块，再不通过就暂停征询你——绝不静默交付被改的数学。
- **绝不覆盖你的 Markdown**：所有产物写入 `arxiv-build/`（或 `$SCRATCH_DIR`）工作目录。

## 安装

```bash
git clone https://github.com/easyfan/arxiv-export.git
cd arxiv-export
./install.sh            # 安装到 ~/.claude/skills/arxiv-export/
./install.sh --dry-run  # 预览
./install.sh --uninstall
```

Windows：`./install.ps1`。

**TeX 工具链**：安装 skill 本身不需要。首次真实运行时 skill 会检查 TeX 引擎，经你同意后安装
（推荐 `tectonic` + `pandoc`——自包含、无需 4GB MacTeX、底层 XeTeX）。注意 tectonic 首次编译
会联网按需下包/字体（数分钟、数百 MB），属正常，非卡死。

## 用法

在 Claude Code 里指向你写好的 Markdown 论文：

```
用 arxiv-export 把 main_en.md 导出成 arXiv 投稿包
把这篇论文 paper.md 转成 LaTeX
compile my markdown paper to a PDF for arXiv
```

产物落在构建目录：

- `main.pdf` — 本地校样
- `submission.tar.gz` — arXiv 上传包
- `main.tex` — 自足 LaTeX 源码
- `EXPORT_REPORT.md` — 工作量、抽检结论、告警处置、未决事项

## 安装的文件

| 路径 | 作用 |
|------|------|
| `skills/arxiv-export/SKILL.md` | 六阶段协调 |
| `skills/arxiv-export/references/unicode-to-latex.md` | unicode→LaTeX 映射 + 残留字符扫描 |
| `skills/arxiv-export/references/latex-template.md` | amsart preamble、amsthm 定理环境、代码块 unicode、表格转换 |
| `skills/arxiv-export/references/arxiv-packaging.md` | `.bbl` vs 内嵌 bib、引擎声明、扁平化、tar.gz、终检清单 |

## Changelog

### v1.0.0 (2026-11-24)

首个版本。经一次真实端到端运行打磨——导出一篇 723 行、裸 unicode 数学（0 个 `$`、
约 890 个 unicode 数学字符、24 条引用、含 Lean 代码块）的论文为干净的 33 页 arXiv 包。

| 项 | 内容 |
|------|------|
| 六阶段流水线 | 预检 → 数学定界 → 结构 → 引用 → 编译 → 打包 |
| `[MUST]` 抽检闭环 | Phase 1 数学保真门禁，带重试 + 暂停征询 |
| 代码块 unicode | XeTeX/tectonic 下 listings `literate` 不触发 → 改用 `escapeinside` 渲染 `→ ¬ φ ⁺` 不丢字 |
| 年份漂移防护 | Phase 3 检查正文年份 vs 引用年份；不一致则用内嵌 `thebibliography` 保留字面（不走 natbib 重排） |
| `Missing character` 检查 | Phase 4 新增专项扫描（区别于 `Undefined control sequence`） |
| 长摘要版式 | 默认 amsart 10pt，让标题+摘要同处首页 |
| 定理编号 | 各类独立计数器 + 无编号陈述用 `\newtheorem*`，忠实 Markdown 原编号 |

See [README.md](README.md) for the full English release notes.

## 许可

MIT——见 [LICENSE](LICENSE)。
