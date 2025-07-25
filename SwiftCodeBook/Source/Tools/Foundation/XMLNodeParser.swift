//
//  XMLNodeParser.swift
//  SwiftCodeBook
//
//  Created by yuman on 2025/7/25.
//

import Foundation

public struct XMLNode {
    public let name: String
    public let attributes: [String: String]
    public let text: [String]
    public let childNodes: [XMLNode]
}

public enum XMLNodeParser {
    public enum DataSource {
        case string(String)
        case data(Data)
        case url(URL)
        case stream(InputStream)
    }

    public static func parseXML(from dataSource: DataSource) async throws -> XMLNode {
        try await withUnsafeThrowingContinuation {
            let parser = XMLNodeParserImp(dataSource: dataSource)
            parser.continuation = $0
            parser.parse()
        }
    }
}

private final class XMLNodeParserImp: NSObject, @unchecked Sendable {
    struct Node {
        var name = ""
        var attributes = [String: String]()
        var text = [String]()
        var childNodes = [Node]()

        func toXMLNode() -> XMLNode {
            XMLNode(name: name, attributes: attributes, text: text, childNodes: childNodes.map { $0.toXMLNode() })
        }
    }

    var parser: XMLParser?
    var continuation: UnsafeContinuation<XMLNode, Error>?
    var stack = [Node]()

    init(dataSource: XMLNodeParser.DataSource) {
        super.init()
        switch dataSource {
        case let .string(string): parser = XMLParser(data: Data(string.utf8))
        case let .data(data): parser = XMLParser(data: data)
        case let .url(url): parser = XMLParser(contentsOf: url)
        case let .stream(inputStream): parser = XMLParser(stream: inputStream)
        }
        parser?.delegate = self
    }

    func parse() {
        guard let parser else {
            stopWithError(NSError(reason: "DataSource error: Unable to initialize parser"))
            return
        }
        parser.parse()
    }
    
    func stopWithError(_ error: Error) {
        continuation?.resume(throwing: error)
        continuation = nil
        parser?.abortParsing()
        parser = nil
        stack.removeAll()
    }
}

extension XMLNodeParserImp: XMLParserDelegate {
    func parserDidEndDocument(_ parser: XMLParser) {
        guard let root = stack.popLast(), stack.isEmpty else {
            stopWithError(NSError(reason: "Parsing error: There should be only one root node."))
            return
        }
        continuation?.resume(with: .success(root.toXMLNode()))
        continuation = nil
    }
    
    func parser(_ parser: XMLParser, didStartElement elementName: String, namespaceURI: String?, qualifiedName qName: String?, attributes attributeDict: [String: String] = [:]) {
        var newNode = Node()
        newNode.name = elementName
        newNode.attributes = attributeDict
        stack.append(newNode)
    }
    
    func parser(_ parser: XMLParser, foundCharacters string: String) {
        guard var lastNode = stack.popLast() else {
            stopWithError(NSError(reason: "Parsing error: No corresponding node was found when running foundCharacters"))
            return
        }
        lastNode.text.append(string)
        stack.append(lastNode)
    }
    
    func parser(_ parser: XMLParser, didEndElement elementName: String, namespaceURI: String?, qualifiedName qName: String?) {
        guard let lastNode = stack.popLast() else {
            stopWithError(NSError(reason: "Parsing error: No corresponding node was found when running didEndElement"))
            return
        }
        if var parentNode = stack.popLast() {
            parentNode.childNodes.append(lastNode)
            stack.append(parentNode)
        } else {
            stack.append(lastNode)
        }
    }
    
    func parser(_ parser: XMLParser, parseErrorOccurred parseError: any Error) {
        stopWithError(parseError)
    }
    
    func parser(_ parser: XMLParser, validationErrorOccurred validationError: any Error) {
        stopWithError(validationError)
    }
}

private extension NSError {
    convenience init(reason: String) {
        self.init(domain: XMLParser.errorDomain, code: XMLParser.ErrorCode.internalError.rawValue, userInfo: ["NSXMLParserErrorMessage": "\(reason)"])
    }
}
