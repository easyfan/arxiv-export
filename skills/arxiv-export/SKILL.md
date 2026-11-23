---
name: arxiv-export
description: 把 Markdown 学术论文导出为 arXiv 级可重编译的 LaTeX 投稿包（含 PDF 校样）。处理 Markdown 作者常见的"裸 unicode 数学无 $ 定界"难题，做 unicode→LaTeX 转换、数学定界、定理环境结构化、refs 转 BibTeX、tectonic/xelatex 编译验证、arXiv 打包（.bbl/00README/tar.gz）。当用户说"导出 arXiv 投稿包"、"生成 arXiv LaTeX"、"投稿 arXiv"、"markdown 转 latex/tex"、"把论文转成 LaTeX"、"编译论文 PDF"、"arXiv submission"、"tex 导出"、"论文投稿打包"时调用。属写作编辑类，承接 academic-paper/writing-editorial 产出的 Markdown 终稿。
allowed-tools: [Bash, Read, Write, Edit, Agent, AskUserQuestion]
---

# arXiv 投稿包导出 Skill

把一篇 Markdown 学术论文（通常由 `academic-paper` / `writing-editorial` 产出）转成
**arXiv 可在其 TeXLive 上干净重编译**的 LaTeX 源码包，并产出本地 PDF 校样。

## 为什么需要专门的 skill

Markdown 作者写论文时几乎总会踩两个坑，naive 的 `pandoc file.md -o out.pdf` 会直接失败或产出劣质排版：

1. **数学没有 `$` 定界**：作者把公式当普通文字写（如 `φ(p) = A(p) − B⁺(p)`），
   LaTeX 不会进入数学模式 → 间距/斜体全错，且 `⟺ ⊆ ⁺ ₀` 等字形在标准字体缺失。
2. **引用是 Markdown 列表不是 BibTeX**、定理没有 amsthm 环境、章节分散在多个 `ch*.md`。

本 skill 把这些坑作为**一等场景**处理。核心难点（数学定界 + unicode 转换）由
按章 Agent 智能完成，确定性部分由脚本完成。

## 开始前：确认三件事（能推断就别打断用户）

1. **源文件**：单一拼装稿（如 `main_en.md`）还是分章 `ch*.md`？**优先用拼装稿**。
2. **目标引擎 / 保真档位**：
   - **pdflatex 全转换（最高保真、arXiv 最稳）**：所有 unicode→LaTeX 命令，默认推荐。
   - **xelatex + unicode-math（较快、中保真）**：保留 unicode 字形，仍须 `$` 定界；
     arXiv 需在提交表单选 xelatex 引擎（`00README` 为兜底，非主渠道）。
   - 默认：**pdflatex 全转换**。
3. **目标模板**：arXiv 默认 `article`，或指定期刊 class（如 `elsarticle`/`amsart`）。默认 `amsart`（含定理环境）。

推断完成后输出一行确认摘要再启动（参照 academic-paper 的确认格式）。

**AskUserQuestion 触发规则（满足任一才打断，否则一律自动推断并在确认摘要中告知）**：
1. 源文件无法在工作目录下用 glob 唯一确定（候选 >1 且无法判定主稿）；
2. 检测到源文件含 CJK 字符（需 xelatex）但用户未指定引擎；
3. 需安装任意工具链组件（无论原因，系统变更强制确认）；
4. Phase 1 spot-check 不通过且重试 2 次仍失败（见 Phase 1）。

---

## 核心流程（6 阶段）

```
Markdown 终稿
      │
      ▼
 Phase 0  Preflight：工具链体检 + 源盘点 + 难点量化
      │   （无 pandoc/tectonic → 征得同意后 brew 安装）
      ▼
 Phase 1  数学定界 + unicode 转换（按章 Agent，最关键）
      │
      ▼
 Phase 2  结构→LaTeX：pandoc + 模板 + amsthm 定理环境
      │
      ▼
 Phase 3  refs.md → .bib + 行内引用转 \cite
      │
      ▼
 Phase 4  编译验证：tectonic/xelatex → 查未定义引用/溢出框/页数，迭代
      │
      ▼
 Phase 5  arXiv 打包：.bbl + 00README + 扁平化 + tar.gz + 终检清单
```

工作目录 `$BUILD_DIR`（**绝对路径**，Phase 0 确定后贯穿全流程）：优先 `$SCRATCH_DIR`，
无则 `$(dirname <源文件绝对路径>)/arxiv-build`。协调者在 Phase 0 用 `realpath` 定下并 `mkdir -p`。
**所有阶段与子 Agent 一律用 `$BUILD_DIR` 绝对路径定位产物**（子 Agent 沙箱不继承环境变量，须经 prompt 参数显式传入）。
**不覆盖原 Markdown**；所有产物写入 `$BUILD_DIR`。

