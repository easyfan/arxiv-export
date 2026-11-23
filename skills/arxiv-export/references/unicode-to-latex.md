# unicode → LaTeX 数学符号映射

Phase 1 用。**pdflatex 档**：全部转成命令。**xelatex 档**：数学符号可保留 unicode（配
`unicode-math` + 完整数学字体），但下标上标 `₀ ⁺` 等仍建议转成 `_0 ^+` 以求稳。

## 规则总则

1. 只在**数学模式内**替换；正文里的 `—`（em dash）、`"" ''`（引号）、`×`（可作"乘"或正文"x"）按上下文。
2. 替换前先定界（见 SKILL.md Phase 1），别对未定界文字做全局 `sed`——会毁掉正文。
3. 下标多字符要加花括号：`x₁₀` → `x_{10}`；上标同理 `A⁺⁺`→`A^{++}`。
4. 希腊字母变体注意：`φ` 论文常指 `\varphi`（非 `\phi`），`ε`→`\varepsilon`，确认作者意图。

## 关系 / 逻辑

| unicode | LaTeX | | unicode | LaTeX |
|---|---|---|---|---|
| ≤ | `\le` | | ⟺ ⇔ | `\iff` / `\Leftrightarrow` |
| ≥ | `\ge` | | ⟹ ⇒ | `\implies` / `\Rightarrow` |
| ≠ | `\ne` | | → | `\to` |
| ≈ | `\approx` | | ↦ | `\mapsto` |
| ≡ | `\equiv` | | ∴ | `\therefore` |
| ∝ | `\propto` | | ∵ | `\because` |
| ≪ ≫ | `\ll` `\gg` | | ⊥ | `\perp` |

## 集合 / 量词

| unicode | LaTeX | | unicode | LaTeX |
|---|---|---|---|---|
| ∈ | `\in` | | ∅ | `\varnothing` / `\emptyset` |
| ∉ | `\notin` | | ∀ | `\forall` |
| ⊆ | `\subseteq` | | ∃ | `\exists` |
| ⊇ | `\supseteq` | | ∄ | `\nexists` |
| ⊂ ⊃ | `\subset` `\supset` | | ∩ ∪ | `\cap` `\cup` |
| ∖ | `\setminus` | | ∧ ∨ | `\land` `\lor` |
| ¬ | `\neg` | | ∣ | `\mid` |

## 运算 / 大算符

| unicode | LaTeX | | unicode | LaTeX |
|---|---|---|---|---|
| − | `-`（真减号，别留 unicode） | | · | `\cdot` |
| × | `\times` | | ± ∓ | `\pm` `\mp` |
| √ | `\sqrt{...}` | | ∞ | `\infty` |
| ∑ | `\sum` | | ∏ | `\prod` |
| ∫ | `\int` | | ∂ | `\partial` |
| ∇ | `\nabla` | | … ⋯ | `\dots` `\cdots` |
| ⌊ ⌋ | `\lfloor \rfloor` | | ⌈ ⌉ | `\lceil \rceil` |
| 𝟙 | `\mathbf{1}` / `\mathbb{1}`(bbm) | | ′ ″ | `'` `''`（prime） |

## 上标 / 下标

| unicode | LaTeX | | unicode | LaTeX |
|---|---|---|---|---|
| ⁺ | `^+` | | ₀₁₂₃₄₅₆₇₈₉ | `_0`..`_9` |
| ⁻ | `^-` | | ⁰¹²³⁴⁵⁶⁷⁸⁹ | `^0`..`^9` |

多位连写要括起来：`P′₀` → `P'_0`，`B⁺` → `B^+`，`V*₁` → `V^*_1`。

## 希腊字母（按需）

α`\alpha` β`\beta` γ`\gamma` δ`\delta` Δ`\Delta` ε`\varepsilon` θ`\theta`
λ`\lambda` μ`\mu` π`\pi` ρ`\rho` σ`\sigma` Σ`\Sigma` τ`\tau` φ`\varphi` ψ`\psi`
ω`\omega` Ω`\Omega`

## 正文（非数学）unicode

- em dash `—` → `---`（pdflatex）或保留（xelatex）。
- 中文引号 `""''` → `` `` '' ``（pdflatex+babel）或保留（xelatex+中文字体）。
- 不间断空格 ` ` → `~` 或普通空格。
- 全角括号/标点（中英混排稿里）：英文版应已是半角；若残留 `（）` → `()`。

## 常见"编译报 Undefined control sequence"的漏网字符

编译失败时优先 grep 这些：`⟨ ⟩`(`\langle \rangle`)、`∥`(`\|`)、`≔`(`:=`)、
`∘`(`\circ`)、`⊕`(`\oplus`)、`⊗`(`\otimes`)、`√`、`𝟙`、`ℝ ℕ ℤ ℚ`(`\mathbb{R}`…)、
`≱`/带删除线组合字符（需拆组合字符）。

验证全文无残留 unicode 数学字符（pdflatex 档，打包前必跑）：
```bash
grep -nP '[^\x00-\x7F]' main.tex | grep -vE '%|中文注释' | head
# 理想：仅剩正文允许的字符（或空）。有残留 → 回表补转。
```
