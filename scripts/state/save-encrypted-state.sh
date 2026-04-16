#!/usr/bin/env bash
set -euo pipefail

SCRIPT_DIR="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd)"
REPO_ROOT="$(cd -- "${SCRIPT_DIR}/../.." && pwd)"
ARTIFACT_DIR="${STATE_SNAPSHOT_DIR:-${REPO_ROOT}/artifacts/hcp-bootstrap-state}"
TIMESTAMP_UTC="$(date -u +"%Y%m%dT%H%M%SZ")"
RETENTION_COUNT="${STATE_SNAPSHOT_RETENTION:-2}"

COMPRESSION_CODEC="${STATE_COMPRESSION_CODEC:-zstd}"
COMPRESSION_LEVEL="${STATE_COMPRESSION_LEVEL:-19}"
AGE_RECIPIENT="${STATE_AGE_RECIPIENT:-${AGE_RECIPIENT:-}}"
AGE_RECIPIENT_FILE="${STATE_AGE_RECIPIENT_FILE:-${AGE_RECIPIENT_FILE:-$HOME/.config/sops/age/yubikey.txt}}"
SOPS_AGE_RECIPIENTS="${STATE_SOPS_AGE_RECIPIENTS:-${SOPS_AGE_RECIPIENTS:-}}"

RAW_OUTPUTS_FILE="${ARTIFACT_DIR}/outputs-${TIMESTAMP_UTC}.json"
RAW_STATE_FILE="${ARTIFACT_DIR}/state-${TIMESTAMP_UTC}.tfstate"
COMPRESSED_OUTPUTS_FILE="${RAW_OUTPUTS_FILE}.zst"
COMPRESSED_STATE_FILE="${RAW_STATE_FILE}.zst"
ENCRYPTED_OUTPUTS_FILE="${COMPRESSED_OUTPUTS_FILE}.age"
ENCRYPTED_STATE_FILE="${COMPRESSED_STATE_FILE}.age"
MANIFEST_FILE="${ARTIFACT_DIR}/snapshot-${TIMESTAMP_UTC}.json"

cleanup_intermediates() {
  rm -f "${RAW_OUTPUTS_FILE}" "${RAW_STATE_FILE}" "${COMPRESSED_OUTPUTS_FILE}" "${COMPRESSED_STATE_FILE}"
}

trap cleanup_intermediates EXIT

if [[ "${COMPRESSION_CODEC}" != "zstd" ]]; then
  echo "Unsupported STATE_COMPRESSION_CODEC='${COMPRESSION_CODEC}'. Supported: zstd." >&2
  exit 1
fi

if [[ -n "${AGE_RECIPIENT}" && -n "${SOPS_AGE_RECIPIENTS}" ]]; then
  echo "Set only one of STATE_AGE_RECIPIENT/AGE_RECIPIENT or STATE_SOPS_AGE_RECIPIENTS/SOPS_AGE_RECIPIENTS." >&2
  exit 1
fi

if [[ -n "${AGE_RECIPIENT}" ]]; then
  SOPS_AGE_RECIPIENTS="${AGE_RECIPIENT}"
fi

if [[ -z "${SOPS_AGE_RECIPIENTS}" && -f "${AGE_RECIPIENT_FILE}" ]]; then
  # Try to extract first age recipient from the configured file.
  SOPS_AGE_RECIPIENTS="$(grep -Eo 'age1[0-9a-z]+' "${AGE_RECIPIENT_FILE}" | head -n 1 || true)"
fi

if [[ -z "${SOPS_AGE_RECIPIENTS}" ]]; then
  echo "No SOPS age recipient configured. Set STATE_SOPS_AGE_RECIPIENTS (or STATE_AGE_RECIPIENT) with an age1... recipient." >&2
  echo "If using YubiKey via nix-config, get recipient with: age-plugin-yubikey --list" >&2
  exit 1
fi

mkdir -p "${ARTIFACT_DIR}"
cd "${REPO_ROOT}"

terraform output -json >"${RAW_OUTPUTS_FILE}"
terraform state pull >"${RAW_STATE_FILE}"

zstd -q -T0 -"${COMPRESSION_LEVEL}" -f "${RAW_STATE_FILE}" -o "${COMPRESSED_STATE_FILE}"
zstd -q -T0 -"${COMPRESSION_LEVEL}" -f "${RAW_OUTPUTS_FILE}" -o "${COMPRESSED_OUTPUTS_FILE}"

export SOPS_AGE_RECIPIENTS
sops --encrypt --input-type binary --output-type binary "${COMPRESSED_STATE_FILE}" >"${ENCRYPTED_STATE_FILE}"
sops --encrypt --input-type binary --output-type binary "${COMPRESSED_OUTPUTS_FILE}" >"${ENCRYPTED_OUTPUTS_FILE}"

