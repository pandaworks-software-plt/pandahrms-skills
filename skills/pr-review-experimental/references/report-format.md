# Round report

Report applies to one inspected base/head pair. Include every historical finding; update evidence and status in place. Script adds recording date. Use full Git SHAs. Suggestions stay outside report.

```json
{
  "head": "aaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaa",
  "base": "bbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbb",
  "checks_passed": false,
  "checks_evidence": "Required CI run URL / commands and outcomes for this head/base",
  "review_complete": true,
  "gaps": ["Required integration test cannot run in available environment"],
  "findings": [
    {
      "id": "F001",
      "key": "export/tenant-scope",
      "classification": "NO-GO",
      "status": "open",
      "evidence": "Export.cs:42 at recorded head; traced caller supplies no tenant constraint; cross-tenant rows returned"
    },
    {
      "id": "F002",
      "key": "report/export-timeout",
      "classification": "MEL",
      "status": "open",
      "evidence": "Report.cs:83 at recorded head; reproduced timeout for large optional exports",
      "impact": "Large optional exports fail; smaller exports work",
      "mitigation": "Limit export date range",
      "owner": "",
      "due": "",
      "ticket": "",
      "accepted_by": "",
      "acceptance_evidence": ""
    }
  ]
}
```

- `checks_passed`, `review_complete`: actual JSON booleans.
- `gaps`: list of unresolved evidence/verification gaps; empty when none.
- `status`: `open`, `resolved`, `dismissed`. Resolution needs fix/test evidence; dismissal needs disproof in `evidence`.
- `classification`: `NO-GO` or `MEL`; allow MEL escalation to NO-GO. NO-GO downgrade is rejected; refer disputed classification to human and keep same ID.
- `key`: stable affected capability plus root cause, unique across findings.
- MEL `due`: ISO `YYYY-MM-DD`, valid through that local date. Recheck each invocation.
- `acceptance_evidence`: concrete session statement or link identifying human, accepted finding, risk and mitigation; string presence alone is not proof.
- Empty MEL fields deliberately keep example BLOCKED. Replace with actual evidence; never copy sample claims into a real review.

Ledger is local review memory, not trusted CI attestation or tamper-proof storage. Single writer; script replays history validation on load and replaces file atomically after successful record.
