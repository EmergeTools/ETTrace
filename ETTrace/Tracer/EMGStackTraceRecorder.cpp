#include "EMGStackTraceRecorder.h"

#import <QuartzCore/QuartzCore.h>
#import <mach-o/arch.h>
#import <mach/mach.h>
#import <pthread.h>
#import <deque>
#import <iostream>
#import <mutex>
#import <unordered_map>

extern "C" {
void FIRCLSWriteThreadStack(thread_t thread, uintptr_t *frames, uint64_t framesCapacity, uint64_t *framesWritten);
}

// The block size for deque in my copy of c++ stdlib is:
// static const _DiffType value = sizeof(_ValueType) < 256 ? 4096 / sizeof(_ValueType) : 16;

static const int kMaxFramesPerStack = 1024;

kern_return_t checkMachCall(kern_return_t result) {
    if (result != KERN_SUCCESS) {
        std::cerr << "Call failed with " << result << std::endl;
    }
    return result;
}

struct Stack {
    CFTimeInterval time;
    size_t storageStartIndex; // Inclusive
    size_t storageEndIndex; // Exclusive
    
    Stack(CFTimeInterval time, size_t storageStartIndex, size_t storageEndIndex) : time(time), storageStartIndex(storageStartIndex), storageEndIndex(storageEndIndex) {
    }
};

struct Thread {
    std::deque<Stack> stacks;
    std::string name;

    Thread(thread_t threadId, thread_t mainThreadId) {
        name = "Failed to get name"; // Error case

        if(threadId == mainThreadId) {
            name = "Main Thread";
        } else {
            // Get thread Name
            char cName[1024];
            pthread_t pt = pthread_from_mach_thread_np(threadId);
            if (pt) {
                int rc = pthread_getname_np(pt, cName, sizeof(cName));
                if (rc == 0) {
                    name = cName;
                }
            }
        }
    }
};

std::vector<ThreadSummary> EMGStackTraceRecorder::collectThreadSummaries() {
    std::lock_guard<std::mutex> lockGuard(threadsLock);
    
    std::vector<ThreadSummary> summaries;
    for (const auto &[threadId, thread] : threadsMap) {
        std::vector<StackSummary> stackSummaries;
        for (const auto &stack : thread.stacks) {
            std::vector<uintptr_t> addresses;
            for (auto i = stack.storageStartIndex; i < stack.storageEndIndex; i++) {
                addresses.emplace_back(addressStorage[i]);
            }
            stackSummaries.emplace_back(stack.time, addresses);
        }
    }
    return summaries;
}

// TODO: put recordAllThreads here as parameter?
void EMGStackTraceRecorder::recordStackForAllThreads(bool recordAllThreads, thread_t mainMachThread, thread_t etTraceThread) {
    std::lock_guard<std::mutex> lockGuard(threadsLock);
    thread_act_array_t threads = nullptr;
    mach_msg_type_number_t threadCount = 0;
    if (recordAllThreads) {
        int result = checkMachCall(task_threads(mach_task_self(), &threads, &threadCount));
        if (result != KERN_SUCCESS) {
            threadCount = 0;
        }
    } else {
        threads = &mainMachThread;
        threadCount = 1;
    }
    
    // TODO: how many blocks is it allocating here?
    // TODO: do thread IDs get reused?
    for (mach_msg_type_number_t i = 0; i < threadCount; i++) {
        if (threads[i] == etTraceThread) {
            continue;
        }

        CFTimeInterval time = CACurrentMediaTime();
        uintptr_t frames[kMaxFramesPerStack];
        uint64_t frameCount = 0;

        if (thread_suspend(threads[i]) != KERN_SUCCESS) {
            // In theory, the thread may have been destroyed by now, so we exit early if this fails
            continue;
        }
        // BEGIN REENTRANT SECTION
        FIRCLSWriteThreadStack(threads[i], frames, kMaxFramesPerStack, &frameCount);
        // END REENTRANT SECTION
        checkMachCall(thread_resume(threads[i]));

        auto emplaceResult = threadsMap.try_emplace(threads[i], threads[i], mainMachThread);
        size_t startIndex = addressStorage.size();
        // TODO: previously, we caught an std::length_error here. why was that happening?
        for (int frame = 0; frame < frameCount; frame++) {
            // TODO: reverse here?
            addressStorage.emplace_back(frames[frame]);
        }
        size_t endIndex = addressStorage.size();
        emplaceResult.first->second.stacks.emplace_back(time, startIndex, endIndex);
    }
}