---

## Phase 0 — Preflight

```bash
for t in pandoc tectonic xelatex pdflatex latexmk; do command -v $t >/dev/null && echo "$t OK" || echo "$t MISSING"; done
```

- 缺 `pandoc`：`brew install pandoc`。
- 缺 TeX 引擎：**首选 `brew install tectonic`**（自包含、按需下包、无需 4GB MacTeX；
  底层 xetex，天然支持 unicode）。需纯 pdflatex 可 `brew install --cask basictex`。
  ⚠️ **tectonic 首次编译会联网按需下载宏包/字体（数分钟、数百 MB）**，须提前告知用户别误判为卡死。
- **装任何东西前必须向用户确认**（系统变更）。
- **[MUST] ABORT 路径**：若缺工具 **且** 用户拒绝安装（或非 macOS、无 brew），**立即中止**并输出
  缺失清单 + 手动安装指引，**不得带着缺失工具跑到 Phase 4 才崩**。宁可早停，不做半成品。

源盘点与难点量化（决定 Phase 1 工作量）：
```bash
cd "$(dirname <源文件绝对路径>)"
grep -c '\$' main_en.md                 # 0 → 裸 unicode 场景，走完整 Phase 1
grep -oE '[≤≥−⟺⟹⊆⊇∈∉∅≠∀∃√·×φψσδΔαβμ₀-₉⁺⁻]' main_en.md | sort | uniq -c | sort -rn
wc -l main_en.md refs.md
```

把结果写进启动摘要（"本稿 0 处 `$`、N 个 unicode 数学字符、M 条引用"），让用户对工作量有预期。

**[MUST] 确定 `$BUILD_DIR`（绝对路径，供后续所有阶段与子 Agent 使用）**：
```bash
SRC="$(realpath <源文件>)"
BUILD_DIR="${SCRATCH_DIR:-$(dirname "$SRC")/arxiv-build}"
mkdir -p "$BUILD_DIR/phase1"
```
后续子 Agent 不继承此变量，必须在各自 prompt 里以参数显式传入 `$BUILD_DIR` 的绝对值。

---

## Phase 1 — 数学定界 + unicode 转换（最关键）

**判断分支：**
- 源**已用 `$...$`**：跳过定界，仅对数学内文做 unicode→LaTeX 字符替换（见 `references/unicode-to-latex.md`）。
- 源**裸 unicode（0 处 `$`）**：必须先定界再转换。定界需语义判断（区分"正文里的 φ 符号" vs "普通文字"），
  **按章派 Agent 完成**——这是全流程唯一不能纯脚本化的步骤。

**按章 Agent 定界/转换**（对每个 `ch*.md` 或把 `main_en.md` 切成 ~200 行块并行）：

> 任务：把下面这段 Markdown 学术正文转成 LaTeX 正文片段。规则：
> 1. 把所有数学表达式（变量、公式、不等式、集合、下标上标）用 `$...$` 行内定界，
>    独立成行的公式用 `\[ ... \]` 或 `equation` 环境。
> 2. 按 `references/unicode-to-latex.md` 的映射表把 unicode 数学符号转成 LaTeX 命令
>    （pdflatex 档）或保留 unicode（xelatex 档，按本次档位）。
> 3. **不改动任何数学内容/措辞/符号方向**（φ(P₀)>0 不得写成 =0 等），只做定界与转义。
> 4. 定理/引理/推论/命题的陈述标出，交 Phase 2 包进 amsthm 环境。
> 5. 行内反引号里的 Lean 标识符（如 `` `phi_addBuy` ``）转成 `\texttt{phi\_addBuy}`，**保持原名**。
> 6. **产物落地（契约）**：把 LaTeX 片段写入 `$BUILD_DIR/phase1/block_<N>.body.tex`（`<N>` 为块序号，
>    `$BUILD_DIR` 由 prompt 参数传入的绝对路径，**禁止相对路径**）；把"本段定界判断说明"写入
>    `$BUILD_DIR/phase1/block_<N>.notes.md`，供抽检。
> 返回文本仅为一行状态（块号 + 行数），完整产物以上述文件为准。

**[契约] 合并**：所有块 Agent 返回后，协调者按块序合并为 Phase 2 的显式输入：
```bash
cat "$BUILD_DIR"/phase1/block_*.body.tex > "$BUILD_DIR/phase1_merged.body.tex"
```
（`block_*` 按零填充序号排序，如 `block_01` `block_02`，确保 `*` 展开顺序正确。）

**[MUST] 定界后抽检**：随机抽 3–5 段比对原文，确认（a）无数学内容被改动；
（b）无把普通文字误定界；（c）符号方向/下标无漂移。学术论文最大风险是转换引入数学错误，必须人工抽检或交叉 Agent 复核。

