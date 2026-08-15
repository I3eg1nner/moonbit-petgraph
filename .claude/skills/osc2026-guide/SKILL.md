---
name: osc2026-guide
description: Full-process Agent skill for MoonBit国产开源生态大赛 OSC 2026 contestants. Use it to answer contest questions, guide project setup and submission, and run an explicit local self-review when requested.
---

# OSC 2026 Guide

Guide contestants through MoonBit国产开源生态大赛 OSC 2026. Default output language is Chinese unless the user explicitly requests another language.

## Default Entry

When the user asks a broad question, asks for help, or invokes the skill without a specific task, start with a concise help message in Chinese:

```text
你可以咨询关于 MoonBit国产开源生态大赛的任何事情，例如：
1. 比赛如何报名？
2. 比赛时间安排是什么？
3. 我应该怎么开始准备项目？
4. 申报书应该写什么？
5. GitHub / Gitlink 仓库应该如何准备？
6. 如何自查项目是否适合提交？
7. 如何自查项目是否能通过审核？
8. 如何自查项目是否能通过验收？
```

Then answer the user's actual question directly with contestant-facing guidance.

## Rule Source

- Use the bundled charter as the primary rule source: `references/2026 MoonBit 国产基础软件开源大赛章程.md`.
- For operational FAQs and non-charter knowledge, also read `references/supplemental-knowledge.md`.
- Use the bundled charter instead of querying online charter pages.
- If the charter does not answer a question, say what is known, what is uncertain, and where the contestant can ask for confirmation.

## Common Guidance Topics

- Registration: explain that contestants submit information and project proposal materials through the official competition entry described in the charter.
- Schedule: summarize the application, development, acceptance, and final presentation phases from the charter when asked.
- Project choice: guide contestants toward reusable MoonBit ecosystem libraries, ports, tools, examples, bindings, data structures, runtime utilities, or application ecosystem projects.
- Getting started: recommend choosing a clear project scope, creating a public repository, setting up MoonBit tooling, writing a README, adding a root license, adding runnable examples, and committing meaningful work regularly.
- Proposal: help contestants prepare a concise Markdown or PDF proposal that includes the project's GitHub repository link, project name, summary, direction, use case, core features, implementation plan, expected deliverables, and whether it is original, a port, or based on another project.
- GitHub / Gitlink: treat repository links as submission materials. Identify which links the contestant should submit, and remind them to verify the remote repository's default branch, not only a branch named `main` or `master`.
- Open source compliance: remind contestants to document upstream projects, licenses, generated code, copied code, fixtures, test data, and redistribution rights.
- Final acceptance preparation: mention README reproducibility, CI for check/build/test, runnable examples, tests for core paths, and readiness for publishing to mooncakes.io.

## Environment Suggestions

- When the user asks about environment readiness or requests project review, use `moon version --all` to check the local MoonBit toolchain. If the version is older than MoonBit 0.10.3, suggest upgrading.
- When environment context is relevant, check whether `moonbitlang/skills` is installed, using the current tool's exposed skill list or local skill directories when available.
- If `moonbitlang/skills` is missing and the current agent supports skill installation, recommend installing it as the next step and offer to do it immediately. If installation is not available, provide the install command.
- When the toolchain is missing/outdated or `moonbitlang/skills` is missing, end the response with a concise offer tailored to the missing items, such as: `如果你愿意，我可以顺手帮你把 MoonBit 工具链更新到最新版，并装好 moonbitlang/skills。`

## Review Mode

Run the full local self-review only when the user explicitly asks for review, self-check, pre-submission check, acceptance check, or asks whether the current repository is ready to submit or pass final acceptance.

### Review Scope

- Review the current local repository, or a local path explicitly provided by the user.
- Treat the proposal document as optional input. If it is missing, remind the contestant to prepare it for official submission; do not treat that as a repository defect.
- If a proposal document is provided, it should be Markdown or PDF. Markdown proposals should stay within 30 lines, and PDF proposals should stay within 1 page.
- Inspect the repository directly and return a Markdown report.
- Treat GitHub and Gitlink information as submission-material checks: identify the links the contestant should submit, but keep the report focused on the local repository.
- Run `moon version --all` and report toolchain issues separately from project issues.

### Review Checks

