# Engineering Notes

## Index and filesystem mismatch

Symptom: validation reports that index references and files differ.

Cause: an entry file was added without registration, removed without deleting
its index row, or renamed on only one side.

Response: make the index and controlled directory exactly match. Do not weaken
the closed-world check.

## Entry rejected after a release update

Symptom: an otherwise valid JSON entry fails its contract.

Cause: common executable-gate failures are an uppercase digest, a URL without
HTTPS, an ID with a version or underscore, a nested source filename, an unsafe
destination, or an unsupported value. Unknown fields are rejected by the
published JSON Schemas but can currently pass the executable verifier.

Response: correct the data to the published contract. If new semantics are
actually required, treat that as a coordinated contract change rather than
loosening one check.

## Catalog passes but Installer does not see the item

Symptom: a merged public entry is absent from a user's media.

Cause: the active reference collection or World intent does not select the
stable ID, or the operator is using an older monorepo commit.

Response: update deliberately, review the Catalog diff between commits, add the
ID to selected media, and inspect the Installer's resolved plan.

## Checksum uncertainty

Symptom: the downloaded file's locally computed hash differs from the proposed
Catalog digest.

Cause: the URL changed content, the wrong architecture or release was selected,
the vendor republished a file, or provenance was copied incorrectly.

Response: stop the update. Compare authoritative vendor checksums and release
identity. Never change the Catalog digest merely to match the local download.

## Schema and verifier drift

Symptom: a JSON Schema tool accepts data that `bin/verify-catalog` rejects, or
vice versa.

Cause: schema files and executable jq rules are maintained independently.

Response: update both surfaces and add a regression fixture. Until they agree,
the executable verifier remains the CI gate, but the mismatch is a release
finding rather than expected behavior.
