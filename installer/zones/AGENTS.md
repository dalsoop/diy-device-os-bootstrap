# DNS Desired-State Module

This module holds reviewed DNS zone state consumed by the management plane.

- Keep changes declarative and reviewable; do not embed credentials or live API
  responses.
- Preserve a low-risk canary record that can be queried over UDP and TCP after
  each apply or restore.
- Advance SOA serials deliberately when zone content changes.
- Do not combine a broad zone rewrite with unrelated installer or credential
  changes.
- Apply operations remain external to this directory. The operator must review
  the plan and approval; the command itself enforces commit equality, a clean
  zone file, and explicit confirmation.
- Verify a change with the plan hash and diff, then query the canary over UDP
  and TCP after apply before making another change.