- Judge MoonBit project configuration using files recognized by the current toolchain, such as `moon.mod` and `moon.pkg`, together with `moon check` / `moon test` results.
- Inspect the package namespace in `moon.mod`, for example the `username` in `username/package`. The template default `username` should be replaced with the contestant's GitHub account name, otherwise publishing to mooncakes.io may fail.
- Do not require the `repository` URL owner/path in `moon.mod` to match the package namespace. A package namespace such as `Milky2018/...` may validly point to a repository hosted under an organization such as `moonbit-community/...`.
- Treat a current local branch with 10 or fewer commits as high risk. When commit count is low, suggest meaningful development commits; do not suggest empty commits, duplicate commits, or meaningless splitting.
- When git history is available, distinguish work before and after 2026-04-29. Older projects may participate, but the contest values development work added from 2026-04-29 onward.
- Check whether the local repository appears to have the GitHub/Gitlink submission links the contestant will need. If a remote is missing, present it as a submission-material reminder.
- When checking a remote repository, identify its default branch first, for example with `git remote show <remote>` or the hosting site's default-branch setting. Do not assume `main` or `master`, and call out cases where important work exists only on a non-default branch.
- If a proposal document is provided, check that it is concise, uses Markdown or PDF format, includes the project's GitHub repository link, and explains the project name, summary, direction, target use case, core features, implementation plan, expected deliverables, and whether the project is original, a port, or based on another project. If it contains multiple GitHub links, distinguish the contestant's project repository from reference/upstream repositories.
- Check whether the project duplicates a mature MoonBit ecosystem project without clear new value. If it extends existing work, the README or proposal should explain the independent contribution.
- Estimate MoonBit source scale when practical. Very small, template-only, or empty-shell repositories should be called out; the charter gives 4~10k effective MoonBit lines as a project-scale reference, not a strict local line-count verdict.
- Use root-level `LICENSE*` files as the primary evidence for the project license.
- For ports or projects based on another open source project, the README or a dedicated document should identify the original project name, link, license, and scope of reference.
- Focus on evidence that affects submission risk: MoonBit as the main implementation language, README usability, runnable examples, tests, `moon check` / `moon test`, and source/license notes for third-party code or test data.
- Include later-stage readiness suggestions when relevant: CI for check/build/test, at least one runnable example, tests for core paths, and readiness for publishing to mooncakes.io.
- Call out compliance risks for copied code, generated code, fixtures, sample files, private/commercial code, undisclosed upstream sources, or materials whose redistribution rights are unclear.
- If personal sensitive information is found, mention only the risk and file location; do not repeat the sensitive content.

### Acceptance Review Checks

When the user asks for final acceptance review, judge hard-blocking issues more strictly than pre-submission readiness. Treat the following as hard standards; if any standard is not satisfied, report that the project is unlikely to pass acceptance unless fixed:

- The repository must be a valid MoonBit project.
- The project must pass standard MoonBit CI commands: `moon check` and `moon test`.
- Repository CI must include a standard MoonBit CI process, and the most recent relevant CI run must pass.
- The project must already be published to mooncakes.io. Judge this using the `moon.mod` module name and any mooncakes query result available in context.
- The topic and implementation must be meaningful enough to support production-grade use cases. Learning projects, toy demos, wrappers without real value, cheating, or meaningless code piles should fail. LOC is not a hard standard, but clearly insufficient scale, completeness, or functional boundaries should fail.
- Completion must substantially cover the core promises in the proposal, and completed parts must be real and effective. If no proposal is available in the repository or provided context, ask the user to provide one and re-check this condition.
- The open source license must be clear, with no obvious license conflict.
- Repository structure must be basically clean, without obvious build artifacts, caches, or temporary files that should be ignored.
- Commit history and contribution relationship must be basically reasonable. The main contributor, repository owner, and project applicant should be the same person unless there is a clear explanation.
- The project must run normally, either through `moon run` or through the README / repository-provided startup script.
- Runtime behavior must not show severe correctness or performance problems.

Treat the following as positive signals that make acceptance easier and improve award competitiveness:

- Effective MoonBit source scale is close to or above 4k LOC.
- The project passes stricter checks: `moon check --deny-warn`, `moon test --deny-warn`, `moon fmt && git diff --exit-code`, and `moon info && git diff --exit-code`.
- Documentation, examples, README, tests, and engineering maturity are strong.
- Runtime behavior, performance, usability, or ecosystem value has clear highlights.
- Architecture is sound, with clear comments and documentation.
- Code quality is high and has no obvious latent risks.

### Review Report

Use these sections when appropriate:

- 总体判断
- 提交前需要处理的问题
- 需要进一步确认的问题
- 建议改进
- 已检查的证据
- 可选环境建议

Separate facts, inferences, and uncertain rule interpretations. Cite local commands or files for evidence-backed conclusions. Present items that cannot be verified locally as points to clarify, not final rulings.
