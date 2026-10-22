#!/bin/bash
# SPDX-FileCopyrightText: 2026 dalsoop
# SPDX-License-Identifier: GPL-3.0-only
set -euo pipefail

script_dir=$(CDPATH='' cd -- "$(dirname -- "$0")" && pwd)
repo_root=$(CDPATH='' cd -- "$script_dir/.." && pwd)
validator=$repo_root/build/verify-distribution-contracts
policy=$repo_root/build/distribution-policy.json
temporary=$(mktemp -d)
temporary=$(CDPATH='' cd -- "$temporary" && pwd -P)
trap 'rm -rf "$temporary"' EXIT HUP INT TERM

sha256_file() {
    if command -v sha256sum >/dev/null 2>&1; then
        sha256sum "$1" | awk '{print $1}'
    else
        shasum -a 256 "$1" | awk '{print $1}'
    fi
}

expect_failure() {
    description=$1
    shift
    if "$@" >"$temporary/rejected.stdout" 2>"$temporary/rejected.stderr"; then
        echo "dns-license-simulation: accepted $description" >&2
        exit 1
    fi
}

assert_exact_keys() {
    fixture=$1
    expected=$2
    description=$3
    jq -e --argjson expected "$expected" \
        '(keys | sort) == ($expected | sort)' "$fixture" >/dev/null || {
        echo "dns-license-simulation: wrong top-level keys for $description" >&2
        exit 1
    }
}

policy_sha256=$(sha256_file "$policy")
registry=$temporary/component-registry.json

jq -n '{
      schema_version: 1,
      artifact_id: "dns-appliance",
      components: [
        {id:"debian-package-closure",version:"13.7.0@20261011T000000Z",digest:{algorithm:"sha256",value:("a"*64)},redistribution:{status:"personal-use-only"}},
        {id:"technitium-oci",version:"15.6.1",digest:{algorithm:"sha256",value:("b"*64)},source_identity:{kind:"oci-digest",value:("sha256:"+("1"*64))},redistribution:{status:"personal-use-only"}},
        {id:"tailscale-archive",version:"1.104.1",digest:{algorithm:"sha256",value:("c"*64)},redistribution:{status:"personal-use-only"}},
        {id:"tailscale-dependency-report",version:"1.104.1",digest:{algorithm:"sha256",value:("d"*64)},redistribution:{status:"personal-use-only"}},
        {id:"repository-source-snapshot",version:("e"*40),digest:{algorithm:"sha256",value:("f"*64)},redistribution:{status:"personal-use-only"}}
      ]
    }' > "$registry"

assert_exact_keys "$registry" '["schema_version","artifact_id","components"]' \
    "the component registry regression fixture"
"$validator" --registry "$registry" --policy "$policy" >/dev/null

jq 'del(.components[0].version)' "$registry" > "$temporary/malformed.json"
expect_failure "a malformed component" \
    "$validator" --registry "$temporary/malformed.json" --policy "$policy"

jq 'del(.components[4])' "$registry" > "$temporary/missing.json"
expect_failure "a missing component" \
    "$validator" --registry "$temporary/missing.json" --policy "$policy"

jq '.components[4].id = .components[0].id' "$registry" > "$temporary/duplicate.json"
expect_failure "duplicate component IDs" \
    "$validator" --registry "$temporary/duplicate.json" --policy "$policy"

jq '.policy = {id:"dns-composite-image-redistribution-v1",sha256:("0"*64)}' \
    "$registry" > "$temporary/old-registry-top-level.json"
expect_failure "the old registry top-level policy object" \
    "$validator" --registry "$temporary/old-registry-top-level.json" --policy "$policy"

jq '.components[0].status = "personal-use-only"' "$registry" \
    > "$temporary/top-level-component-status.json"
expect_failure "a top-level component status" \
    "$validator" --registry "$temporary/top-level-component-status.json" --policy "$policy"

jq 'del(.components[1].source_identity)' "$registry" \
    > "$temporary/technitium-source-identity-missing.json"
expect_failure "a Technitium component without source identity" \
    "$validator" --registry "$temporary/technitium-source-identity-missing.json" \
    --policy "$policy"

