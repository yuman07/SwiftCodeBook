//
//  XMLNodeParserTests.swift
//  SwiftCodeBookTests
//
//  Unit tests for: SwiftCodeBook/Source/Tools/Foundation/XMLNodeParser.swift
//  Covers XMLNode (value type / Hashable / Sendable) and
//  XMLNodeParser.parseXML(from:) across the .string / .data / .url data
//  sources, including happy paths, structure/attributes/text, entities,
//  unicode, error branches (malformed XML, multiple roots, bad URL),
//  large inputs, and concurrent parsing.
//

import Testing
import Foundation
@testable import SwiftCodeBook

@Suite struct XMLNodeParserTests {

    // MARK: - Helpers

    /// Creates a unique temporary directory for file-based tests and removes it on deinit.
    private final class TempDir {
        let url: URL
        init() {
            url = FileManager.default.temporaryDirectory
                .appendingPathComponent("XMLNodeParserTests-\(UUID().uuidString)", isDirectory: true)
            try? FileManager.default.createDirectory(at: url, withIntermediateDirectories: true)
        }
        deinit {
            try? FileManager.default.removeItem(at: url)
        }
        func write(_ contents: String, name: String = "doc.xml") throws -> URL {
            let fileURL = url.appendingPathComponent(name)
            try Data(contents.utf8).write(to: fileURL)
            return fileURL
        }
    }

    /// Parses an XML string via the .string data source.
    private static func parse(_ xml: String) async throws -> XMLNode {
        try await XMLNodeParser.parseXML(from: .string(xml))
    }

    // MARK: - XMLNode value semantics

    @Test func xmlNodeStoresAllProvidedValues() {
        let child = XMLNode(name: "child", attributes: ["k": "v"], text: ["t"], childNodes: [])
        let node = XMLNode(name: "root", attributes: ["a": "1", "b": "2"], text: ["x", "y"], childNodes: [child])
        #expect(node.name == "root")
        #expect(node.attributes == ["a": "1", "b": "2"])
        #expect(node.text == ["x", "y"])
        #expect(node.childNodes.count == 1)
        #expect(node.childNodes[0] == child)
    }

    @Test func xmlNodeSupportsEmptyValues() {
        let node = XMLNode(name: "", attributes: [:], text: [], childNodes: [])
        #expect(node.name.isEmpty)
        #expect(node.attributes.isEmpty)
        #expect(node.text.isEmpty)
        #expect(node.childNodes.isEmpty)
    }

    @Test func xmlNodeHashableEquality() {
        let a = XMLNode(name: "n", attributes: ["x": "1"], text: ["hi"], childNodes: [])
        let b = XMLNode(name: "n", attributes: ["x": "1"], text: ["hi"], childNodes: [])
        let c = XMLNode(name: "n", attributes: ["x": "2"], text: ["hi"], childNodes: [])
        #expect(a == b)
        #expect(a != c)
        #expect(a.hashValue == b.hashValue)
        let set: Set<XMLNode> = [a, b, c]
        #expect(set.count == 2) // a == b collapse into one
    }

    @Test func xmlNodeEqualityIsDeepOverChildren() {
        let leaf1 = XMLNode(name: "leaf", attributes: [:], text: ["v"], childNodes: [])
        let leaf2 = XMLNode(name: "leaf", attributes: [:], text: ["DIFFERENT"], childNodes: [])
        let parentA = XMLNode(name: "p", attributes: [:], text: [], childNodes: [leaf1])
        let parentB = XMLNode(name: "p", attributes: [:], text: [], childNodes: [leaf2])
        #expect(parentA != parentB)
    }

    // MARK: - DataSource cases produce identical results

