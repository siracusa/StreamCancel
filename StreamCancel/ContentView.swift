//
//  ContentView.swift
//  StreamCancel
//
//  Created by John Siracusa on 12/11/24.
//

import SwiftUI

struct ContentView: View {
    @State var consumer : Consumer
    @State var isRunning = false

    var body: some View {
        VStack {
            if !isRunning {
                Button("Start") {
                    isRunning = true

                    Task {
                        await consumer.start()
                    }
                }
            }
            else {
                Button("Stop") {
                    isRunning = false
                    consumer.stop()
                }
            }
        }
        .padding()
    }
}

actor Producer {
    var stream : AsyncStream<Int>.Continuation?
    var streamTask : Task<Void, Never>?

    func start() -> AsyncStream<Int> {
        return AsyncStream<Int>(bufferingPolicy: .bufferingNewest(1)) { continuation in
            self.stream = continuation

            // WORKING:

            //let task = Task {
            //    await self.doWork()
            //    continuation.finish()
            //}
            //
            //self.streamTask = task
            //
            //continuation.onTermination = { reason in
            //    print("Terminated: \(reason)")
            //    task.cancel()
            //}

            // NOT WORKING:

            //self.streamTask = Task {
            //    await self.doWork()
            //    continuation.finish()
            //}
            //
            //continuation.onTermination = { reason in
            //    print("Terminated: \(reason)")
            //    // ERROR: Actor-isolated property 'streamTask' can not be referenced from a Sendable closure
            //    self.streamTask?.cancel()
            //}

            // FIX:

            self.streamTask = Task {
                await self.doWork()
                continuation.finish()
            }

            continuation.onTermination = { [streamTask] reason in
                print("Terminated: \(reason)")
                streamTask?.cancel()
            }

            // Explanation from Dimitri Bouniol as to why adding a [streamTask]
            // capture to the NOT WORKING code, changing it to the FIX code
            // fixes it:
            //
            // continuation.onTermination = { [streamTask] reason in ... }
            //
            // Dimitri: From a safety perspective, you copy self.streamTask into
            // immutable storage before entering the closure that can run anywhere.
            // This means that even if you change the task, the memory that composes
            // where that task lives will never be in an inconsistent state.
            //
            // (You can access self.streamTask within that closure too if you made a
            // helper function to retrieve the current task, but the compiler would
            // force you to call that function with await at that point, essentially
            // placing a lock on that actor to access it safely.)
            //
            // (Note that unlike Objective-C’s default, a capture list in Swift makes
            // an explicit copy rather than a reference.)
            //
            // John: Ah ha, I think that's the bit of info I was missing! Though it
            // does seem weird that it can make a full copy of the thing and then still
            // do things with it that affect the thing that was copied! Task is a
            // struct and therefore a value type, right?
            //
            // Dimitri: In that regard, I would think of Task as a thread-safe
            // reference type. It will always refer to the same internal “Task”, though
            // making a copy of the struct will copy the internal pointer, if you want
            // to think of it that way.
            //
            // Tasks in that regard are stateless. They just point to the work that has
            // already started, allowing you to cancel it or await its results.
            //
            // In a sense, it’s the same copy-on-write pattern [as Array, String, etc.],
            // but you can’t write, so a copy never happens.
        }
    }

    func doWork() async {
        for i in 1...100_000 {
            if self.streamTask?.isCancelled ?? false {
                print("doWork: detected cancel")
                break
            }

            print("Yield: \(i)")
            self.stream?.yield(i)

            do {
                try await Task.sleep(for: .seconds(1))
            }
            catch {
                print("Caught: \(error)")
            }
        }

        print("doWork: ended")
    }
}

@MainActor class Consumer {
    var producer : Producer
    var cancel = false

    func start() async {
        let producer = self.producer

        let stream = await producer.start()

        for try await state in stream {
            if self.cancel {
                break
            }

            print("Consumed: \(state)")
        }

        print("Producer: done")
    }

    func stop() {
        self.cancel = true
    }

    init() {
        self.producer = Producer()
    }
}