jq '.components[0].source_identity = {kind:"oci-digest",value:("sha256:"+("2"*64))}' \
    "$registry" > "$temporary/non-technitium-source-identity.json"
expect_failure "source identity on a non-Technitium component" \
    "$validator" --registry "$temporary/non-technitium-source-identity.json" \
    --policy "$policy"

review=$temporary/technitium-review.json
jq -n \
    --slurpfile policy "$policy" \
    '{
      schema_version: 1,
      status: "redistribution-reviewed",
      component_id: "technitium-oci",
      component_version: "15.6.1",
      artifact_sha256: ("b"*64),
      source_identity: {kind:"oci-digest",value:("sha256:"+("1"*64))},
      reviewed_at: "2026-10-17",
      reviewer: "license-reviewer@example.invalid",
      evidence: ($policy[0].evidence_kinds | map({kind:.,url:("https://evidence.example.invalid/"+.+".txt")})),
      obligations: ($policy[0].obligation_kinds | map({kind:.,disposition:"embedded-artifact",location:{scope:"artifact",path:("licenses/"+.+".txt"),sha256:("3"*64)}}))
    }' > "$review"

jq -n '
  ["SPDXRef-DebianPackageClosure","SPDXRef-Technitium","SPDXRef-Tailscale","SPDXRef-TailscaleDependencyReport","SPDXRef-DIYDeviceOSBootstrap"] as $described |
  {
    spdxVersion:"SPDX-2.3",
    dataLicense:"CC0-1.0",
    SPDXID:"SPDXRef-DOCUMENT",
    name:"dns-appliance-installer-dns-test-build",
    documentNamespace:"https://github.com/dalsoop/diy-device-os-bootstrap/sbom/eeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeee/dns-appliance-installer-dns-test-build",
    creationInfo:{created:"2026-10-17T00:00:00Z",creators:["Tool: dns-license-simulation"]},
    documentDescribes:$described,
    packages:($described | to_entries | map({
      name:("component-"+(.key|tostring)),
      versionInfo:"1.0.0",
      SPDXID:.value,
      downloadLocation:("https://artifacts.example.invalid/"+(.key|tostring)),
      filesAnalyzed:false,
      licenseDeclared:(if .key == 0 then "NOASSERTION" else "GPL-3.0-only" end),
      licenseConcluded:"GPL-3.0-only",
      copyrightText:"Copyright test"
    }))
  }
' > "$temporary/sbom-noassertion.json"

expect_failure "reviewed promotion while the SBOM contains NOASSERTION" \
    "$validator" --registry "$registry" --policy "$policy" \
    --component-review "$review" --sbom "$temporary/sbom-noassertion.json"

for noassertion_variant in ' noassertion ' 'LicenseRef-NoAssertion'; do
    jq --arg value "$noassertion_variant" '.packages[0].licenseDeclared=$value' \
        "$temporary/sbom-noassertion.json" > "$temporary/sbom-noassertion-variant.json"
    expect_failure "a normalized or decorated NOASSERTION value: $noassertion_variant" \
        "$validator" --registry "$registry" --policy "$policy" \
        --component-review "$review" --sbom "$temporary/sbom-noassertion-variant.json"
done

jq '.packages[0].licenseDeclared="GPL-3.0-only"' \
    "$temporary/sbom-noassertion.json" > "$temporary/sbom-complete.json"
jq '.artifact_sha256 = ("9"*64)' "$review" > "$temporary/component-digest-mismatch.json"
expect_failure "a component review artifact digest mismatch" \
    "$validator" --registry "$registry" --policy "$policy" \
    --component-review "$temporary/component-digest-mismatch.json" \
    --sbom "$temporary/sbom-complete.json"
jq 'del(.source_identity)' "$review" > "$temporary/component-source-identity-missing.json"
expect_failure "a component review that drops OCI source identity" \
    "$validator" --registry "$registry" --policy "$policy" \
    --component-review "$temporary/component-source-identity-missing.json" \
    --sbom "$temporary/sbom-complete.json"
