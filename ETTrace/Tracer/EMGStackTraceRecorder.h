#import <deque>
#import <vector>
#import <unordered_map>
#import <mach/mach.h>
#import <QuartzCore/QuartzCore.h>

class Thread;

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
    
    ThreadSummary(thread_t threadId, std::string &name, std::vector<StackSummary> &stacks) : threadId(threadId), name(name), stacks(stacks) {
    }
};

class EMGStackTraceRecorder {
    std::unordered_map<unsigned int, Thread> threadsMap;
    std::mutex threadsLock;
    std::deque<ptrdiff_t> addressStorage;
    bool recordAllThreads;
    
public:
    EMGStackTraceRecorder();
    void recordStackForAllThreads(bool recordAllThreads, thread_t mainMachThread, thread_t etTraceThread);

    std::vector<ThreadSummary> collectThreadSummaries();
};