    @Test func allDataSourcesProduceSameNode() async throws {
        let xml = "<root attr=\"v\">hello</root>"
        let temp = TempDir()
        let fileURL = try temp.write(xml)

        let fromString = try await XMLNodeParser.parseXML(from: .string(xml))
        let fromData = try await XMLNodeParser.parseXML(from: .data(Data(xml.utf8)))
        let fromURL = try await XMLNodeParser.parseXML(from: .url(fileURL))

        #expect(fromString == fromData)
        #expect(fromString == fromURL)
        #expect(fromString.name == "root")
        #expect(fromString.attributes == ["attr": "v"])
        #expect(fromString.text == ["hello"])
    }

    // MARK: - Happy paths: structure

    @Test func parsesSimpleRootWithText() async throws {
        let node = try await Self.parse("<root>hello</root>")
        #expect(node.name == "root")
        #expect(node.attributes.isEmpty)
        #expect(node.text == ["hello"])
        #expect(node.childNodes.isEmpty)
    }

    @Test func parsesSelfClosingElementHasNoTextOrChildren() async throws {
        let node = try await Self.parse("<root/>")
        #expect(node.name == "root")
        #expect(node.text.isEmpty)
        #expect(node.childNodes.isEmpty)
        #expect(node.attributes.isEmpty)
    }

    @Test func parsesAttributes() async throws {
        let node = try await Self.parse("<root a=\"1\" b=\"two\" c=\"\"/>")
        #expect(node.attributes == ["a": "1", "b": "two", "c": ""])
    }

    @Test func parsesNestedChildren() async throws {
        let node = try await Self.parse("<root><a>1</a><b>2</b></root>")
        #expect(node.name == "root")
        #expect(node.childNodes.count == 2)
        let a = try #require(node.childNodes.first { $0.name == "a" })
        let b = try #require(node.childNodes.first { $0.name == "b" })
        #expect(a.text == ["1"])
        #expect(b.text == ["2"])
        // Children should preserve document order.
        #expect(node.childNodes.map(\.name) == ["a", "b"])
    }

    @Test func parsesDeeplyNestedStructurePreservesHierarchy() async throws {
        let node = try await Self.parse("<a><b><c><d>deep</d></c></b></a>")
        let b = try #require(node.childNodes.first)
        #expect(b.name == "b")
        let c = try #require(b.childNodes.first)
        #expect(c.name == "c")
        let d = try #require(c.childNodes.first)
        #expect(d.name == "d")
        #expect(d.text == ["deep"])
    }

    @Test func ignoresXMLDeclaration() async throws {
        let node = try await Self.parse("<?xml version=\"1.0\" encoding=\"UTF-8\"?><root>x</root>")
        #expect(node.name == "root")
        #expect(node.text == ["x"])
    }

    @Test func allowsTrailingCommentAfterRoot() async throws {
        // A trailing comment after the root element is valid XML and does not
        // produce a second root.
        let node = try await Self.parse("<root>a</root><!-- trailing -->")
        #expect(node.name == "root")
        #expect(node.text == ["a"])
    }

    // MARK: - Text handling

    @Test func mixedTextAndElementsCollectsTextChunksOnParent() async throws {
        // foundCharacters fires for each text run around the inline element.
        let node = try await Self.parse("<root>a<b/>c</root>")
        #expect(node.text == ["a", "c"])
        #expect(node.childNodes.count == 1)
        #expect(node.childNodes[0].name == "b")
    }

    @Test func entitiesAreDecodedIntoSeparateTextChunks() async throws {
        // &lt; &amp; &gt; each surface as their own foundCharacters callback,
        // so they accumulate as separate text entries (joined == "<&>").
        let node = try await Self.parse("<root>&lt;&amp;&gt;</root>")
        #expect(node.text.joined() == "<&>")
    }

    @Test func whitespaceBetweenElementsIsCapturedAsParentText() async throws {
        // The newlines/indentation between child elements become text on root.
        let node = try await Self.parse("<root>\n  <child>x</child>\n</root>")
        #expect(node.childNodes.count == 1)
        #expect(node.childNodes[0].name == "child")
        #expect(node.childNodes[0].text == ["x"])
        // Root collects the surrounding whitespace as text.
        #expect(!node.text.isEmpty)
        #expect(node.text.joined().allSatisfy { $0.isWhitespace })
    }