STATE_SHA256="$(sha256sum "${RAW_STATE_FILE}" | awk '{print $1}')"
STATE_ENCRYPTED_SHA256="$(sha256sum "${ENCRYPTED_STATE_FILE}" | awk '{print $1}')"
OUTPUTS_SHA256="$(sha256sum "${RAW_OUTPUTS_FILE}" | awk '{print $1}')"
OUTPUTS_ENCRYPTED_SHA256="$(sha256sum "${ENCRYPTED_OUTPUTS_FILE}" | awk '{print $1}')"
STATE_SERIAL="$(jq -r '.serial // 0' "${RAW_STATE_FILE}")"
STATE_LINEAGE="$(jq -r '.lineage // ""' "${RAW_STATE_FILE}")"
STATE_RESOURCE_COUNT="$(jq -r '[.resources[]?] | length' "${RAW_STATE_FILE}")"
HCP_PROJECT_ID="$(jq -r '.hcp_project_id.value // ""' "${RAW_OUTPUTS_FILE}")"
TFE_ORG_NAME="$(jq -r '.tfe_organization_name.value // ""' "${RAW_OUTPUTS_FILE}")"
TFE_PROJECT_ID="$(jq -r '.tfe_project_id.value // ""' "${RAW_OUTPUTS_FILE}")"

jq -n \
  --arg timestamp "${TIMESTAMP_UTC}" \
  --arg compression_codec "${COMPRESSION_CODEC}" \
  --arg compression_level "${COMPRESSION_LEVEL}" \
  --arg recipient_file "${AGE_RECIPIENT_FILE}" \
  --arg recipients "${SOPS_AGE_RECIPIENTS}" \
  --arg state_file "$(basename "${ENCRYPTED_STATE_FILE}")" \
  --arg outputs_file "$(basename "${ENCRYPTED_OUTPUTS_FILE}")" \
  --arg state_sha "${STATE_SHA256}" \
  --arg state_encrypted_sha "${STATE_ENCRYPTED_SHA256}" \
  --arg outputs_sha "${OUTPUTS_SHA256}" \
  --arg outputs_encrypted_sha "${OUTPUTS_ENCRYPTED_SHA256}" \
  --arg state_serial "${STATE_SERIAL}" \
  --arg state_lineage "${STATE_LINEAGE}" \
  --arg state_resource_count "${STATE_RESOURCE_COUNT}" \
  --arg hcp_project_id "${HCP_PROJECT_ID}" \
  --arg tfe_org_name "${TFE_ORG_NAME}" \
  --arg tfe_project_id "${TFE_PROJECT_ID}" \
  '{
    timestamp_utc: $timestamp,
    compression: {
      codec: $compression_codec,
      level: $compression_level
    },
    encryption: {
      type: "sops+age",
      recipient_file: $recipient_file,
      recipients: $recipients
    },
    files: {
      state: $state_file,
      outputs: $outputs_file
    },
    hashes: {
      state_sha256: $state_sha,
      state_encrypted_sha256: $state_encrypted_sha,
      outputs_sha256: $outputs_sha,
      outputs_encrypted_sha256: $outputs_encrypted_sha
    },
    terraform_state: {
      serial: $state_serial,
      lineage: $state_lineage,
      resource_count: $state_resource_count
    },
    hcp: {
      project_id: $hcp_project_id,
      tfe_organization_name: $tfe_org_name,
      tfe_project_id: $tfe_project_id
    }
  }' >"${MANIFEST_FILE}"

prune_snapshots() {
  local manifest
  local timestamp
  mapfile -t manifests < <(find "${ARTIFACT_DIR}" -maxdepth 1 -type f -name 'snapshot-*.json' | sort -r)

  if (( ${#manifests[@]} <= RETENTION_COUNT )); then
    return
  fi

  for manifest in "${manifests[@]:RETENTION_COUNT}"; do
    timestamp="$(basename "${manifest}")"
    timestamp="${timestamp#snapshot-}"
    timestamp="${timestamp%.json}"
    rm -f \
      "${ARTIFACT_DIR}/snapshot-${timestamp}.json" \
      "${ARTIFACT_DIR}/state-${timestamp}.tfstate.zst.age" \
      "${ARTIFACT_DIR}/outputs-${timestamp}.json.zst.age"
  done
}

prune_snapshots

echo "Encrypted state snapshot saved."
echo "State: ${ENCRYPTED_STATE_FILE}"
echo "Outputs: ${ENCRYPTED_OUTPUTS_FILE}"
echo "Manifest: ${MANIFEST_FILE}"
echo "Retention: keeping latest ${RETENTION_COUNT} snapshot generations"