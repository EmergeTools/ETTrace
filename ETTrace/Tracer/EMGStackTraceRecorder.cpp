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

static const int kMaxFramesPerStack = 1024;

kern_return_t checkMachCall(kern_return_t result) {
    if (result != KERN_SUCCESS) {
        std::cerr << "Mach call failed with " << result << std::endl;
    }
    return result;
}

Thread::Thread(thread_t threadId, thread_t mainThreadId) {
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
            // Reverse the stack addresses to get the correct order
            std::reverse(addresses.begin(), addresses.end());
            stackSummaries.emplace_back(stack.time, addresses);
        }
        summaries.emplace_back(threadId, thread.name, stackSummaries);
    }
    return summaries;
}

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
    
    // This time gets less accurate for later threads, but still good
    CFTimeInterval time = CACurrentMediaTime();
    for (mach_msg_type_number_t i = 0; i < threadCount; i++) {
        if (threads[i] == etTraceThread) {
            continue;
        }

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
        for (int frame_idx = 0; frame_idx < frameCount; frame_idx++) {
            addressStorage.emplace_back(frames[frame_idx]);
        }
        size_t endIndex = addressStorage.size();
        emplaceResult.first->second.stacks.emplace_back(time, startIndex, endIndex);
    }
    if (recordAllThreads) {
      vm_deallocate(mach_task_self(), (vm_address_t) threads, sizeof(thread_t) * threadCount);
    }
}
