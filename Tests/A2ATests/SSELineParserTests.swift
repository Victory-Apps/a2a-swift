import Testing
@testable import A2A

@Suite("SSELineParser")
struct SSELineParserTests {

    @Test func parsesDataField() {
        var parser = SSELineParser()
        let field = parser.parse(line: "data: {\"hello\":\"world\"}")
        #expect(field == .data("{\"hello\":\"world\"}"))
    }

    @Test func parsesDataFieldNoSpace() {
        var parser = SSELineParser()
        let field = parser.parse(line: "data:{\"hello\":\"world\"}")
        #expect(field == .data("{\"hello\":\"world\"}"))
    }

    @Test func parsesEmptyDataField() {
        var parser = SSELineParser()
        let field = parser.parse(line: "data:")
        #expect(field == .data(""))
    }

    @Test func parsesIdField() {
        var parser = SSELineParser()
        let field = parser.parse(line: "id: 42")
        #expect(field == .id("42"))
        #expect(parser.lastEventId == "42")
    }

    @Test func tracksLastEventId() {
        var parser = SSELineParser()
        _ = parser.parse(line: "id: 1")
        _ = parser.parse(line: "id: 2")
        _ = parser.parse(line: "id: 3")
        #expect(parser.lastEventId == "3")
    }

    @Test func parsesRetryField() {
        var parser = SSELineParser()
        let field = parser.parse(line: "retry: 3000")
        #expect(field == .retry(3000))
        #expect(parser.serverRetryInterval == 3.0)
    }

    @Test func parsesRetryFieldUpdatesInterval() {
        var parser = SSELineParser()
        _ = parser.parse(line: "retry: 1000")
        #expect(parser.serverRetryInterval == 1.0)
        _ = parser.parse(line: "retry: 5000")
        #expect(parser.serverRetryInterval == 5.0)
    }

    @Test func invalidRetryTreatedAsComment() {
        var parser = SSELineParser()
        let field = parser.parse(line: "retry: abc")
        #expect(field == .comment)
        #expect(parser.serverRetryInterval == nil)
    }

    @Test func parsesEventField() {
        var parser = SSELineParser()
        let field = parser.parse(line: "event: message")
        #expect(field == .event("message"))
    }

    @Test func parsesComment() {
        var parser = SSELineParser()
        let field = parser.parse(line: ": this is a comment")
        #expect(field == .comment)
    }

    @Test func parsesEmptyLine() {
        var parser = SSELineParser()
        let field = parser.parse(line: "")
        #expect(field == .empty)
    }

    @Test func parsesWhitespaceOnlyLine() {
        var parser = SSELineParser()
        let field = parser.parse(line: "   ")
        #expect(field == .empty)
    }

    @Test func unknownFieldTreatedAsComment() {
        var parser = SSELineParser()
        let field = parser.parse(line: "unknown: value")
        #expect(field == .comment)
    }

    @Test func initialStateIsNil() {
        let parser = SSELineParser()
        #expect(parser.lastEventId == nil)
        #expect(parser.serverRetryInterval == nil)
    }
}