"$validator" --registry "$registry" --policy "$policy" \
    --component-review "$review" --sbom "$temporary/sbom-complete.json" >/dev/null

reviewed_registry=$temporary/reviewed-registry.json
jq --slurpfile policy "$policy" '
  .components |= map(
    . as $component |
    .redistribution = ({
      schema_version: 1,
      status: "redistribution-reviewed",
      component_id: $component.id,
      component_version: $component.version,
      artifact_sha256: $component.digest.value,
      reviewed_at: "2026-10-17",
      reviewer: "license-reviewer@example.invalid",
      evidence: ($policy[0].evidence_kinds | map({kind:.,url:("https://evidence.example.invalid/"+.+".txt")})),
      obligations: ($policy[0].obligation_kinds | map({kind:.,disposition:"embedded-artifact",location:{scope:"artifact",path:("licenses/"+.+".txt"),sha256:("3"*64)}}))
    } + if $component | has("source_identity")
         then {source_identity:$component.source_identity}
         else {}
         end)
  )
' "$registry" > "$reviewed_registry"
"$validator" --registry "$reviewed_registry" --policy "$policy" >/dev/null

jq 'del(.components[1].redistribution.source_identity)' "$reviewed_registry" \
    > "$temporary/reviewed-technitium-source-identity-missing.json"
expect_failure "reviewed Technitium redistribution without source identity" \
    "$validator" \
    --registry "$temporary/reviewed-technitium-source-identity-missing.json" \
    --policy "$policy"

jq '.components[1].redistribution.source_identity.value = ("sha256:"+("2"*64))' \
    "$reviewed_registry" \
    > "$temporary/reviewed-technitium-source-identity-mismatch.json"
expect_failure "reviewed Technitium redistribution with mismatched source identity" \
    "$validator" \
    --registry "$temporary/reviewed-technitium-source-identity-mismatch.json" \
    --policy "$policy"

registry_sha256=$(sha256_file "$reviewed_registry")
sbom_sha256=$(sha256_file "$temporary/sbom-complete.json")

manifest=$temporary/build-manifest.json
jq -n \
    --arg registry_sha256 "$registry_sha256" \
    --arg policy_sha256 "$policy_sha256" \
    --arg sbom_sha256 "$sbom_sha256" \
    --slurpfile registry "$reviewed_registry" \
    '{
      schema_version: 1,
      artifact_id: "dns-appliance",
      build_id: "dns-test-build",
      install_mode: "guided",
      iso: "dns-test.iso",
      iso_sha256: ("4"*64),
      distribution_status: "redistribution-reviewed",
      component_registry: "component-redistribution-registry.json",
      component_registry_sha256: $registry_sha256,
      distribution_policy_sha256: $policy_sha256,
      components: ($registry[0].components | map({id,status:.redistribution.status})),
      sbom: "sbom.spdx.json",
      sbom_sha256: $sbom_sha256,
      debian_point_release: "13.7.0",
      debian_snapshot: "20261011T000000Z",
      technitium_version: "15.6.1",
      technitium_image_digest: ("sha256:"+("1"*64)),
      technitium_archive_sha256: ("b"*64),
      tailscale_version: "1.104.1",
      tailscale_archive_sha256: ("c"*64),
      source_revision: ("e"*40),
      source_repository: "https://github.com/dalsoop/diy-device-os-bootstrap",
      source_archive: ("https://github.com/dalsoop/diy-device-os-bootstrap/archive/"+("e"*40)+".tar.gz")
    }' > "$manifest"
manifest_sha256=$(sha256_file "$manifest")

final_review=$temporary/final-review.json
jq -n \
    --arg registry_sha256 "$registry_sha256" \
    --arg manifest_sha256 "$manifest_sha256" \
    --slurpfile policy "$policy" \
    '{
      schema_version: 1,
      artifact: {id:"dns-appliance",sha256:("4"*64)},
      inputs: {
        component_registry_sha256: $registry_sha256,
        build_manifest_sha256: $manifest_sha256
      },
      reviewed_at: "2026-10-17",
      reviewer: "license-reviewer@example.invalid",
      evidence: ($policy[0].evidence_kinds | map({kind:.,url:("https://evidence.example.invalid/"+.+".txt")})),
      obligations: ($policy[0].obligation_kinds | map({kind:.,disposition:"bundle-file",location:{scope:"release-bundle",path:("licenses/"+.+".txt"),sha256:("6"*64)}}))
    }' > "$final_review"

