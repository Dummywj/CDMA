---
name: create-cdma-beginner-tutorials
description: Create or revise beginner-first tutorials for any step of this CDMA wireless data-link project, grounded in `edu/老师十步法-CDMA无线数据传输链路设计教学.md` and `material/Question.txt`. Use when Codex is asked to explain, teach, document, implement, or improve a numbered CDMA step, especially for a learner with no communications background, or when an existing step tutorial is technically confusing or inconsistent with the project.
---

# Create CDMA Beginner Tutorials

Generate a technically defensible tutorial that a complete communications beginner can follow. Preserve the ten-step development boundary: teach the requested step thoroughly without silently implementing later steps.

## Read Project Sources

Work from the repository root. Before drafting or editing, read:

1. `material/Question.txt` completely for hard project requirements.
2. `edu/老师十步法-CDMA无线数据传输链路设计教学.md` sections covering:
   - overall link and frozen parameters;
   - ten-step overview;
   - requested step;
   - immediately preceding and following steps;
   - common acceptance and troubleshooting guidance.
3. Existing `edu/step*.md` tutorials and `simulation/step*/` code relevant to inherited behavior.

Treat `material/Question.txt` as the project requirement source and the teacher's ten-step document as the step-order and scope source. Do not modify either source unless explicitly asked.

Do not invent exact IS-95 polynomials, register conventions, bit order, initial states, zero insertion, CRC details, or reference vectors. If the project does not freeze a standard-specific value, state that it must come from the course specification or a verified primary standard. Clearly label any small teaching sequence as a placeholder rather than IS-95.

## Establish The Step Boundary

Write down privately before drafting:

- the input inherited from the previous step;
- the one new capability introduced now;
- the output that becomes the next step's baseline;
- assumptions kept ideal in this step;
- features explicitly postponed.

Show the learner a short before/after chain. Use precise operation names. For example, distinguish QPSK complex mapping from RF modulation rather than calling both "modulation."

When the simplified step differs from the final IS-95 link, show both chains and explain why. Never let a teaching shortcut masquerade as the final standard architecture.

## Teach From Concrete To Abstract

Assume the learner knows no communications terminology. Use this order:

1. State in one sentence what this step adds.
2. Give a tiny hand-calculable example with no noise and minimal notation.
3. Explain what the learner should observe.
4. Introduce each necessary term at first use in plain language.
5. Connect the example to this project's actual parameters and chain.
6. Introduce formulas only after the operation is intuitive.
7. Add code incrementally: one value, a short fixed vector, many values, then noise or impairments.
8. End with experiments, acceptance checks, common failures, and the next-step boundary.

Keep one main idea per section. Put derivations and standard details in clearly marked optional sections. Do not open with acronyms, polynomials, state machines, or a large program.

For every formula:

- define every symbol immediately;
- include units where applicable;
- substitute at least one project value;
- explain the result in words;
- distinguish a rate, a count, a duration, a frequency, and an energy ratio.

Prefer direct language over analogies. Use an analogy only when it makes the operation more accurate, and state where the analogy stops being valid.

## Prevent Known Conceptual Confusion

Explicitly check and clarify relevant items below:

- **QPSK mapping vs RF modulation:** Mapping bits to an I/Q complex number is digital baseband work. Moving I/Q onto the 800 MHz carrier is RF modulation and occurs later.
- **Complex vs imaginary:** A QPSK value normally has real I and imaginary Q parts; it is not merely a pure imaginary number. Explain complex multiplication as changing I/Q signs or phase.
- **Walsh vs PN:** Walsh codes separate pilot, synchronization, and traffic logical channels. IS-95 short PN codes provide I/Q spreading/scrambling, phase acquisition, and path-search structure.
- **Length increase vs PN multiplication:** Repetition, rate matching, or Walsh covering creates chip positions. Multiplying an existing chip stream by an equal-length PN stream does not increase its length.
- **Step 2 vs final link:** Step 2 may combine symbol repetition and PN multiplication because Walsh is absent. In the final link, Walsh already produces `1.2288 Mchip/s`, and PN-I/PN-Q multiply those chips one-for-one.
- **PN period vs spreading factor:** A 32768-chip short-code period does not mean one information bit becomes 32768 chips.
- **I/Q rate:** Simultaneous I and Q streams at `1.2288 Mchip/s` form one complex stream at `1.2288 Mchip/s`; do not add them into `2.4576 Mchip/s`.
- **Carrier frequency vs data rate:** `800 MHz` locates the RF signal. It does not multiply the business rate or chip rate.
- **Pure AWGN comparison:** Spreading does not create free BER improvement when energy per information bit is held constant.
- **Synchronization assumptions:** Say whether clock, PN phase, frame position, carrier phase, and channel are known or estimated in this step.

