#import <deque>
#import <vector>
#import <unordered_map>
#import <mach/mach.h>
#import <QuartzCore/QuartzCore.h>
#import <iostream>

struct StackSummary {
    CFTimeInterval time;
    std::vector<uintptr_t> stack;
    
    StackSummary(CFTimeInterval time, std::vector<uintptr_t> &stack) : time(time), stack(stack) {
    }
};

struct ThreadSummary {
    thread_t threadId;
    std::string name;
    std::vector<StackSummary> stacks;
    
    ThreadSummary(thread_t threadId, const std::string &name, std::vector<StackSummary> &stacks) : threadId(threadId), name(name), stacks(stacks) {
    }
};

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
    
    Thread(thread_t threadId, thread_t mainThreadId);
};

class EMGStackTraceRecorder {
    std::unordered_map<unsigned int, Thread> threadsMap;
    std::mutex threadsLock;
    std::deque<uintptr_t> addressStorage;
    bool recordAllThreads;
    
public:
    void recordStackForAllThreads(bool recordAllThreads, thread_t mainMachThread, thread_t etTraceThread);

    std::vector<ThreadSummary> collectThreadSummaries();
};