    @Test func cdataIsNotCapturedAsText() async throws {
        // The parser implements foundCharacters but NOT foundCDATA, so CDATA
        // content is dropped entirely.
        let node = try await Self.parse("<root><![CDATA[<not parsed & ignored>]]></root>")
        #expect(node.name == "root")
        #expect(node.text.isEmpty)
        #expect(node.childNodes.isEmpty)
    }

    @Test func unicodeAndEmojiTextRoundTripsViaJoin() async throws {
        // Multi-byte UTF-8 may be split across multiple foundCharacters chunks,
        // so assert on the joined string rather than chunk count.
        let payload = "café 🎉 naïve Ωmega 日本語 \u{1F600}"
        let node = try await Self.parse("<root>\(payload)</root>")
        #expect(node.text.joined() == payload)
    }

    @Test func pureAsciiTextStaysSingleChunk() async throws {
        let node = try await Self.parse("<root>plain ascii text 123</root>")
        #expect(node.text == ["plain ascii text 123"])
    }

    // MARK: - Attribute ordering robustness

    @Test(arguments: [
        "<r x=\"1\" y=\"2\" z=\"3\"/>",
        "<r z=\"3\" y=\"2\" x=\"1\"/>",
    ])
    func attributeDictionaryIsOrderIndependent(xml: String) async throws {
        let node = try await Self.parse(xml)
        #expect(node.attributes == ["x": "1", "y": "2", "z": "3"])
    }

    // MARK: - Error branches