**[MUST] 抽检结果处理（闭环，不得省略分支）**：
- **(a) 全部通过** → 写 `$BUILD_DIR/phase1_done.flag`，进入 Phase 2。
- **(b) 数学内容被改动**（符号方向/上下标/算符漂移）→ 对出问题的块**重新派 Agent 重做**，最多 2 次；
  仍不通过 → `AskUserQuestion` 向用户呈报问题段落的原文↔产物对比并**暂停**，不得继续。
- **(c) 误定界**（普通文字被当数学定界）→ 派 Agent 修正该块后重新抽检。
- **(d) 门禁**：`$BUILD_DIR/phase1_done.flag` 不存在时，**Phase 2 不得启动**。

---

## Phase 2 — 结构 → LaTeX

**输入**：`$BUILD_DIR/phase1_merged.body.tex`（Phase 1 合并产物；须先确认 `phase1_done.flag` 存在）。
**输出**：`$BUILD_DIR/main_draft.tex`（preamble + body，尚未转 `\cite`，交 Phase 3）。

- **决策树（二选一，避免双重转换）**：
  - Phase 1 Agent 已产出**完整 LaTeX body**（含 `\section`/`\subsection` 结构）→ **直接拼 preamble，跳过 pandoc**。
  - Phase 1 只产出**带 `$` 定界的 Markdown**（未转完整 LaTeX 语法）→ 用 pandoc 转结构：
    `pandoc phase1_merged.body.tex --to=latex -o body.tex`。
  - **默认走前者**（Phase 1 Agent prompt 已要求产出完整 LaTeX 片段）；**切勿对已是 LaTeX 的内容再跑 pandoc**。
- preamble + 定理环境见 `references/latex-template.md`（amsthm 的 theorem/lemma/corollary/
  proposition/definition + 共享计数器）。
- 把 Phase 1 标出的定理陈述包进对应环境；证明用 `proof` 环境，`∎`/QED 交给环境自动生成。
- 表格：Markdown 表 → pandoc `longtable`/`booktabs`；宽表加 `\small` 或 `adjustbox`。

---

## Phase 3 — 引用 → BibTeX

**契约（I/O 锁定）**：输入 `$BUILD_DIR/main_draft.tex`（Phase 2 输出），输出
`$BUILD_DIR/main.tex`（已转 `\cite` 版）+ `$BUILD_DIR/refs.bib` + `$BUILD_DIR/cite_map.tsv`
（原文写法 → bib key 对应表）。完成后写 `$BUILD_DIR/phase3_done.flag`，Phase 4 检测存在后才启动。

**多写法变体统一**：同一引用在正文常有多种写法（`Han et al. (2022)`、`Han (2022)`、
`(Han et al., 2022)`），须全部映射到同一 key。做法：`grep -nP` 枚举全部变体 → `cite_map.tsv`
每个变体单列一行指向同一 key → 按行 `sed` 替换，避免漏替或重复替。

- 解析 `refs.md`（或正文文末参考文献）为 `refs.bib`。每条尽量补全
  `author/title/journal/year/volume/doi`（DOI 常已在文中，如本样例 `10.1016/j.pacfin.2022.101160`）。
- 行内引用 `Han et al. (2022)` → 建立 key（`han2022`）→ 文中改 `\citet{han2022}` / `\citep{...}`
  （natbib）。作者年制期刊用 `natbib`+`plainnat`；数学类可用 `amsrefs` 或 `alpha`。
- 若引用是外部已发表成果（非本文结果），保持原样引用，别误转成本文定理。

**[MUST] natbib 转换前先做年份一致性检查（防年份漂移）**：源稿正文的作者年份常与 `refs.md`
不一致（如正文写 `Muni Toke (2014)`，但 refs 里是 2015——arXiv 版年 vs 期刊出版年）。
natbib `\citet{key}` 会**按 bib 条目年份重排**，把正文的 "2014" 显示成 "2015"——这是**改动内容**。
做法：枚举每个行内引用的年份 ↔ 对应 refs 条目年份，若**存在任一不一致**：
- **不要**强转 natbib；改走 **thebibliography 回退档**（见下），保留正文引用字面原样；
- 或在 `cite_map.tsv` 标红不一致条目，征询用户后再定。

