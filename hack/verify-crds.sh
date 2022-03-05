#!/usr/bin/env bash
# Copyright 2020 The cert-manager Authors.
#
# Licensed under the Apache License, Version 2.0 (the "License");
# you may not use this file except in compliance with the License.
# You may obtain a copy of the License at
#
#     http://www.apache.org/licenses/LICENSE-2.0
#
# Unless required by applicable law or agreed to in writing, software
# distributed under the License is distributed on an "AS IS" BASIS,
# WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
# See the License for the specific language governing permissions and
# limitations under the License.

set -o nounset
set -o errexit
set -o pipefail

if [[ -z "${TEST_WORKSPACE:-}" ]]; then
	# Not running inside bazel, so create a tmpdir
	TEST_TMPDIR="$(mktemp -d)"
	trap "rm -rf ${TEST_TMPDIR}" EXIT
fi

usage_and_quit() {
	echo "usage: $0 <update-crds-target> <path-to-go> <path-to-controller-gen> <path-to-yq>" >&2
	exit 1
}

if [ -z "${1:-}" ]; then
	usage_and_quit
fi

if [ -z "${2:-}" ]; then
	usage_and_quit
fi

if [ -z "${3:-}" ]; then
	usage_and_quit
fi

if [ -z "${4:-}" ]; then
	usage_and_quit
fi

echo "Verifying generated CRD manifests are up-to-date..." >&2

update_crds=$1
go=$2
controllergen=$3
yq=$4

tmpfiles=$TEST_TMPDIR/files

(
  mkdir -p "$tmpfiles"
  rm -f bazel-*
  cp -aL "." "$tmpfiles"
  export BUILD_WORKSPACE_DIRECTORY=$tmpfiles
  export HOME=$(realpath "$TEST_TMPDIR/home")
  unset GOPATH
  export PATH=$(dirname "$go"):$PATH
  "$@"
  $update_crds $go $controllergen
)

(
  # Remove the platform/binary for gazelle and kazel
  controllergen=$(dirname "$3")
  rm -rf {.,"$tmpfiles"}/{"controllergen"}
)
# Avoid diff -N so we handle empty files correctly
diff=$(diff -upr \
  -x ".git" \
  -x "bazel-*" \
  -x "_output" \
  "." "$tmpfiles" 2>/dev/null || true)

if [[ -n "${diff}" ]]; then
  echo "${diff}" >&2
  echo >&2
  echo "generated CRDs are out of date. Please run './hack/update-crds.sh'" >&2
  exit 1
fi
echo "SUCCESS: generated CRDs up-to-date"

# Verify that CRDs don't contain status fields as that causes issues when they
# are managed by some CD tools. This check is necessary because currently
# controller-gen adds a status field that needs to be removed manually.
# See https://github.com/cert-manager/cert-manager/pull/4379 for context
crdPath="${tmpfiles}/deploy/crds"
yq=$(realpath "$4")

echo "Verifying that CRDs don't contain .status fields..."
for file in ${crdPath}/*.yaml; do
  name=$($yq e '.metadata.name' $file)
  echo "Verifying that the CRD for $name does not contain a status field"
  # Exit 1 if status is non-null
  $yq e --exit-status=1 '.status==null' $file
done

echo "SUCCESS: generated CRDs don't contain any status fields"
