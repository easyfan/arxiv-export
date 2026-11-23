# LaTeX 模板 + 定理环境

Phase 2 用。按本次档位选 preamble；定理环境是数学/理论论文的刚需。

## 默认 preamble（amsart，pdflatex 档，arXiv 最稳）

```latex
\documentclass[11pt]{amsart}
\usepackage[utf8]{inputenc}     % pdflatex 必需；但所有数学 unicode 应已转成命令
\usepackage[T1]{fontenc}
\usepackage{amsmath, amssymb, amsthm, mathtools}
\usepackage{bbm}               % \mathbbm{1} 指示函数
\usepackage{booktabs, longtable, array}
\usepackage{adjustbox}         % 宽表 \begin{adjustbox}{max width=\textwidth}
\usepackage[numbers,sort&compress]{natbib}  % 作者年制改 [round,authoryear]
\usepackage{hyperref}
\usepackage{cleveref}

% ---- 定理环境（共享一个计数器，按 section 编号）----
\theoremstyle{plain}
\newtheorem{theorem}{Theorem}[section]
\newtheorem{lemma}[theorem]{Lemma}
\newtheorem{corollary}[theorem]{Corollary}
\newtheorem{proposition}[theorem]{Proposition}
\theoremstyle{definition}
\newtheorem{definition}[theorem]{Definition}
\newtheorem{remark}[theorem]{Remark}

\title{<标题>}
\author{<作者>}
\date{\today}

\begin{document}
\maketitle
\begin{abstract}
<摘要>
\end{abstract}

<正文>

\bibliographystyle{plainnat}   % 数学类可用 amsplain/alpha
\bibliography{refs}
\end{document}
```

> **编号一致性关键**：原 Markdown 常是全局顺序编号（Theorem 1,2,3,4…）。若作者正文里
> 用"Theorem 4"这种**连续编号**互相引用，amsart 默认 `[section]` 会变成 "Theorem 7.1"。
> 二选一：(a) 去掉 `[section]`，用 `\newtheorem{theorem}{Theorem}` 全局连续编号，匹配原稿；
> (b) 保留 section 编号但全局替换正文里的"Theorem N"为 `\cref{thm:...}`。
> **默认选 (a)**，最忠实 Markdown 原编号。务必和原稿核对编号不漂移。
>
> **各类独立计数器**：若原稿 Theorem / Lemma / Corollary / Proposition **各自从 1 连续编号**
> （如同时有 "Theorem 1-4" 和 "Lemma 1-3"），则**不要**用 `[theorem]` 共享计数器，改各自独立：
> `\newtheorem{lemma}{Lemma}`（无方括号）。无编号陈述（原稿 "**Definition.**" / "**Corollary.**"
> 不带号）用 `\newtheorem*{definition}{Definition}` 保持无编号，别让它挤占计数器导致后续漂移。

> **长摘要 → 首页空白坑**：`amsart` 用 `[11pt]` + 多段长摘要时，`\maketitle` 可能把整段摘要
> 挤到第 2 页，首页只剩标题（空荡）。**默认用 amsart 本体 10pt（即 `\documentclass{amsart}`，
> 不加 `[11pt]`）**，标题+摘要通常同处首页，也更合数学论文惯例。`abstract` 环境须置于
> `\maketitle` **之前**（amsart 要求）。

> **超长标题 → running head 溢出**：amsart 页眉放标题，长标题会每页 Overfull（几百 pt）。
> 用 `\title[短标题]{长标题}` 和 `\author[F. Zheng]{Fan Zheng}` 的**方括号可选参数**设 running head。

## 代码块 / Lean 片段里的 unicode（listings，重要坑）

论文含 Lean/代码块时，代码里常有真实语法 unicode（`→ ¬ φ ⁺ − ≤` 等）。处理要点：

1. **别用 `verbatim`**：pdflatex 等宽字体（lmtt）无这些字形 → `Missing character` **静默丢字**（数据丢失）。
2. **listings `literate` 在 XeTeX/tectonic 下不触发**（实测：仍报 Missing character）。
   **可靠做法是 `escapeinside` + 预处理转义**，逐字符保留真实字形、引擎无关：
   ```latex
   \usepackage{listings}
   \lstset{basicstyle=\ttfamily\small, breaklines=true, columns=fullflexible,
           keepspaces=true, escapeinside={(*@}{@*)}}
   ```
   然后把代码块里的 unicode 重写成转义（Lean 4 无 `(* *)` 注释，定界安全）：
   `φ`→`(*@$\varphi$@*)`、`ψ`→`(*@$\psi$@*)`、`→`→`(*@$\rightarrow$@*)`、
   `¬`→`(*@$\neg$@*)`、`−`→`(*@$-$@*)`、`⁺`→`(*@\textsuperscript{+}@*)`、
   `≤`→`(*@$\le$@*)`、`≥`→`(*@$\ge$@*)`（只在 `lstlisting` 块内替换，用 DOTALL 正则逐块处理）。
3. 替代档：XeLaTeX 下可 `fontspec` 设含这些字形的等宽字体（如 DejaVu Sans Mono），但 `⁺`(U+207A)
   等上标字形覆盖不全，且引入字体依赖——**首选 escapeinside**。
4. **长 `\texttt{...}` 标识符溢出**（如 `\texttt{addBuy\_lower\_mono}/\texttt{addBuy\_upper\_mono}`）：
   导言区加 `\usepackage{microtype}` + `\emergencystretch=3em` + `\sloppy` 基本可消。

## xelatex 档 preamble（保留 unicode 字形）

把上面前几行换成：
```latex
\documentclass[11pt]{amsart}
\usepackage{fontspec}
\usepackage{unicode-math}
\setmainfont{Latin Modern Roman}      % 或 TeX Gyre Pagella
\setmathfont{Latin Modern Math}       % 完整 unicode 数学字体，TeXLive 自带
% 中文混排（英文稿一般不需要）：\usepackage{xeCJK}\setCJKmainfont{Noto Serif CJK SC}
```
其余（amsthm/定理环境/natbib/hyperref）不变。**注意**：`inputenc`/`fontenc` 在 xelatex 下
不要加。unicode 数学符号可保留，但仍须 `$` 定界。

## 定理/证明包装示例

Phase 1 Agent 会标出哪段是定理陈述。包装成：
```latex
\begin{theorem}[P1 的正向充要刻画]\label{thm:p1-char}
<定理陈述，数学已定界>
\end{theorem}
\begin{proof}
<证明；原文的 ∎ / QED 删掉，环境自动生成>
\end{proof}
```
- 行内引用 Lean 名：`machine-verified (Lean: \texttt{P1\_characterization})`。**下划线必须转义** `\_`。
- 外部引用保持不动（如 `produce\_UM`、`Madhavan (1992)`）。

## 表格转换

Markdown 表 → booktabs：
```latex
\begin{table}[htbp]\centering
\begin{adjustbox}{max width=\textwidth}
\begin{tabular}{llll}
\toprule
<表头> \\ \midrule
<行> \\
\bottomrule
\end{tabular}
\end{adjustbox}
\caption{<标题>}\label{tab:xxx}
\end{table}
```
表元里若有数学，同样要 `$` 定界。
