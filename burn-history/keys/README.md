# Keys

This folder holds the operator's public key material. Git ignores everything
here except this README.

Do not place long-lived secrets here merely because the folder is ignored.
Passwords, tokens, private SSH keys, age identities, and recovery archives
belong in the principal secret store. The World may contain a non-sensitive
reference to that store, never the value.

```text
keys/
├── README.md                    this file (tracked)
├── operator-authorized-keys     operator SSH public key(s)
└── age-recipient                public age recipient for enrollment bundles
```

- Only public material belongs here. The DNS image build reads
  `operator-authorized-keys` and `age-recipient` unless
  `DNS_APPLIANCE_AUTHORIZED_KEYS` or `DNS_APPLIANCE_AGE_RECIPIENT` points
  elsewhere. `engine/installer/management/cluster-bootstrap` reads
  `age-recipient` unless `DNS_CLUSTER_AGE_RECIPIENT` points elsewhere.
- The expected formats are shown by
  [`operator-authorized-keys.example`](../../engine/installer/docs/examples/operator-authorized-keys.example)
  and [`age-recipient.example`](../../engine/installer/docs/examples/age-recipient.example).
