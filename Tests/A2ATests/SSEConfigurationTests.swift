import Testing
import Foundation
@testable import A2A

@Suite("SSEConfiguration")
struct SSEConfigurationTests {

    @Test func defaultConfiguration() {
        let config = SSEConfiguration.default
        #expect(config.maxRetries == 3)
        #expect(config.initialRetryInterval == 1.0)
        #expect(config.maxRetryInterval == 30.0)
        #expect(config.backoffMultiplier == 2.0)
        #expect(config.jitterFraction == 0.1)
    }

    @Test func disabledConfiguration() {
        let config = SSEConfiguration.disabled
        #expect(config.maxRetries == 0)
    }

    @Test func delayExponentialBackoff() {
        let config = SSEConfiguration(
            initialRetryInterval: 1.0,
            maxRetryInterval: 30.0,
            backoffMultiplier: 2.0,
            jitterFraction: 0.0 // No jitter for deterministic testing
        )

        let delay0 = config.delay(forAttempt: 0)
        #expect(delay0 == 1.0) // 1.0 * 2^0 = 1.0

        let delay1 = config.delay(forAttempt: 1)
        #expect(delay1 == 2.0) // 1.0 * 2^1 = 2.0

        let delay2 = config.delay(forAttempt: 2)
        #expect(delay2 == 4.0) // 1.0 * 2^2 = 4.0
    }

    @Test func delayClampsToMax() {
        let config = SSEConfiguration(
            initialRetryInterval: 1.0,
            maxRetryInterval: 5.0,
            backoffMultiplier: 2.0,
            jitterFraction: 0.0
        )

        let delay10 = config.delay(forAttempt: 10)
        #expect(delay10 == 5.0) // Clamped to maxRetryInterval
    }

    @Test func delayWithJitterInRange() {
        let config = SSEConfiguration(
            initialRetryInterval: 10.0,
            maxRetryInterval: 30.0,
            backoffMultiplier: 1.0,
            jitterFraction: 0.1
        )

        // With jitter=0.1, delay should be in range [9.0, 11.0]
        for _ in 0..<100 {
            let delay = config.delay(forAttempt: 0)
            #expect(delay >= 9.0)
            #expect(delay <= 11.0)
        }
    }

    @Test func equatable() {
        #expect(SSEConfiguration.default == SSEConfiguration())
        #expect(SSEConfiguration.default != SSEConfiguration.disabled)
    }
}
