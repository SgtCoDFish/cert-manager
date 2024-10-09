/*
Copyright 2020 The cert-manager Authors.

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

package main

import (
	"context"
	"encoding/hex"
	"flag"
	"fmt"
	"math"
	"sync"

	"github.com/cert-manager/cert-manager/controller-binary/app"
	"github.com/cert-manager/cert-manager/internal/cmd/util"
	"github.com/cert-manager/cert-manager/pkg/cmrand"
	logf "github.com/cert-manager/cert-manager/pkg/logs"

	"github.com/google/go-tpm/tpm2"
	"github.com/google/go-tpm/tpm2/transport"
	"github.com/google/go-tpm/tpm2/transport/simulator"
)

type tpmRandReader struct {
	TPM transport.TPMCloser

	mu sync.Mutex
}

func (r *tpmRandReader) Read(data []byte) (n int, err error) {
	r.mu.Lock()
	defer r.mu.Unlock()

	if len(data) > math.MaxUint16 {
		return 0, fmt.Errorf("tpm-rand: number of bytes to read cannot exceed math.MaxInt16")
	}

	grc := tpm2.GetRandom{
		BytesRequested: uint16(len(data)),
	}

	randResponse, err := grc.Execute(r.TPM)
	if err != nil {
		return 0, fmt.Errorf("tpm GetRandom failed: %v", err)
	}

	copy(data, randResponse.RandomBytes.Buffer)

	return len(data), nil
}

func NewTPMRandReader(tpm transport.TPMCloser) *tpmRandReader {
	return &tpmRandReader{
		TPM: tpm,
	}
}

func main() {
	fmt.Println("hello world")

	theTPM, err := simulator.OpenSimulator()
	if err != nil {
		panic(fmt.Errorf("couldn't open TPM simulator: %v", err))
	}

	defer func() {
		err := theTPM.Close()
		if err != nil {
			panic(fmt.Errorf("failed to close TPM simulator: %v", err))
		}
	}()

	cmrand.Reader = NewTPMRandReader(theTPM)

	buf := make([]byte, 16)

	n, err := cmrand.Reader.Read(buf)
	if err != nil {
		panic(fmt.Errorf("failed to get rand: %s", err))
	}

	if n != 16 {
		panic("didn't read exactly 16 bytes")
	}

	fmt.Println("so random lol:", hex.EncodeToString(buf))

	ctx, exit := util.SetupExitHandler(context.Background(), util.GracefulShutdown)
	defer exit() // This function might call os.Exit, so defer last

	logf.InitLogs()
	defer logf.FlushLogs()
	ctx = logf.NewContext(ctx, logf.Log, "controller")

	cmd := app.NewServerCommand(ctx)
	cmd.Flags().AddGoFlagSet(flag.CommandLine)

	if err := cmd.ExecuteContext(ctx); err != nil {
		logf.Log.Error(err, "error executing command")
		util.SetExitCode(err)
	}
}
