/*
Copyright 2024 The cert-manager Authors.

Licensed under the Apache License, Version 2.0 (the "License");
you may not use this file except in compliance with the License.
You may obtain a copy of the License at

    http://www.apache.org/licenses/LICENSE-2.0

Unless required by applicable law or agreed to in writing, software
distributed under the License is distributed on an "AS IS" BASIS,
WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
See the License for the specific language governing permissions and
limitations under the License.
*/

package cmrand

import (
	"crypto/rand"
	"io"
)

// Reader defaults to pointing at `crypto/rand.Reader` as a central point of configuration
// for random number generation. A custom RNG can be configured globally instead by manually
// changing this.
var Reader io.Reader = rand.Reader