**thebibliography 回退档（推荐用于年份不一致 / 不想引入 natbib 的场景）**：
正文引用**保持 Phase 1 产出的字面文本**（不转 `\cite`），参考文献用内嵌
`\begin{thebibliography}{99} \bibitem{key} ... \end{thebibliography}` 直接写进 `main.tex`。
优点：零年份漂移、零 key 映射错误、**arXiv 无需 `.bbl`/`.bib`**（文献已内嵌），打包最简。
忠实源 `refs.md` 的编号（若源是 1..N 编号列表，用 `{99}` 数字档正好对应）。
此时**不加 natbib / 不写 `\bibliography`**；页尾 `\S`、`&`、`--`、`\textsuperscript` 等照常转义。
**CJK 文献**（中文期刊/规则）在 pdflatex 档**必须罗马化/英译**（标 `[In Chinese.]`），否则缺字编译失败。

---

## Phase 4 — 编译验证

前置：确认 `$BUILD_DIR/phase3_done.flag` 存在再编译。
```bash
cd "$BUILD_DIR"
tectonic --keep-intermediates main.tex   # 须 --keep-intermediates 才落盘 .bbl（Phase 5 打包用）
                                          # 或 latexmk -xelatex / -pdf main.tex
```
> **tectonic 底层是 XeTeX**：对正文数学无影响（已全转命令），但 **`verbatim`/`listings` 里的
> 裸 unicode 会静默丢字**（见 `latex-template.md` 代码块小节，用 `escapeinside`）。

验证清单（**全绿才算过**）：
- [ ] 编译退出码 0，产出 `main.pdf`。
- [ ] 日志无 `Undefined control sequence`（漏转的 unicode/命令）。
- [ ] 日志无 `Missing character`（**另一类静默丢字**，常见于代码块裸 unicode；
      `tectonic --print main.tex 2>&1 | grep 'Missing character'` 必须为空）。
- [ ] 无 `LaTeX Warning: Reference ... undefined` / `Citation ... undefined`。
- [ ] `Overfull \hbox` 超过 ~20pt 的逐个处理（宽公式拆行；**所有宽表统一包
      `\begin{adjustbox}{max width=\textwidth}`**，只在超宽时缩放，安全）。
- [ ] running head 若每页 Overfull（几百 pt）→ 设 `\title[短标题]{...}`（见 template）。
- [ ] 页数合理（和 Markdown 篇幅量级一致，防止大段内容丢失）。

**[MUST] 迭代上限与失败升级**：修复方向——未定义命令回 `references/unicode-to-latex.md` 补映射；
未定义引用回 Phase 3。**每轮 = 一次修复 + 一次编译，最多 3 轮**；第 3 轮仍未全绿即**停止迭代**，输出：
- 编译日志末 ~20 行摘要；
- 错误类型 → 对应 `references/arxiv-packaging.md` 速查表行；
- 人工介入建议，并写入 `EXPORT_REPORT.md` 的「未解决问题」节。

---

## Phase 5 — arXiv 打包

细节见 `references/arxiv-packaging.md`。要点：
- **文献打包二选一**：
  - 走 **natbib + `\bibliography`** 档 → **必须包含 `.bbl`**（arXiv 不保证重跑 bibtex）：本地
    `bibtex main` 生成后一并打包；可不含 `.bib`。tectonic 须 `--keep-intermediates` 才落盘 `.bbl`。
  - 走 **内嵌 `thebibliography`** 档（Phase 3 回退档）→ **无需 `.bbl`/`.bib`**，文献已在 `main.tex` 内，
    打包只放 `main.tex`（+ `00README.XXX`），最简最稳。
- **引擎声明**：arXiv 支持 pdflatex / xelatex（**不支持 lualatex**）。选引擎以 **arXiv 提交表单**为准；
  走 xelatex 时在表单选 xelatex，`00README.XXX` 仅作兜底声明。pdflatex 档无需任何声明
  （`\pdfoutput=1` 为可选保险，非必需）。
- **扁平化**：所有 `\input`/图片放同一层，无绝对路径、无 `~`。
- 字体：pdflatex 档用 TeXLive 自带包；xelatex 档若指定非自带字体须随包携带或改用 TeXLive 自带数学字体。
- 打包：`tar czf submission.tar.gz main.tex main.bbl *.sty figures/ 00README.XXX`。
- **终检清单**（逐项勾）：见 packaging 参考文件尾部。

---

## 交付

- `<build_dir>/main.pdf` — 本地校样。
- `<build_dir>/submission.tar.gz` — arXiv 上传包。
- `<build_dir>/EXPORT_REPORT.md` — 转换记录：工作量、定界抽检结论、编译告警处置、未决事项。
- 向用户中文汇报：PDF 页数、关键告警是否清零、arXiv 包是否通过终检清单。

## 参考资源

- `references/unicode-to-latex.md` — unicode→LaTeX 数学符号完整映射 + 转换规则 + 常见漏网字符。
- `references/latex-template.md` — preamble + amsthm 定理环境 + article/amsart 模板。
- `references/arxiv-packaging.md` — arXiv 打包规则、引擎声明、.bbl、00README、tar.gz、终检清单。
