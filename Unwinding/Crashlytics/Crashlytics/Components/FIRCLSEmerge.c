// Copyright 2019 Google
//
// Licensed under the Apache License, Version 2.0 (the "License");
// you may not use this file except in compliance with the License.
// You may obtain a copy of the License at
//
//      http://www.apache.org/licenses/LICENSE-2.0
//
// Unless required by applicable law or agreed to in writing, software
// distributed under the License is distributed on an "AS IS" BASIS,
// WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
// See the License for the specific language governing permissions and
// limitations under the License.

#include "../Helpers/FIRCLSDefines.h"
#include "../Helpers/FIRCLSThreadState.h"
#include "../Unwind/FIRCLSUnwind.h"
#include "../Helpers/FIRCLSUtility.h"

#include <mach/mach.h>
#include <stdbool.h>
#include <dispatch/dispatch.h>
#include <objc/message.h>
#include <pthread.h>
#include <sys/sysctl.h>

#define THREAD_NAME_BUFFER_SIZE (64)

void FIRCLSWriteThreadStack(thread_t thread, uintptr_t *frames, uint64_t framesCapacity, uint64_t *framesWritten) {
  *framesWritten = 0;
  FIRCLSUnwindContext unwindContext;
  FIRCLSThreadContext context;

  // try to get the value by querying the thread state
  mach_msg_type_number_t stateCount = FIRCLSThreadStateCount;

  // For unknown reasons, thread_get_state returns this value on Rosetta,
  // but still succeeds.
  const int ROSETTA_SUCCESS = 268435459;
  kern_return_t status = thread_get_state(thread, FIRCLSThreadState, (thread_state_t)(&(context.__ss)),
                                   &stateCount);
  if (status != KERN_SUCCESS && status != ROSETTA_SUCCESS) {
    FIRCLSSDKLogError("Failed to get thread state via thread_get_state for thread: %i\n", thread);
    *framesWritten = 0;
    return;
  }

  if (!FIRCLSUnwindInit(&unwindContext, context)) {
    FIRCLSSDKLog("Unable to init unwind context\n");
    return;
  }

  uint32_t repeatedPCCount = 0;
  uint64_t repeatedPC = 0;
  while (FIRCLSUnwindNextFrame(&unwindContext) && (*framesWritten) < framesCapacity) {
    const uintptr_t pc = FIRCLSUnwindGetPC(&unwindContext);
    const uint32_t frameCount = FIRCLSUnwindGetFrameRepeatCount(&unwindContext);

    if (repeatedPC == pc && repeatedPC != 0) {
      // actively counting a recursion
      repeatedPCCount = frameCount;
      continue;
    }

    if (frameCount >= FIRCLSUnwindInfiniteRecursionCountThreshold && repeatedPC == 0) {
      repeatedPC = pc;
      continue;
    }

    frames[*framesWritten] = pc;
    (*framesWritten)++;
  }
  return;
}

