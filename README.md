# Institutional Investor Distraction & M&A Activity

> Replication and extension of Kempf, Manconi & Spalt (2017): does institutional investor distraction causally increase the probability of merger activity?

**Authors:** Leonardo Trapani, Tre' McMillan, Sebastian Czarnietzki, Novi van der Voort
**Institution:** Erasmus School of Economics — February 2026

## Overview

When institutional investors are distracted by extreme return events in *other* industries they hold, their monitoring of portfolio firms weakens. This project constructs a firm-quarter **distraction measure D(f,q)** following the KMS framework and estimates its causal effect on merger and acquisition activity using high-dimensional fixed-effects regressions on 40+ years of US equity data (1980–2025).

## Research Question

*Does a reduction in institutional monitoring — proxied by investor distraction — causally increase the likelihood and type of M&A activity at the firm level, and does this effect vary with the availability of alternative monitors and the severity of agency frictions?*

## Data Sources

| Dataset | Description |
|---|---|
| Thomson Reuters 13F | Quarterly institutional holdings (manager, CUSIP, shares, price) |
| CRSP | Daily and quarterly stock returns |
| Compustat | Financial statement data (size, Tobin's Q, cash flow, etc.) |
| SDC Platinum / Eikon | Merger announcement data |
| Fama-French 12 industries | Industry classification and quarterly returns |

**Sample:** 306,144 firm-quarter observations, 5,634 unique US public firms, 1980–2010 (replication) / 1980–2025 (extensions). Micro-cap firms excluded (below 20th NYSE market cap percentile); minimum 20 quarterly observations per firm.

> **Note:** All datasets are proprietary (WRDS/Compustat/SEC EDGAR/SDC). The code is fully documented and replicable given access to the underlying data sources.

## Methodology

### Step 1 — Constructing D(f,q) [`CODE_firstpart.do`]

Following KMS equation (1), for each fund `f` and quarter `q`:

```
D(f,q) = Σ_i  w(i,f,q) · [Σ_j≠i  w(j,f,q) · Extreme(j,q)]
```

Where:
- `w(i,f,q)` = composite weight combining portfolio weight quintile and percentage ownership quintile
- `Extreme(j,q)` = indicator for extreme return in industry `j` in quarter `q` (highest or lowest among FF12 industries)

The measure is aggregated to the **firm-quarter** level (`D_fq`) by summing over all institutional owners.

### Step 2 — Regression Analysis [`CODE_FOR_RESULTS.do`]

**Main specification:**
```
M&A_outcome(i,q) = α + β·D_fq(i,q) + γ·Controls + FE + ε
```
- Fixed effects: industry×quarter (IQ FE) and firm FE
- Controls: log size, Tobin's Q, cash flow, cash holdings, IO, top-5 share, momentum
- Standard errors clustered at firm level

## Summary Statistics (Table 1)

| Variable | Mean | SD | Median | N |
|---|---|---|---|---|
| Merger (any) | 2.7% | 0.161 | 0 | 306,144 |
| Diversifying merger | 0.6% | 0.081 | 0 | 306,144 |
| Within-industry merger | 2.0% | 0.141 | 0 | 306,144 |
| Distraction D | 0.135 | 0.095 | 0.121 | 306,144 |
| Institutional ownership | 54.8% | 0.261 | 57.3% | 306,144 |
| Top-5 IO share | 14.3% | 0.087 | 12.6% | 306,144 |

## Key Results

### Table 2 — Main Replication (1980–2010)

| Outcome | β (IQ FE only) | t-stat | β (IQ + Firm FE) | t-stat |
|---|---|---|---|---|
| All mergers | **0.055** | 3.44*** | 0.019 | 1.27 |
| Diversifying | **0.028** | 2.89*** | 0.017 | 1.78* |
| Within-industry | **0.032** | 2.50** | 0.006 | 0.52 |

**Economic magnitude:** 1-SD increase in distraction (SD = 0.095) → merger probability +19.4% relative to baseline (2.68%). KMS benchmark: 29%. The smaller magnitude reflects lower merger activity post-2000 in our extended sample.

**Moving average (D_MA(−2,0)):** β = 0.105 (t = 3.45***) — effect strengthens when distraction is measured over the full typical deal preparation window.

### Table 3 — Substitution by Alternative Monitors

- **Low IO breadth firms:** distraction effect = 0.090 (t = 5.24***)
- **High IO breadth firms:** distraction effect = 0.057 — i.e. **37% weaker** when more attentive institutional investors are present
- Interaction coefficient: −0.034 (t = −4.53***), robust to firm FE: −0.023 (t = −3.16***)

### Table 4 — Agency Frictions

- **Low top-5 blockholder concentration:** interaction = −0.021 (t = −3.08***) — tighter baseline monitoring amplifies the distraction effect
- **High free cash flow:** interaction = +0.014 (t = 2.18**) — consistent with Jensen (1986) empire-building hypothesis
- Total distraction effect: 0.075 (high FCF) vs. 0.061 (low FCF)

### Identification — Placebo Test

- D_lead4 coefficient = −0.003 (t = −0.17, p = 0.87) → future distraction does not predict current mergers, supporting causal interpretation

## Repository Structure

```
├── CODE_firstpart.do          # Builds DISTRACTION_FINAL.dta from raw 13F + FF12 data
├── CODE_FOR_RESULTS.do        # Loads panel dataset, produces Tables 1–4
└── README.md
```

## Requirements

- **Stata 17** or later
- Packages: `reghdfe`, `gcollapse`, `gegen`, `gquantiles` (from `gtools`), `estout`

Install packages:
```stata
ssc install reghdfe
ssc install gtools
ssc install estout
```

## References

- Kempf, E., Manconi, A., & Spalt, O. (2017). *Distracted shareholders and corporate actions.* Review of Financial Studies, 30(5), 1660–1695.
- Jensen, M.C. (1986). *Agency costs of free cash flow, corporate finance, and takeovers.* American Economic Review, 76(2), 323–329.
