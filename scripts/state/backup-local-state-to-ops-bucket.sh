#!/usr/bin/env bash
set -euo pipefail

SCRIPT_DIR="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd)"
REPO_ROOT="$(cd -- "${SCRIPT_DIR}/../.." && pwd)"
cd "${REPO_ROOT}"

TIMESTAMP_UTC="$(date -u +"%Y%m%dT%H%M%SZ")"
DATE_PREFIX="$(date -u +"%Y/%m/%d")"
REPO_NAME="$(basename "${REPO_ROOT}")"
HOST_TAG="$(hostname | tr '[:upper:]' '[:lower:]' | tr -cs 'a-z0-9._-' '-')"
BACKUP_PREFIX="${STATE_BACKUP_PREFIX:-terraform/bootstrap-state/${REPO_NAME}}"

state_files=()
for candidate in terraform.tfstate terraform.tfstate.backup; do
  if [[ -s "${candidate}" ]]; then
    state_files+=("${candidate}")
  fi
done

if [[ "${#state_files[@]}" -eq 0 ]]; then
  echo "No local Terraform state files found in ${REPO_ROOT}; nothing to back up."
  exit 0
fi

resolve_ops_bucket() {
  if [[ -n "${OPS_BUCKET_NAME:-}" ]]; then
    printf "%s" "${OPS_BUCKET_NAME}"
    return 0
  fi

  if command -v bw >/dev/null 2>&1 && [[ -n "${BW_SESSION:-}" ]]; then
    local item_json
    item_json="$(bw list items --search "AWS Bootstrap Outputs" --session "${BW_SESSION}" 2>/dev/null || true)"
    if [[ -n "${item_json}" ]]; then
      local bucket_from_bw
      bucket_from_bw="$(printf "%s" "${item_json}" | jq -r '
        .[0].fields // []
        | map(select(.name == "OPS_BUCKET_NAME" and (.value // "" | length > 0)) | .value)
        | .[0] // empty
      ' 2>/dev/null || true)"
      if [[ -n "${bucket_from_bw}" ]]; then
        printf "%s" "${bucket_from_bw}"
        return 0
      fi
    fi
  fi

  if command -v terraform >/dev/null 2>&1 && [[ -d ../terraform-aws-bootstrap ]]; then
    local bucket_from_tf
    bucket_from_tf="$(terraform -chdir=../terraform-aws-bootstrap output -raw ops_bucket_name 2>/dev/null || true)"
    if [[ -n "${bucket_from_tf}" ]]; then
      printf "%s" "${bucket_from_tf}"
      return 0
    fi
  fi

  return 1
}

OPS_BUCKET_NAME="$(resolve_ops_bucket || true)"
if [[ -z "${OPS_BUCKET_NAME}" ]]; then
  echo "Could not resolve OPS_BUCKET_NAME. Set OPS_BUCKET_NAME or export BW_SESSION before running backup." >&2
  exit 1
fi

if ! aws sts get-caller-identity >/dev/null 2>&1; then
  echo "AWS credentials are not available for backup upload." >&2
  exit 1
fi

printf "Backing up %d local state file(s) to s3://%s/%s\n" "${#state_files[@]}" "${OPS_BUCKET_NAME}" "${BACKUP_PREFIX}"

for state_file in "${state_files[@]}"; do
  state_sha256="$(sha256sum "${state_file}" | awk '{print $1}')"
  object_key="${BACKUP_PREFIX}/${DATE_PREFIX}/${TIMESTAMP_UTC}/${HOST_TAG}/${state_file}"
  checksum_key="${object_key}.sha256"

  aws s3 cp "${state_file}" "s3://${OPS_BUCKET_NAME}/${object_key}" --sse AES256 --only-show-errors
  printf "%s  %s\n" "${state_sha256}" "${state_file}" | aws s3 cp - "s3://${OPS_BUCKET_NAME}/${checksum_key}" --sse AES256 --only-show-errors

  echo "Uploaded s3://${OPS_BUCKET_NAME}/${object_key}"
  echo "Uploaded s3://${OPS_BUCKET_NAME}/${checksum_key}"
done

echo "Backup upload complete."