assert_exact_keys "$final_review" \
    '["schema_version","artifact","inputs","reviewed_at","reviewer","evidence","obligations"]' \
    "the final review regression fixture"
"$validator" --registry "$reviewed_registry" --policy "$policy" \
    --final-review "$final_review" --build-manifest "$manifest" \
    --sbom "$temporary/sbom-complete.json" >/dev/null

jq '.status = "redistribution-reviewed"' "$final_review" \
    > "$temporary/final-review-with-status.json"
expect_failure "a final review with the removed top-level status" \
    "$validator" --registry "$reviewed_registry" --policy "$policy" \
    --final-review "$temporary/final-review-with-status.json" \
    --build-manifest "$manifest" --sbom "$temporary/sbom-complete.json"

incomplete_manifest=$temporary/incomplete-build-manifest.json
jq 'del(.debian_point_release)' "$manifest" > "$incomplete_manifest"
incomplete_manifest_sha256=$(sha256_file "$incomplete_manifest")
jq --arg sha256 "$incomplete_manifest_sha256" '.inputs.build_manifest_sha256=$sha256' \
    "$final_review" > "$temporary/incomplete-manifest-final-review.json"
expect_failure "a schema-incomplete build manifest with a matching review hash" \
    "$validator" --registry "$reviewed_registry" --policy "$policy" \
    --final-review "$temporary/incomplete-manifest-final-review.json" \
    --build-manifest "$incomplete_manifest" --sbom "$temporary/sbom-complete.json"

jq 'del(.sbom_sha256)' "$manifest" > "$temporary/unbound-sbom-build-manifest.json"
unbound_manifest_sha256=$(sha256_file "$temporary/unbound-sbom-build-manifest.json")
jq --arg sha256 "$unbound_manifest_sha256" '.inputs.build_manifest_sha256=$sha256' \
    "$final_review" > "$temporary/unbound-sbom-final-review.json"
expect_failure "a build manifest without an SBOM digest binding" \
    "$validator" --registry "$reviewed_registry" --policy "$policy" \
    --final-review "$temporary/unbound-sbom-final-review.json" \
    --build-manifest "$temporary/unbound-sbom-build-manifest.json" \
    --sbom "$temporary/sbom-complete.json"

printf '{}\n' > "$temporary/substitute-empty-sbom.json"
expect_failure "an empty substitute SBOM" \
    "$validator" --registry "$reviewed_registry" --policy "$policy" \
    --final-review "$final_review" --build-manifest "$manifest" \
    --sbom "$temporary/substitute-empty-sbom.json"

jq '.name += "-substitute"' "$temporary/sbom-complete.json" \
    > "$temporary/substitute-valid-sbom.json"
expect_failure "a valid-shaped SBOM whose bytes do not match the build manifest" \
    "$validator" --registry "$reviewed_registry" --policy "$policy" \
    --final-review "$final_review" --build-manifest "$manifest" \
    --sbom "$temporary/substitute-valid-sbom.json"

jq 'del(.obligations[3])' "$final_review" > "$temporary/incomplete-final-review.json"
expect_failure "an incomplete final review record" \
    "$validator" --registry "$reviewed_registry" --policy "$policy" \
    --final-review "$temporary/incomplete-final-review.json" \
    --build-manifest "$manifest" --sbom "$temporary/sbom-complete.json"

jq '.inputs.component_registry_sha256 = ("7"*64)' "$final_review" \
    > "$temporary/final-digest-mismatch.json"
expect_failure "a final-review registry digest mismatch" \
    "$validator" --registry "$reviewed_registry" --policy "$policy" \
    --final-review "$temporary/final-digest-mismatch.json" \
    --build-manifest "$manifest" --sbom "$temporary/sbom-complete.json"

echo "DNS license simulations: passed"
