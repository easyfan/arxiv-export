# arXiv 打包规则与终检清单

Phase 5 用。arXiv 在**自家 TeXLive**重新编译你的源码，所以本地能编译 ≠ arXiv 能编译。

## 1. 文献：.bbl 档 vs 内嵌 thebibliography 档

**先确定走哪档**（Phase 3 已决定）：

- **内嵌 `thebibliography` 档（最简，推荐在年份不一致 / 无 natbib 场景）**：文献直接写进
  `main.tex`（`\begin{thebibliography}...\bibitem...\end{thebibliography}`），**无需 `.bbl`/`.bib`，
  不跑 bibtex**。打包只放 `main.tex`（+ `00README.XXX`）。跳过本节其余 .bbl 步骤。
- **natbib + `\bibliography` 档**：见下，**必须包含 `.bbl`**。

## 1b. natbib 档：必须包含 .bbl（最常见翻车点）

arXiv 不保证重跑 bibtex。标准做法：本地编译一轮生成 `.bbl`，把它当源码一起上传。
```bash
cd <build_dir>
pdflatex main      # 或 xelatex
bibtex  main       # 生成 main.bbl
pdflatex main
pdflatex main      # 交叉引用稳定
```
- 上传包里**带 `main.bbl`**。可以**不带 `refs.bib`**（带了也无害，但 `.bbl` 是权威）。
- 若用 tectonic 编译：它**默认不把 `.bbl` 等中间文件写到磁盘**，直接 `tectonic main.tex` 后找不到 `.bbl`。
  必须加 `--keep-intermediates`（可配 `--keep-logs`）：`tectonic --keep-intermediates main.tex`，
  再把生成的 `main.bbl` 抽出来放进上传包。

## 2. 引擎声明（xelatex 档必做）

arXiv 官方 TeXLive 支持的引擎为 **pdflatex / latex+dvips / xelatex**（及 plain tex 类），
**不支持 lualatex**——所以本 skill 只在 pdflatex / xelatex 两档间选，别用 lualatex。
- **选引擎的权威方式是 arXiv 提交页面的处理表单**（web form 里直接选 pdflatex / xelatex），
  不是靠 `00README.XXX`。首选在表单里选对引擎。
- `00README.XXX`（纯文本放工程根）是**辅助/兜底**手段，可用 `engine` 行等声明，但以表单为准：
  ```
  engine: xelatex
  ```
- 若能用 pdflatex 就用 pdflatex（全 unicode 已转命令），免去引擎问题——**这也是默认推 pdflatex 档的原因**。
- `\pdfoutput=1`（置于导言区首行附近）用于让 pdflatex 强制直接产出 PDF（而非 DVI）。
  现代 arXiv 在表单已选 pdflatex 时并不要求它，加之无害、不加也行，属可选保险。

## 3. 扁平化与路径

- 所有 `\input`/`\include` 的子文件、`.sty`、图片放**同一目录层级**，或用相对子目录 `figures/`。
- **禁止**绝对路径、`~`、`/Users/...`。`grep -rn '/Users/\|~/' *.tex` 应为空。
- 自定义 `.sty`/`.cls` 必须随包携带（除非是 TeXLive 标准包）。

## 4. 图片

- arXiv 接受 `.pdf/.png/.jpg`（pdflatex）或 `.eps`（配 `epstopdf`）。无 `.svg`。
- 本样例论文无图；若有，确认 `\includegraphics` 路径相对、文件已入包。

## 5. 字体（xelatex 档专有坑）

- 只用 TeXLive 自带字体（Latin Modern Math / TeX Gyre 系列 / STIX Two Math）。
- 用了系统私有字体（如某商业字体）→ arXiv 无此字体编译失败。改用自带字体或嵌入。

## 6. 打包命令

```bash
cd <build_dir>
tar czf submission.tar.gz \
  main.tex main.bbl \
  $(ls *.sty 2>/dev/null) \
  $(ls -d figures 2>/dev/null) \
  $(ls 00README.XXX 2>/dev/null)
tar tzf submission.tar.gz        # 列内容复核
```
不要把 `.aux .log .out .pdf .bib`（可选）塞进去（无害但不整洁；`.pdf` 不要，arXiv 自己生成）。

## 7. 终检清单（逐项勾，全绿才交付）

- [ ] 干净目录重编译通过：`rm -f *.aux *.bbl *.blg *.out && pdflatex→bibtex→pdflatex×2` 退出码 0。
- [ ] 日志零 `Undefined control sequence`（= 无漏转 unicode/命令）。
- [ ] 日志零 `Reference ... undefined` / `Citation ... undefined`。
- [ ] 所有 `\ref`/`\cite`/`\cref` 解析正确，定理编号与原 Markdown 一致（抽查 Theorem 1–4 等）。
- [ ] `grep -nP '[^\x00-\x7F]' main.tex` 无残留数学 unicode（pdflatex 档）。
- [ ] 无绝对路径：`grep -rn '/Users/\|/home/\|~/' *.tex` 为空。
- [ ] 页数与 Markdown 篇幅量级一致（防内容整段丢失）。
- [ ] `submission.tar.gz` 含 `main.tex` + `main.bbl`（+ 必要 sty/figures/README），不含绝对路径。
- [ ] 数学内容抽检：随机 5 处公式与原 Markdown 逐字符比对，符号方向/上下标无漂移。
- [ ] （可选但推荐）在 Overleaf 上传 tar.gz 用对应引擎试编译一次，模拟 arXiv 环境。

## 常见报错速查

| 症状 | 原因 | 处置 |
|---|---|---|
| `Undefined control sequence \xxx` | 漏转 unicode 或拼错命令 | 回 `unicode-to-latex.md` 补映射 |
| `Citation 'xxx' undefined` | key 不在 .bib 或没跑 bibtex | 补条目 / 重跑 bibtex→pdflatex×2 |
| `Theorem 7.1` 而非 `Theorem 4` | amsthm 用了 `[section]` | 去掉 `[section]` 用全局连续编号 |
| arXiv "unable to compile" | 缺 .bbl 或需 xelatex 未在表单选对 | 带 .bbl / 提交表单选 xelatex（00README 为兜底） |
| 宽表/宽公式溢出 | 超 `\textwidth` | `adjustbox`/`\small`/`\resizebox`/拆行 |
| 字体找不到（xelatex） | 用了系统私有字体 | 改 TeXLive 自带字体 |