Do not include every clarification mechanically. Include the ones touched by the requested step, and verify the tutorial does not contradict the others.

## Connect All Project Rates

When rate relationships matter, start from the frozen project values and construct a dimensional table. For the recommended forward-link teaching chain, verify:

```text
36.864 MHz / 30 = 1.2288 Mchip/s
1.2288 Mchip/s / 64 Walsh chips = 19.2 ksymbol/s
```

With the recommended rate-1/2 convolutional code, explain how each traffic rate reaches `19.2 ksymbol/s` before Walsh covering:

| Information rate | After rate-1/2 coding | Repetition to 19.2 ksymbol/s | Chips per information bit |
| --- | --- | --- | --- |
| 9.6 kbps | 19.2 ksymbol/s | 1 | 128 |
| 4.8 kbps | 9.6 ksymbol/s | 2 | 256 |
| 2.4 kbps | 4.8 ksymbol/s | 4 | 512 |

State the assumptions behind this table. Do not apply Step 1's "two information bits per QPSK symbol" directly to the final IS-95 forward-link rate accounting; the final complex chip stream is formed through I/Q spreading after channel processing.

## Build Implementation Gradually

Match the language and tool requested by the user and the repository's existing patterns. For MATLAB, Simulink, C, or RTL examples:

- reuse previously validated modules instead of rewriting them with different conventions;
- begin with a fixed short vector and no noise;
- use explicit dimensions and row/column orientation;
- use a fixed random seed for statistical tests;
- keep energy normalization visible;
- calculate deterministic latency instead of deleting samples until BER becomes zero;
- add assertions for length, energy, noiseless equality, and known vectors;
- separate educational placeholder parameters from final standard parameters;
- explain a code block before or immediately after it in plain language.

Avoid presenting a complete large program before the learner understands the small example it implements.

## Required Tutorial Shape

Adapt section names to the step, but normally include:

1. What this step adds.
2. What is inherited and what is postponed.
3. A before/after chain.
4. A hand-calculable example.
5. Minimal vocabulary.
6. Project-specific numerical relationships.
7. Plain-language formulas.
8. Incremental implementation.
9. Experiments from noiseless to realistic.
10. Acceptance checklist.
11. Symptom-cause-check troubleshooting table.
12. What to save and what the next step will remove or add.

Use Markdown tables only for genuine comparisons or mappings. Keep paragraphs short. Avoid repeating the same definition in multiple sections.

## Validate Before Delivery

Perform a final consistency pass:

- Re-read the requested step in the teacher document.
- Confirm no later-step feature was silently introduced.
- Check every rate equation dimensionally and numerically.
- Check code implements the displayed equations and mapping order.
- Check all normalization factors are consistent.
- Check every acronym and specialist term is explained at first use.
- Search for ambiguous uses of "modulation," "symbol," "chip," "PN spreading," and "synchronization."
- Confirm the tutorial distinguishes the teaching model from the final IS-95 chain.
- Confirm Markdown code fences are balanced.
- Preserve unrelated user changes in the worktree.

If exact standard facts are unavailable, leave a visible, actionable requirement to obtain the course reference vector. Do not hide uncertainty behind confident wording.