    @Test func throwsOnMalformedXML() async throws {
        await #expect(throws: (any Error).self) {
            try await Self.parse("this is not xml")
        }
    }

    @Test func throwsOnEmptyDocument() async throws {
        await #expect(throws: (any Error).self) {
            try await Self.parse("")
        }
    }

    @Test func throwsOnWhitespaceOnlyDocument() async throws {
        await #expect(throws: (any Error).self) {
            try await Self.parse("    \n   ")
        }
    }

    @Test func throwsOnMismatchedTags() async throws {
        await #expect(throws: (any Error).self) {
            try await Self.parse("<a></b>")
        }
    }

    @Test func throwsOnUnclosedTag() async throws {
        await #expect(throws: (any Error).self) {
            try await Self.parse("<root>")
        }
    }

    @Test func throwsOnMultipleRootElements() async throws {
        // Two sibling roots: XMLParser reports "Extra content at the end" before
        // parserDidEndDocument is reached, so an error is thrown.
        await #expect(throws: (any Error).self) {
            try await Self.parse("<a/><b/>")
        }
    }

    @Test func malformedErrorIsInNSXMLParserErrorDomain() async throws {
        do {
            _ = try await Self.parse("not xml at all")
            Issue.record("Expected parsing to throw")
        } catch {
            let nsError = error as NSError
            #expect(nsError.domain == XMLParser.errorDomain)
        }
    }

    @Test func throwsForNonexistentFileURL() async throws {
        let temp = TempDir()
        let missing = temp.url.appendingPathComponent("does-not-exist.xml")
        await #expect(throws: (any Error).self) {
            try await XMLNodeParser.parseXML(from: .url(missing))
        }
    }

    @Test func throwsForDirectoryURL() async throws {
        let temp = TempDir()
        await #expect(throws: (any Error).self) {
            try await XMLNodeParser.parseXML(from: .url(temp.url))
        }
    }

    @Test func parsesValidFileURL() async throws {
        let temp = TempDir()
        let xml = "<config version=\"2\"><item id=\"a\">first</item><item id=\"b\">second</item></config>"
        let fileURL = try temp.write(xml, name: "config.xml")
        let node = try await XMLNodeParser.parseXML(from: .url(fileURL))
        #expect(node.name == "config")
        #expect(node.attributes == ["version": "2"])
        #expect(node.childNodes.count == 2)
        #expect(node.childNodes.map { $0.attributes["id"] } == ["a", "b"])
        #expect(node.childNodes.map { $0.text } == [["first"], ["second"]])
    }

    // MARK: - Empty Data source

    @Test func throwsForEmptyData() async throws {
        await #expect(throws: (any Error).self) {
            try await XMLNodeParser.parseXML(from: .data(Data()))
        }
    }

    // MARK: - Large / wide / deep inputs (time bounded)

    @Test func parsesManySiblingChildren() async throws {
        let count = 20_000
        var builder = "<root>"
        builder.reserveCapacity(count * 24)
        for i in 0..<count {
            builder += "<item>\(i)</item>"
        }
        builder += "</root>"
        let node = try await Self.parse(builder)
        #expect(node.name == "root")
        #expect(node.childNodes.count == count)
        // Spot check first and last preserve order and text.
        #expect(node.childNodes.first?.text == ["0"])
        #expect(node.childNodes.last?.text == ["\(count - 1)"])
    }

    @Test func parsesDeeplyNestedChain() async throws {
        // A deep (but bounded) nesting chain: <n0><n1>...<n499/>...</n1></n0>
        let depth = 500
        var open = ""
        var close = ""
        for i in 0..<depth {
            open += "<n\(i)>"
            close = "</n\(i)>" + close
        }
        let node = try await Self.parse(open + close)
        var current: XMLNode? = node
        var level = 0
        while let c = current, !c.childNodes.isEmpty {
            #expect(c.name == "n\(level)")
            current = c.childNodes.first
            level += 1
        }
        #expect(level == depth - 1)
        #expect(current?.name == "n\(depth - 1)")
    }

    @Test func parsesLongTextPayload() async throws {
        let big = String(repeating: "A", count: 200_000)
        let node = try await Self.parse("<root>\(big)</root>")
        #expect(node.text.joined() == big)
        #expect(node.text.joined().count == 200_000)
    }

    // MARK: - Concurrency

    @Test func concurrentParsingOfManyDocumentsIsCorrect() async throws {
        let total = 300
        let results = try await withThrowingTaskGroup(of: (Int, XMLNode).self) { group in
            for i in 0..<total {
                group.addTask {
                    let xml = "<doc index=\"\(i)\"><payload>value-\(i)</payload></doc>"
                    let node = try await XMLNodeParser.parseXML(from: .string(xml))
                    return (i, node)
                }
            }
            var collected = [Int: XMLNode]()
            for try await (i, node) in group {
                collected[i] = node
            }
            return collected
        }

        #expect(results.count == total)
        for i in 0..<total {
            let node = try #require(results[i])
            #expect(node.name == "doc")
            #expect(node.attributes["index"] == "\(i)")
            #expect(node.childNodes.count == 1)
            #expect(node.childNodes[0].name == "payload")
            #expect(node.childNodes[0].text == ["value-\(i)"])
        }
    }

    @Test func concurrentParsingMixOfValidAndInvalidDocuments() async throws {
        let total = 200
        struct Outcome: Sendable { let index: Int; let succeeded: Bool }
        let outcomes = await withTaskGroup(of: Outcome.self) { group in
            for i in 0..<total {
                group.addTask {
                    let xml = i.isMultiple(of: 2) ? "<ok>\(i)</ok>" : "<broken"
                    do {
                        _ = try await XMLNodeParser.parseXML(from: .string(xml))
                        return Outcome(index: i, succeeded: true)
                    } catch {
                        return Outcome(index: i, succeeded: false)
                    }
                }
            }
            var all = [Outcome]()
            for await o in group { all.append(o) }
            return all
        }

        #expect(outcomes.count == total)
        for o in outcomes {
            #expect(o.succeeded == o.index.isMultiple(of: 2))
        }
    }

    @Test func repeatedParsingOfSameInputIsDeterministic() async throws {
        let xml = "<root a=\"1\"><c>x</c><c>y</c></root>"
        let first = try await Self.parse(xml)
        for _ in 0..<25 {
            let again = try await Self.parse(xml)
            #expect(again == first)
        }
    }
}
