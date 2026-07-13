# GitHub Monitoring Status Map

Use this map when rechecking existing outreach links. Record the source URL and
the observed state in the Airtable log.

## External state to Airtable

| External state | Airtable status | Next action |
| --- | --- | --- |
| PR open, no new maintainer response | `PR Open` | Recheck on a dated cadence |
| Issue open, no new maintainer response | `Issue Open` | Recheck on a dated cadence |
| PR or issue has maintainer questions | `Pending Review` | `Run closing draft` if a reply or revision draft is needed |
| PR merged or listing accepted | `Listed` | Clear unless follow-up is required |
| Listing visible outside GitHub | `Listed` | Clear unless follow-up is required |
| Duplicate open submission discovered | Match the canonical PR or issue (`PR Open`, `Issue Open`, or `Pending Review`) | Preserve the platform record, use its canonical link, and do not create a replacement target |
| Issue resolved as completed | `Listed` only when the requested result is visible; otherwise `Pending Review` | Verify the delivered outcome instead of inferring success from the resolution label |
| PR or issue closed as not a fit | `Declined` | Clear, with reason |
| PR or issue closed without a stated reason | `Declined` | Record `closed without a stated reason`; do not invent a fit judgment |
| Target rules now reject CLIs/scripts | `Deferred` or `Dead` | Use `Dead` for permanent mismatch |
| Link missing, inaccessible, or gated | `Deferred` | Recheck only if access can change |
| Scope or eligibility changed | Keep current or `Deferred` | `Run lead qualification` when fit must be rechecked |

## Recheck rules

- Do not leave `Last Checked` blank after opening a recorded link.
- Do not duplicate comments just to ask for status.
- Do not create replacement targets for the same repository; use `Merge Queue`
  only when a real dedupe conflict exists.
- If a maintainer asks for new copy, route to closing draft rather than
  drafting inside monitoring.
- Preserve existing platform records and target notes. Every meaningful update
  appends a log whose result names the exact outcome, reason, and next step and
  whose link is the relevant source URL.
