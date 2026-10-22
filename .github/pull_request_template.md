<!-- Follow docs/git-policy.md. Use a concise imperative English title without a type prefix. Update the title and description to match the final scope. -->

## Problem and resulting behavior

Explain the concrete problem and the resulting user-visible or maintenance behavior. Link the authoritative task or issue and relevant design decisions. State any deviations and undelivered requirements with reasons.

## Verification

List the checks or user journeys actually run, their results, and the target/environment. Include relevant evidence. Distinguish passed, failed, blocked, not run, planned and inapplicable checks. Required CI must cover the submitted revision.

## Review considerations

Include important tradeoffs, compatibility or data changes, remaining limitations, and any separately authorized rollout work. Remove this section if none apply.

## Review readiness

- [ ] Self-reviewed the final diff against acceptance criteria, including normal, failure and boundary behavior.
- [ ] Recorded resolution of required findings and material questions, or marked the PR as not ready.
- [ ] Consolidated temporary history and checked any squash commit message against docs/git-policy.md.
- [ ] Re-verified behavior changes and the resulting tree after any rebase or squash; required checks and reviews apply to the candidate revision.
