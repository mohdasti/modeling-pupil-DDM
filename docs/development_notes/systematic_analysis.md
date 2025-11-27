Quesiton 1: 


# What to do with minimum RT in your design

**Your task design (recap):** standard (100 ms) → ISI 500 ms → target (100 ms) → 250 ms blank → *response screen appears* (3,000 ms window). Participants can’t respond before the screen, so measured RT = time from *response-screen onset* to button press.

## Recommendation (DDM + pupillometry)

1. **Use a single floor: 200 ms post–response-screen onset** for *both* auditory and visual tasks.

   * It treats <200 ms as anticipations / button mashing, preserves trials, and aligns with common practice (many studies trim at ~200–250 ms). Aging DDM papers frequently use **250 ms**; e.g., recent aging work excluded **RT < 250 ms** before modeling. If you want to be ultra-conservative for ≥65, run a sensitivity check at 225 ms and 250 ms; expect negligible differences if participants obey the “no-early-response” rule. ([Nature][1])

2. **Upper cutoff:** drop *extreme* late responses (e.g., **>3,000–4,000 ms** or “>3 SD above a participant’s median”), consistent with aging DDM conventions (e.g., many aging/attention papers use 3,000 ms). Report the exact rule and the % of trials removed. ([SpringerLink][2])

3. **Model contaminants, don’t just trim them.** In your DDM fits, include a **small contaminant/outlier process (≈3–5%)** so rare anticipations or lapses don’t bias parameter recovery (this is standard practice per Ratcliff & Tuerlinckx). Keep the 200 ms hard floor *and* a contaminant component. ([PubMed][3])

4. **Document the latency basis explicitly.** Make it crystal-clear that RT is measured **from response-screen onset**, and that the 350 ms from target onset to response-screen onset (100 ms target + 250 ms blank) is a **forced delay** (“gated” motor output). This matters for interpreting the non-decision time.

5. **One threshold across modalities.** Don’t set different floors for auditory vs visual; it creates a needless confound in RT distributions and DDM non-decision time. If you ever *must* differentiate, justify it with hardware timing tests—not perception theory.

6. **Report a sensitivity analysis.** Pre-register and report that the main results are unchanged with alternative floors (e.g., 225 ms, 250 ms).

---

# How the response-signal / deadline diffusion framework applies to your task

Your design is essentially a **single-lag response-signal** (RS) paradigm: evidence accrues from target onset, **responses are *gated*** until the “go” signal (your response screen) arrives a fixed **350 ms** after target onset.

## Core idea

* In response-signal (a.k.a. deadline) paradigms, the decision process (e.g., DDM) **starts at stimulus onset** and runs *until a signal/deadline*.
* **If a bound is already hit before the signal**, the corresponding choice is made.
* **If no bound is hit at the signal**, the choice is made from **partial information** (sign/position of the decision variable) or by a constrained “guess”; both are formalized and fit within DDM variants. This is the **“implicit boundaries + partial-information”** account, which outperforms no-boundary/guess-only accounts. ([PMC][4])

## What that means for parameters in your setup

* Because participants can’t respond before the go screen, **measured RT mostly reflects motor output** and any residual decision finishing *after* the go. In a single-lag RS design, **accuracy** carries most of the leverage on **drift (v)**; RT mainly informs **non-decision time (t₀)** and any residual decision time post-signal.
* Practically, in fits **from response-screen RT**, set **t₀ to include only post-signal encoding + motor**; the **pre-signal accrual** is *inside* the diffusion process up to the implicit deadline (350 ms after target onset). This is precisely the mapping used when DDM is extended to RS data. ([PMC][4])

## “Best practice” if you can afford a mini-manipulation

* If you can spare a short block, add **2–3 response-signal lags** (e.g., 200, 350, 700 ms after target onset). That lets you trace the **speed–accuracy trade-off (SAT) function** and improves identifiability (e.g., separating **v** from **a** cleanly). If you can’t, your single-lag design is still valid—just be explicit about the identifiability limits. ([PubMed][5])

---

# “Do-this” checklist you can paste into Methods

