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

            let task = Task {
                await self.doWork()
                continuation.finish()
            }

            self.streamTask = task

            continuation.onTermination = { reason in
                print("Terminated: \(reason)")
                task.cancel()
            }

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
