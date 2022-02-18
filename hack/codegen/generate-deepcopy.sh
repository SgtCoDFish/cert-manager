#!/usr/bin/env bash
# Copyright 2022 The cert-manager Authors.
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

set -eu -o pipefail

deepcopygen=$1

module_name="github.com/cert-manager/cert-manager"

# Generate deepcopy functions for all internal and external APIs
deepcopy_inputs=(
  internal/apis/certmanager/v1alpha2 \
  internal/apis/certmanager/v1alpha3 \
  internal/apis/certmanager/v1beta1 \
  pkg/apis/certmanager/v1 \
  internal/apis/certmanager \
  internal/apis/acme/v1alpha2 \
  internal/apis/acme/v1alpha3 \
  internal/apis/acme/v1beta1 \
  pkg/apis/acme/v1 \
  internal/apis/acme \
  pkg/apis/config/webhook/v1alpha1 \
  internal/apis/config/webhook \
  pkg/apis/meta/v1 \
  internal/apis/meta \
  pkg/webhook/handlers/testdata/apis/testgroup/v2 \
  pkg/webhook/handlers/testdata/apis/testgroup/v1 \
  pkg/webhook/handlers/testdata/apis/testgroup \
  pkg/acme/webhook/apis/acme/v1alpha1 \
)

clean() {
  path=$1
  name=$2
  if [[ ! -d "$path" ]]; then
    return 0
  fi
  find "$path" -name "$name" -delete
}

clean pkg/apis 'zz_generated.deepcopy.go'
clean pkg/acme/webhook/apis 'zz_generated.deepcopy.go'
clean pkg/webhook/handlers/testdata/apis 'zz_generated.deepcopy.go'

echo "+++ generating deepcopy methods" >&2

prefixed_inputs=( "${deepcopy_inputs[@]/#/$module_name/}" )
echo "prefixed inputs: ${prefixed_inputs[*]}"
joined=$( IFS=$','; echo "${prefixed_inputs[*]}" )

echo "joined: $joined"

"$deepcopygen" \
	--go-header-file hack/boilerplate/boilerplate.generatego.txt \
	--input-dirs "$joined" \
	--output-file-base zz_generated.deepcopy \
	--trim-path-prefix="$module_name" \
	--bounding-dirs "${module_name}" \
	--output-base .
