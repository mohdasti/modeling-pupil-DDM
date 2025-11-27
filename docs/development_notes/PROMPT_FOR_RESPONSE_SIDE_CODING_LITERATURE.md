# Prompt for Literature Search: Response-Side Coding in DDM

## Context

I am writing a methods section for a diffusion decision model (DDM) analysis in which I need to justify our use of **response-side coding** (also called response-boundary mapping) rather than accuracy-based coding for identifying starting-point bias (z).

## Our Specific Approach

**Decision Coding Method:**
- We use **response-side coding** where the upper boundary corresponds to "different" responses and the lower boundary corresponds to "same" responses
- This is in contrast to accuracy-based coding where one boundary = correct and the other = incorrect
- We apply this coding across all trials in our DDM analysis

**Study Design:**
- Response-signal change detection task (forced-choice same/different discrimination)
- Three difficulty conditions: Standard (Δ=0, identical stimuli), Easy (large stimulus differences), Hard (small stimulus differences)
- Standard trials (Δ=0) are critical for bias identification because they contain zero evidence (drift ≈ 0)
- On Standard trials, participants chose "same" on 87.8% of trials and "different" on 12.2%, indicating a conservative bias toward "same"

**Why This Matters:**
- Response-side coding allows us to identify bias independently of correctness
- On Standard trials, both "same" and "different" responses are technically correct (since stimuli are identical), so accuracy-based coding would be ambiguous
- Bias (z) reflects participants' response tendency/preference rather than their accuracy
- This is important for understanding how arousal/effort affects response caution and bias, separate from discrimination ability

## Questions for Literature Search

1. **Methodological justification**: What papers (preferably recent, high-impact) justify or recommend using response-side coding (boundary mapping to response choices) rather than accuracy-based coding in DDM analyses of same/different discrimination tasks?

2. **Bias identification**: What literature discusses using Δ=0 (no-change) trials or neutral trials for identifying starting-point bias in DDM? I recall de Gee et al. (2020, eLife) may have used a similar approach for pupil-linked arousal and bias.

3. **Same/different tasks**: What papers specifically address DDM parameter estimation (especially bias) in same/different discrimination tasks rather than 2AFC tasks with clearly correct/incorrect responses?

4. **Bias vs accuracy**: What literature discusses the conceptual distinction between starting-point bias (response tendency/preference) and accuracy/performance in DDM? Why is it important to model bias independently of correctness?

5. **Standardization**: Is response-side coding becoming a standard practice in the field? What are the arguments for/against this approach compared to accuracy-based coding?

## Specific Details to Include in Search

- Task type: Change detection, same/different discrimination, match-to-sample
- DDM parameter: Starting-point bias (z parameter)
- Trial type: Neutral trials, Δ=0 trials, no-change trials
- Methodological focus: Response-boundary mapping, response-side coding, accuracy-independent bias estimation
- Applications: Arousal, effort, motivation effects on bias

## Expected Output Format

For each relevant paper found, please provide:
1. Full citation (APA format)
2. Brief summary of how they justify/use response-side coding
3. Key quote or methodological detail (if available)
4. Relevance to our approach (1-2 sentences)

Thank you!