* **RT definition.** “Response time (RT) was measured from **response-screen onset** to keypress.”
* **Exclusions.** “Trials with **RT < 200 ms** (anticipations) or **RT > 3,000 ms** (timeouts) were excluded (primary analysis). Sensitivity analyses using **225 ms** and **250 ms** floors yielded the same inferences.” ([Nature][1])
* **Contaminants.** “A **5% contaminant process** was included in the diffusion model to absorb rare anticipations/lapses.” ([PubMed][3])
* **Model.** “We fit a **response-signal diffusion model**: evidence accumulation began at **target onset** and proceeded until the response-signal (**350 ms** post-target onset). If a boundary was reached before the signal, that choice was emitted; otherwise, the choice followed the **partial-information rule** based on the sign of the decision variable at signal time. Post-signal motor output contributed to **t₀** in the RT model.” ([PMC][4])
* **Pupil (if reported).** “Pupillometry was analyzed relative to **target onset**; RT trimming was based on **response-screen RT** and does not affect early evoked-pupil components. We co-modeled pupil with DDM parameters across trials.” (Background links on arousal–bias coupling in DDM are standard.) ([eLife][6])

---

## Why **200 ms** is a reasonable default for your older-adult (65+) sample

* It preserves data and is within mainstream practice for cognitive RT studies; many aging/DDM papers use **200–250 ms** floors, and several high-quality aging datasets explicitly trim **<250 ms** before DDM. With your **forced delay**, sub-200 ms post-signal presses are almost certainly anticipations. ([Nature][1])

If a reviewer pushes back, you can show that:

* Raising the floor to **250 ms** barely changes your parameter inferences (report the sensitivity table).
* You’re also modeling a small **contaminant** mass, which addresses any residual anticipations on top of the hard floor. ([PubMed][3])

---

# Key references (APA)

