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

#include "FIRCLSUtility.h"

#include <mach/mach.h>

#include <dlfcn.h>

#include "../Components/FIRCLSGlobals.h"
#include "FIRCLSFeatures.h"

#import <CommonCrypto/CommonHMAC.h>

void FIRCLSLookupFunctionPointer(void* ptr, void (^block)(const char* name, const char* lib)) {
  Dl_info info;

  if (dladdr(ptr, &info) == 0) {
    block(NULL, NULL);
    return;
  }

  const char* name = "unknown";
  const char* lib = "unknown";

  if (info.dli_sname) {
    name = info.dli_sname;
  }

  if (info.dli_fname) {
    lib = info.dli_fname;
  }

  block(name, lib);
}

uint8_t FIRCLSNybbleFromChar(char c) {
  if (c >= '0' && c <= '9') {
    return c - '0';
  }

  if (c >= 'a' && c <= 'f') {
    return c - 'a' + 10;
  }

  if (c >= 'A' && c <= 'F') {
    return c - 'A' + 10;
  }

  return FIRCLSInvalidCharNybble;
}

bool FIRCLSReadMemory(vm_address_t src, void* dest, size_t len) {
  if (!FIRCLSIsValidPointer(src)) {
    return false;
  }

  vm_size_t readSize = len;

  // Originally this was a `vm_read_overwrite` to protect against reading invalid memory.
  // That can happen in the context of a crash reporter, but should not happen during normal
  // ettrace operation. Replacing it with memcpy makes this about 5x faster
  // return vm_read_overwrite(mach_task_self(), src, len, (pointer_t)dest, &readSize) == KERN_SUCCESS;
  memcpy(dest, src, len);
  return true;
}

bool FIRCLSReadString(vm_address_t src, char** dest, size_t maxlen) {
  char c;
  vm_address_t address;

  if (!dest) {
    return false;
  }

  // Walk the entire string.  Not certain this is perfect...
  for (address = src; address < src + maxlen; ++address) {
    if (!FIRCLSReadMemory(address, &c, 1)) {
      return false;
    }

    if (c == 0) {
      break;
    }
  }

  *dest = (char*)src;

  return true;
}

void FIRCLSDispatchAfter(float timeInSeconds, dispatch_queue_t queue, dispatch_block_t block) {
  dispatch_after(dispatch_time(DISPATCH_TIME_NOW, (int64_t)(timeInSeconds * NSEC_PER_SEC)), queue,
                 block);
}

bool FIRCLSUnlinkIfExists(const char* path) {
  if (unlink(path) != 0) {
    if (errno != ENOENT) {
      return false;
    }
  }

  return true;
}

NSString* FIRCLSNormalizeUUID(NSString* value) {
  return [[value stringByReplacingOccurrencesOfString:@"-" withString:@""] lowercaseString];
}

// Redacts a UUID wrapped in parenthesis from a char* using strchr, which is async safe.
// Ex.
//   "foo (bar) (45D62CC2-CFB5-4E33-AB61-B0684627F1B6) baz"
// becomes
//   "foo (bar) (********-****-****-****-************) baz"
void FIRCLSRedactUUID(char* value) {
  if (value == NULL) {
    return;
  }
  char* openParen = value;
  // find the index of the first paren
  while ((openParen = strchr(openParen, '(')) != NULL) {
    // find index of the matching close paren
    const char* closeParen = strchr(openParen, ')');
    if (closeParen == NULL) {
      break;
    }
    // if the distance between them is 37, traverse the characters
    // and replace anything that is not a '-' with '*'
    if (closeParen - openParen == 37) {
      for (int i = 1; i < 37; ++i) {
        if (*(openParen + i) != '-') {
          *(openParen + i) = '*';
        }
      }
      break;
    }
    openParen++;
  }
}

void FIRCLSAddOperationAfter(float timeInSeconds, NSOperationQueue* queue, void (^block)(void)) {
  dispatch_queue_t afterQueue = dispatch_get_global_queue(DISPATCH_QUEUE_PRIORITY_DEFAULT, 0);
  FIRCLSDispatchAfter(timeInSeconds, afterQueue, ^{
    [queue addOperationWithBlock:block];
  });
}

#if DEBUG
void FIRCLSPrintAUUID(const uint8_t* value) {
  CFUUIDRef uuid = CFUUIDCreateFromUUIDBytes(kCFAllocatorDefault, *(CFUUIDBytes*)value);

  NSString* string = CFBridgingRelease(CFUUIDCreateString(kCFAllocatorDefault, uuid));

  CFRelease(uuid);

  FIRCLSDebugLog(@"%@", [[string stringByReplacingOccurrencesOfString:@"-"
                                                           withString:@""] lowercaseString]);
}
#endif