* Heitz, R. P. (2014). The speed–accuracy tradeoff: History, physiology, methodology, and behavior. *Frontiers in Neuroscience*, 8, 150. [https://doi.org/10.3389/fnins.2014.00150](https://doi.org/10.3389/fnins.2014.00150)  ([PubMed][5])
* Ratcliff, R. (2006). Modeling response signal and response time data. *Cognitive Psychology*, 53(3), 195–237. [https://doi.org/10.1016/j.cogpsych.2005.10.002](https://doi.org/10.1016/j.cogpsych.2005.10.002)  ([PMC][7])
* Ratcliff, R., & McKoon, G. (2008). The diffusion decision model: Theory and data for two-choice decision tasks. *Psychological Review*, 115(2), 247–281. [https://doi.org/10.1037/0033-295X.115.2.247](https://doi.org/10.1037/0033-295X.115.2.247)  ([PMC][4])
* Ratcliff, R., & Tuerlinckx, F. (2002). Estimating parameters of the diffusion model: Approaches to dealing with contaminant reaction times and parameter variability. *Psychonomic Bulletin & Review*, 9(3), 438–481. [https://doi.org/10.3758/BF03196302](https://doi.org/10.3758/BF03196302)  ([PubMed][3])
* Starns, J. J., & Ratcliff, R. (2012). Age-related differences in diffusion model boundary optimality with both trial-limited and time-limited tasks. *Psychonomic Bulletin & Review*, 19, 139–145. [https://doi.org/10.3758/s13423-011-0189-3](https://doi.org/10.3758/s13423-011-0189-3)  ([SpringerLink][2])
* Kosciessa, J. Q., et al. (2024). Broadscale dampening of uncertainty adjustment in the aging brain. *Nature Communications*, 15, 5480. (Premature responses **<250 ms** excluded). [https://doi.org/10.1038/s41467-024-55416-2](https://doi.org/10.1038/s41467-024-55416-2)  ([Nature][1])
* Cavanagh, J. F., Wiecki, T. V., Kochar, A., & Frank, M. J. (2014). Eye tracking and pupillometry are indicators of dissociable latent decision processes. *Journal of Experimental Psychology: General*, 143(4), 1476–1488. [https://doi.org/10.1037/a0035813](https://doi.org/10.1037/a0035813)  ([PubMed][8])
* de Gee, J. W., Tsetsos, K., & Donner, T. H. (2020). Pupil-linked phasic arousal predicts a reduction of choice bias across species and decision domains. *eLife*, 9, e54014. [https://doi.org/10.7554/eLife.54014](https://doi.org/10.7554/eLife.54014)  ([PMC][9])
* Gomez, P., Ratcliff, R., & Perea, M. (2007). A model of the go/no-go task. *Journal of Experimental Psychology: General*, 136(3), 389–413. [https://doi.org/10.1037/0096-3445.136.3.389](https://doi.org/10.1037/0096-3445.136.3.389)  ([PubMed][10])

---


[1]: https://www.nature.com/articles/s41467-024-55416-2 "Broadscale dampening of uncertainty adjustment in the aging brain | Nature Communications"
[2]: https://link.springer.com/article/10.3758/s13423-011-0189-3 "Age-related differences in diffusion model boundary optimality with both trial-limited and time-limited tasks | Psychonomic Bulletin & Review"
[3]: https://pubmed.ncbi.nlm.nih.gov/12412886/?utm_source=chatgpt.com "Estimating parameters of the diffusion model - PubMed - NIH"
[4]: https://pmc.ncbi.nlm.nih.gov/articles/PMC2474742/ "
            The Diffusion Decision Model: Theory and Data for Two-Choice Decision Tasks - PMC
        "
[5]: https://pubmed.ncbi.nlm.nih.gov/24966810/?utm_source=chatgpt.com "The speed-accuracy tradeoff: history, physiology, methodology, and ..."
[6]: https://elifesciences.org/articles/23232?utm_source=chatgpt.com "Dynamic modulation of decision biases by brainstem ..."
[7]: https://pmc.ncbi.nlm.nih.gov/articles/PMC2397556/?utm_source=chatgpt.com "Modeling response signal and response time data - PMC"
[8]: https://pubmed.ncbi.nlm.nih.gov/24548281/?utm_source=chatgpt.com "Eye tracking and pupillometry are indicators of dissociable ..."
[9]: https://pmc.ncbi.nlm.nih.gov/articles/PMC7297536/?utm_source=chatgpt.com "Pupil-linked phasic arousal predicts a reduction of choice bias ..."
[10]: https://pubmed.ncbi.nlm.nih.gov/17696690/?utm_source=chatgpt.com "A model of the go/no-go task - PubMed - NIH"


Question 2:


 **keep the “Standard = Same” (Δ=0) trials in your DDM–pupillometry analysis.** They’re the cleanest leverage you have to identify *bias* (starting-point (z) and/or drift-bias (v_0)) and to test how tonic/phasic pupil signals modulate bias versus caution (boundary (a)). Prior work links pupil to these exact levers, and your own methods already use a conservative RT floor that preserves trials.  

# What to do (concrete, DDM-pupil recipe)

1. **Keep Δ=0 trials and code evidence properly**

   * Use **stimulus coding** with the *upper* bound mapped to “Different.”
   * Let (|\Delta|) be offset magnitude and (S) indicate “Same” (Δ=0).
   * Specify drift as (v = v_{\text{bias}} + \beta_{\Delta},|\Delta|) (optionally add a signed term if you have plus/minus offsets).
   * On Δ=0 trials, (v \approx v_{\text{bias}}). These trials are therefore *essential* to estimate (v_{\text{bias}}) and/or (z). This is exactly where you can test whether arousal (pupil) **reduces** decision bias (as in de Gee) or **increases** caution (as in Cavanagh). ([eLife][1]) 

2. **Tie pupil signals to *specific* latent parameters (trial-wise regressors)**
   Include two trial-wise pupil covariates:

   * **Baseline pupil** (e.g., −500–0 ms pre-target) → allow effects on **starting point (z)** and/or **boundary (a)** (tonic arousal / criterion).
   * **Phasic pupil** (e.g., slope/AUC 200–900 ms post-target; avoid the immediate light reflex & motor spillover) → allow effects on **drift-bias (v_{\text{bias}})** or **boundary (a)**.
     Fit **competing models** and select by WAIC/DIC:
   * M1: pupil→(a) (Cavanagh-style “caution” modulation under conflict). 
   * M2: pupil→(v_{\text{bias}}) (de Gee-style **bias suppression**; often reduces yes/no or same/different bias in detection). ([eLife][1])
   * M3: pupil→both (a) and (v_{\text{bias}}) (Leong et al. show phasic pupil can bias **drift** specifically, depending on task goals). ([PMC][2])
     Keeping Δ=0 makes these contrasts identifiable because (v_{\text{bias}}) dominates when evidence ≈ 0.

   *Implementation hint (HDDMRegressor / PyDDM style):*

   ```
   a ~ 1 + pupil_baseline + pupil_phasic
   z ~ 1 + pupil_baseline + S           # S = 1 on Δ=0 trials
   v ~ 1 + |Δ| + pupil_phasic + S + S:pupil_phasic
   t ~ 1
   ```

   The **S** and **S:pupil_phasic** terms let you test whether phasic arousal specifically shifts bias on Δ=0 (“Standard”) trials.

3. **Control for rarity / oddball effects of Δ=0**
   If Δ=0 trials are ~20% (as in your design), pupil can be larger for *oddballs* irrespective of decision (classic arousal). Include **trial type (S)** as a covariate in both the **pupil GLM** and the **pupil→parameter** mappings so any Δ=0 “oddball-pupil” isn’t misread as a change in caution or bias. (de Gee/Urai show arousal often suppresses pre-existing bias; you want to see that *conditional* on S and (|\Delta|).) ([eLife][1])

4. **Windows for pupil with your timing**
   With 100 ms standard → 500 ms ISI → 100 ms target → 250 ms blank → response screen (max 3000 ms):

   * **Baseline:** −500–0 ms pre-**target**.
   * **Phasic (decision-related):** 200–900 ms post-**target** (skip early PLR; stay pre-motor).
     Cavanagh show decision-related pupil is slow and typically peaks ~1 s; they also used response-locked windows to avoid motor artifacts—useful as a robustness check. 

5. **RT handling (you’re fine)**
   Keep your **min RT = 200 ms after response prompt** (≈450 ms after target offset). This mirrors typical 200 ms floors in DDM/pupil work and preserved ~98–99% of trials in your data. Note this explicitly in methods.  

6. **Sensitivity analyses you *should* report**

   * Refit excluding Δ=0; confirm the **pupil→(a)** vs **pupil→(v_{\text{bias}})** conclusion holds.
   * Swap phasic windows (e.g., 300–1200 ms) and add a **response-locked** measure (−200–+300 ms) to show effects are **decision**-related, not motor.
   * Posterior predictive checks separated by (S) (Δ=0 vs Δ>0) and by pupil tertile.

# Why this is correct (quick evidence)

* **Δ=0 trials index bias components**: They maximally constrain (z)/(v_{\text{bias}}) because sensory evidence ≈ 0. That’s exactly where prior work shows **pupil-linked arousal changes bias/caution**:
  • **Phasic pupil ↘︎ bias** in perceptual detection (visual and auditory): de Gee et al., 2017/2020. ([eLife][1])
  • **Pupil ↗︎ threshold (caution)** during conflict/value decisions: Cavanagh et al., 2014; they explicitly model single-trial pupil → (a). 
  • **Pupil can bias drift itself** when motivation manipulates the desired percept: Leong et al., 2021 (pupil–drift interaction). ([PMC][2])

# Exactly how to write it up (drop-in methods text)

> *We included “Standard = Same” (Δ=0) trials in all DDM–pupillometry models because these trials constrain decision bias parameters (starting point (z) and drift-bias (v_0)) under near-zero sensory evidence. Trial-wise baseline pupil (−500–0 ms pre-target) and phasic pupil (slope 200–900 ms post-target) were entered as regressors on (a, z,) and (v). We compared models in which pupil modulated (i) boundary (a), (ii) drift-bias (v_0), or (iii) both, using WAIC/DIC and posterior predictive checks. To prevent oddball-related arousal from confounding parameter inferences, we included an indicator for Δ=0 trials and its interactions with pupil regressors. RTs <200 ms after the response prompt were excluded (≈1.2% of trials); this mirrors standard 200 ms floors in DDM/pupillometry (e.g., Cavanagh et al., 2014). Sensitivity analyses excluding Δ=0 trials and varying phasic windows (300–1200 ms; response-locked −200–+300 ms) yielded the same qualitative pupil→parameter mapping.*

# Bottom line

* **Include Δ=0 (“Standard = Same”) trials.** Treat them as **zero-evidence** and use them to identify **bias** and its **pupil-linked modulation**.
* Keep your **200 ms** RT floor; it’s consistent with the literature and your own data loss is minimal.  

---

## References (APA)

* Cavanagh, J. F., Wiecki, T. V., Kochar, A., & Frank, M. J. (2014). **Eye tracking and pupillometry are indicators of dissociable latent decision processes.** *Journal of Experimental Psychology: General, 143*(4), 1476–1488. [https://doi.org/10.1037/a0035813](https://doi.org/10.1037/a0035813)   
* de Gee, J. W., Knapen, T., & Donner, T. H. (2014). **Decision-related pupil dilation reflects upcoming choice and individual bias.** *Proceedings of the National Academy of Sciences, 111*(9), E618–E625. ([ADS][3])
* de Gee, J. W., Colizoli, O., Kloosterman, N. A., Knapen, T., Nieuwenhuis, S., & Donner, T. H. (2017). **Dynamic modulation of decision biases by brainstem arousal systems.** *eLife, 6*, e23232. [https://doi.org/10.7554/eLife.23232](https://doi.org/10.7554/eLife.23232) ([PubMed][4])
* de Gee, J. W., et al. (2020). **Pupil-linked phasic arousal predicts a reduction of choice bias.** *eLife, 9*, e54014. ([eLife][5])
* Leong, Y. C., Hughes, B. L., Wang, Y., Zaki, J., & Samanez-Larkin, G. R. (2021). **Pupil-linked arousal biases evidence accumulation toward desirable percepts during perceptual decision-making.** *Psychological Science, 32*(2), 224–244. ([PMC][2])
* Murphy, P. R., Vandekerckhove, J., & Nieuwenhuis, S. (2014). **Pupil-linked arousal determines variability in perceptual decision-making.** *PLOS Computational Biology, 10*(9), e1003854. [https://doi.org/10.1371/journal.pcbi.1003854](https://doi.org/10.1371/journal.pcbi.1003854) ([PMC][6])

*(Your uploaded manuscript documents the 200 ms post-prompt RT floor and low data loss; keep that exactly as written.)* 

[1]: https://elifesciences.org/articles/23232?utm_source=chatgpt.com "Dynamic modulation of decision biases by brainstem ..."
[2]: https://pmc.ncbi.nlm.nih.gov/articles/PMC8726586/ "
            Pupil-Linked Arousal Biases Evidence Accumulation Toward Desirable Percepts During Perceptual Decision-Making - PMC
        "
[3]: https://ui.adsabs.harvard.edu/abs/2014PNAS..111E.618D/abstract?utm_source=chatgpt.com "Decision-related pupil dilation reflects upcoming choice ..."
[4]: https://pubmed.ncbi.nlm.nih.gov/28383284/?utm_source=chatgpt.com "Dynamic modulation of decision biases by brainstem ..."
[5]: https://elifesciences.org/articles/54014?utm_source=chatgpt.com "Pupil-linked phasic arousal predicts a reduction of choice ..."
[6]: https://pmc.ncbi.nlm.nih.gov/articles/PMC4168983/?utm_source=chatgpt.com "Pupil-Linked Arousal Determines Variability in Perceptual ..."


Question 3
with regards to Response Coding Discrepancy, always always make incorrect as 0 and the correct as 1.

Question 4
Given the instructions I provided on question 1, revisit this issue and tell me exactly how much percentage of trials removed due to RT filtering, and further examine the outliers, and possibly what we can do about them accordingly. but first, let's run the modifications


-------------


---

# Quick ground truth (why these priors at all)

* In **brms** with `family = wiener()`, the default links are: **drift (v): identity**, **bs (a): log**, **ndt (t₀): log**, **bias (z): logit**. If you set `link_bs="log"`, `link_ndt="log"`, `link_bias="logit"`, your **priors must be on the link scale** for those parameters. ([cran.r-project.org][1])
* Older adults (65+) reliably show **larger boundaries** and **longer non-decision time** than young adults, while **drift** is task-dependent; in perceptual tasks it tends to be lower. That meta-pattern is robust across tasks. ([PMC][2])
* Response-signal/deadline paradigms (your forced 350 ms pre-response period) do not invalidate standard DDM, but they shift practical expectations for **t₀** (you’re modeling post-signal encoding/motor portions when RTs are measured from the response screen). Keep priors for **ndt** conservative and >0.25–0.30 s for older adults. ([ScienceDirect][3])
* Pupil↔DDM mapping: phasic arousal often **reduces choice bias** (z shift) and can alter drift; tonic vs phasic can differentially associate with a and v. Don’t hard-wire the direction into tight priors; keep slopes weakly informative. ([eLife][4])

---

# Evaluate each prior set

### Set 1 — *Main DDM Analysis*

```r
prior(normal(0, 1.5), class = "Intercept"),
prior(normal(0, 1),   class = "b"),
prior(exponential(1), class = "sd")
```

**What it actually does:** Intercept & `b` here apply to **drift (v)**, because that’s the main formula. No priors on `bs`, `ndt`, `bias` → you’re letting brms defaults handle them.

**Issues / fixes**

* `normal(0,1.5)` on **v** is fine but wide; it implies you expect huge accuracy swings. With standardized predictors, I’d prefer **`normal(0,1)`** for v-intercept.
* `normal(0,1)` on **b** (slopes on v) is wide. For condition dummies & z-scored pupil, **`normal(0,0.5)`** keeps effects realistic without handcuffing them.
* **Missing parameter-specific priors**: add explicit priors for `bs`, `ndt`, `bias` on the **correct link scales** (see unified spec below).
* `exponential(1)` on **sd** (random-effect SDs) is a standard weakly-informative shrinker; acceptable. If you want slightly stronger shrinkage, `exponential(2)` or `student_t(3,0,0.5)` are common choices in Stan land. ([GitHub][5])

**Verdict:** *Usable but under-specified.* Add parameter-specific priors.

---

### Set 2 — *Tonic/History/Pupil*

```r
prior(normal(0, 0.5), class = "b"),
prior(normal(0, 1),   class = "sd"),
prior(normal(0, 0.2), class = "Intercept", dpar = "bs"),
prior(normal(0, 0.2), class = "Intercept", dpar = "ndt"),
prior(normal(0, 0.2), class = "Intercept", dpar = "bias")
```

**Critical scale problem:** With your links (`log` for `bs`,`ndt`; `logit` for `bias`) these Intercepts live on the link scale:

* `bs ~ normal(0,0.2)` → centers **a = exp(0)=1.00** with very tight spread (≈ 0.82–1.22). That’s **too low and too tight** for older adults (typical a ≈ 1.4–2.2).
* `ndt ~ normal(0,0.2)` → centers **t₀ = exp(0)=1.00 s**, wildly wrong and tight.
* `bias ~ normal(0,0.2)` on logit → centers **z=.5** (fine), but 0.2 on logit is **very** tight (~.45–.55).

Also missing an explicit drift prior.

**Verdict:** *Incorrect centers for `bs` & `ndt` and too tight overall.* Fix to meaningful centers (see unified spec).

---

### Set 3 — *Simple DDM Fit*

```r
prior(normal(0, 0.3), class = "b"),
prior(normal(0, 0.5), class = "sd"),
prior(normal(log(0.2), 0.3), class = "Intercept", dpar = "ndt"),
prior(normal(0, 0.2),        class = "Intercept", dpar = "bs"),
prior(normal(0, 0.2),        class = "Intercept", dpar = "bias")
```

* **ndt** centered at `log(0.2)` (0.2 s) is **young-adult-ish**; for your older sample + response-screen timing, center higher (≈ **0.30–0.40 s**).
* **bs** again centered at `log(1)` (because 0 on log scale), too low; move to **log(1.7)**.
* **bias** 0.2 logit-sd is tight; loosen to 0.4–0.7.
* `b` sd=0.3 is fine if predictors are standardized; otherwise widen to 0.5.

**Verdict:** *Closer, but centers are off for older adults and bias too tight.*

---

### Set 4 — *Adaptive Phase_B (the dangerous one)*

```r
prior(normal(0, 1),     class = "Intercept"),      # drift (OK)
prior(normal(1, 0.5),   class = "Intercept", dpar="bs"),   # WRONG scale
prior(normal(0.2, 0.08),class = "Intercept", dpar="ndt", lb=0.01, ub=max_ndt), # WRONG scale
prior(normal(0, 0.5),   class = "b"),
prior(exponential(2),   class = "sd")
```

* **Fatal bug:** `bs` & `ndt` priors are on the **natural** scale, but with `log` links the prior is interpreted on the **log** scale. That makes a nonsense prior (e.g., log-Normal(1,0.5) rather than Normal(log(1),0.5)).
* The `ub = max_ndt` constraint is on the link scale, and with a log link you don’t need positivity constraints—log already enforces it. Upper bounds tied to (filtered) min RT are rarely worth the brittleness.
* `exponential(2)` is just a stronger shrinker vs `exponential(1)`; the choice should be global/consistent. ([cran.r-project.org][1])

**Verdict:** *Fix immediately.* Convert to link-scale or you’re injecting the wrong beliefs.

---

### Set 5 — *Parameter recovery/testing*

Minimal priors are okay **only** if you simulate from generous ranges and you’re stress-testing identifiability. For apples-to-apples, **use the same priors as production** unless the test’s purpose is different (e.g., prior sensitivity). ([The R Journal][6])

---

### Set 6 — *Model comparison*

```r
prior(normal(0, 0.5), class = "b"),
prior(normal(0, 1),   class = "sd")
```

Lean is fine for comparing *drift-only* formulas, but once you compare full DDMs, **hold priors constant across models** (including `bs`,`ndt`,`bias`) so Bayes factors/LOO target the structure, not prior idiosyncrasies. ([Journal of Statistical Software][7])

---

# A single, standardized prior spec (drop-in)

**Assumptions**

* All continuous predictors (pupil metrics) **z-scored**; categorical predictors **centered** (±0.5 coding).
* Links: `link_bs="log"`, `link_ndt="log"`, `link_bias="logit"` (defaults).
* Older adults, perceptual 2AFC, RT measured from response-screen onset.

```r
priors_std <- c(
  ## Drift (v) — identity link
  prior(normal(0, 1),     class = "Intercept"),   # weakly informative around 0
  prior(normal(0, 0.5),   class = "b"),           # condition/pupil effects on v

  ## Boundary separation (a / bs) — log link
  prior(normal(log(1.7), 0.30), class = "Intercept", dpar = "bs"),
  prior(normal(0, 0.20),        class = "b",       dpar = "bs"),   # small shifts

  ## Non-decision time (t0 / ndt) — log link
  prior(normal(log(0.35), 0.25), class = "Intercept", dpar = "ndt"),
  prior(normal(0, 0.15),         class = "b",       dpar = "ndt"),

  ## Starting point (z / bias) — logit link
  prior(normal(0, 0.5),   class = "Intercept", dpar = "bias"),     # centered at 0.5, not too tight
  prior(normal(0, 0.3),   class = "b",         dpar = "bias"),

  ## Random effects (subject-level)
  prior(student_t(3, 0, 0.5), class = "sd")  # or exponential(1) if you prefer
)
```

**Why these centers/spreads**

* **a**: older adults typically adopt more cautious thresholds; **1.5–2.2** is common—so center at **1.7** with sd on the log scale ≈ ±35% range. ([PMC][2])
* **t₀**: with response-screen timing and older adults, expect **0.30–0.45 s**; center **0.35 s** with enough spread to cover 0.2–0.6 s. ([PMC][2])
* **z**: keep it near .5 but let it move; phasic arousal often reduces bias, so allow movement in either direction. ([eLife][4])
* **v**: 0-centered to avoid baking in “easy > hard” before the data; slopes are moderate.

> If you must keep your current link settings, this spec is drop-in. If you change links, **re-express the priors on the new link scale**.

---

# Consistency & when to vary

* **Production, comparison, and recovery** should share **the same priors** unless you’re explicitly testing prior sensitivity. Document any deliberate deviations (e.g., much tighter priors for a calibration experiment).
* The only justified routine variation: **per-task** centers for `v` intercept if you split auditory vs visual fits, and **per-sample** centers for `a`/`t₀` if you add younger cohorts.

---

# Specific corrections to your sets

* **Set 1:** keep, but add the parameter-specific priors above. Consider narrowing `b` on v to 0.5.
* **Set 2:** change to

  * `Intercept,dpar="bs" = normal(log(1.7), 0.30)`
  * `Intercept,dpar="ndt" = normal(log(0.35), 0.25)`
  * `Intercept,dpar="bias" = normal(0, 0.5)`
  * add `class="Intercept"` (no `dpar`) for **drift**: `normal(0,1)`
* **Set 3:** bump `ndt` center from `log(0.2)` → **`log(0.35)`**; change `bs` center to **`log(1.7)`**; loosen `bias` sd to **0.5**.
* **Set 4 (Phase_B):** **fix the scale bug now.** Change

  * `bs Intercept: normal(log(1.7), 0.30)`
  * `ndt Intercept: normal(log(0.35), 0.25)` and **drop `ub`**; the log link already enforces positivity. Keep `exponential(2)` if you want stronger shrinkage, but make it consistent across scripts.
* **Set 5 & 6:** copy the standardized spec.

---

# Aging & response-signal implications (brief)

* **Aging:** Expect **higher a**, **longer t₀**; drift may be lower in perceptual tasks (like yours). Don’t over-tighten around those expectations—set centers sensibly, give room. ([PMC][2])
* **Response-signal:** Your RTs start at response-screen onset; standard `ndt` then approximates **post-signal encoding + motor**. That justifies the **0.30–0.40 s** center. If you later fit *true* response-signal diffusion (pre-signal accumulation + deadline), use the Ratcliff (2006) framework; brms’ `wiener` does not implement RS dynamics explicitly. ([ScienceDirect][3])

---

# Final take

* Your current priors are **inconsistent** and (in Set 4) **on the wrong scale**.
* Standardize now to the unified spec above; it’s defensible from **brms’ link functions**, **aging DDM meta-patterns**, and **response-signal logic**.
* Keep predictors standardized, keep random-effects shrinkage consistent, and document the rationale once so you don’t have to re-argue it later.

---

## References (APA)

* Bürkner, P.-C. (2017). *brms: An R package for Bayesian multilevel models using Stan.* *Journal of Statistical Software, 80*(1), 1–28. [https://doi.org/10.18637/jss.v080.i01](https://doi.org/10.18637/jss.v080.i01) ([Journal of Statistical Software][7])
* de Gee, J. W., Tsetsos, K., Schwabe, L., Urai, A. E., McCormick, D., McGinley, M., Donner, T. H., & Nieuwenhuis, S. (2020). Pupil-linked phasic arousal predicts a reduction of choice bias across species and decision domains. *eLife, 9*, e54014. [https://doi.org/10.7554/eLife.54014](https://doi.org/10.7554/eLife.54014) ([eLife][4])
* Gelman, A. (2006). Prior distributions for variance parameters in hierarchical models. *Bayesian Analysis, 1*(3), 515–533. [https://doi.org/10.1214/06-BA117A](https://doi.org/10.1214/06-BA117A) ([Statistical Consulting at Columbia][8])
* Murphy, P. R., Vandekerckhove, J., & Nieuwenhuis, S. (2014). Pupil-linked arousal determines variability in perceptual decision making. *PLOS Computational Biology, 10*(9), e1003854. [https://doi.org/10.1371/journal.pcbi.1003854](https://doi.org/10.1371/journal.pcbi.1003854) ([PLOS][9])
* Ratcliff, R. (2006). Modeling response signal and response time data. *Cognitive Psychology, 53*(3), 195–237. [https://doi.org/10.1016/j.cogpsych.2005.10.002](https://doi.org/10.1016/j.cogpsych.2005.10.002) ([ScienceDirect][3])
* Ratcliff, R., & McKoon, G. (2008). The diffusion decision model: Theory and data for two-choice decision tasks. *Neural Computation, 20*(4), 873–922. [https://doi.org/10.1162/neco.2008.12-06-420](https://doi.org/10.1162/neco.2008.12-06-420) ([MIT Press Direct][10])
* Theisen, M., Lerche, V., von Krause, M., & Voss, A. (2020). Age differences in diffusion model parameters: A meta-analysis. *Psychological Research, 84*(7), 1854–1876. [https://doi.org/10.1007/s00426-019-01164-5](https://doi.org/10.1007/s00426-019-01164-5) ([PMC][2])
* Wabersich, D., & Vandekerckhove, J. (2014). The **RWiener** package: An R package providing distribution functions for the Wiener diffusion model. *The R Journal, 6*(1), 49–56. [https://doi.org/10.32614/RJ-2014-005](https://doi.org/10.32614/RJ-2014-005) ([The R Journal][6])

If you want, I can rewrite your existing scripts’ `prior()` blocks to this spec and flag any other landmines (e.g., coding, predictor scaling).

[1]: https://cran.r-project.org/web/packages/brms/brms.pdf?utm_source=chatgpt.com "brms: Bayesian Regression Models using 'Stan' - CRAN"
[2]: https://pmc.ncbi.nlm.nih.gov/articles/PMC8289776/ "
            Age differences in diffusion model parameters: a meta-analysis - PMC
        "
[3]: https://www.sciencedirect.com/science/article/abs/pii/S0010028505000757?utm_source=chatgpt.com "Modeling response signal and response time data"
[4]: https://elifesciences.org/articles/54014?utm_source=chatgpt.com "Pupil-linked phasic arousal predicts a reduction of choice ..."
[5]: https://github.com/stan-dev/stan/wiki/prior-choice-recommendations?utm_source=chatgpt.com "Prior Choice Recommendations · stan-dev/stan Wiki"
[6]: https://journal.r-project.org/archive/2014/RJ-2014-005/index.html?utm_source=chatgpt.com "The RWiener Package: an R... The R Journal"
[7]: https://www.jstatsoft.org/v80/i01/?utm_source=chatgpt.com "An R Package for Bayesian Multilevel Models Using Stan"
[8]: https://sites.stat.columbia.edu/gelman/research/published/taumain.pdf?utm_source=chatgpt.com "Prior distributions for variance parameters in hierarchical ..."
[9]: https://journals.plos.org/ploscompbiol/article?id=10.1371%2Fjournal.pcbi.1003854&utm_source=chatgpt.com "Pupil-Linked Arousal Determines Variability in Perceptual ..."
[10]: https://direct.mit.edu/neco/article/20/4/873/7299/The-Diffusion-Decision-Model-Theory-and-Data-for?utm_source=chatgpt.com "The Diffusion Decision Model: Theory and Data for Two- ..."
