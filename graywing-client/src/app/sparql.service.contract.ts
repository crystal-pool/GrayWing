import { SparqlQueryResult, SparqlQueryRecord, SparqlUri, SparqlLiteral, SparqlBlankNode, SparqlVariableBindingValue } from "./sparql-models";
import { Observable } from "rxjs";
import { InjectionToken } from "@angular/core";

export interface ISparqlQueryStatus {
    // undefined indicates the user hasn't executed any query yet.
    status?: "busy" | "successful" | "failed";
    message?: string;
}

export interface ISparqlService {

    readonly currentResult: Observable<SparqlQueryResult>;

    readonly currentStatus: Observable<ISparqlQueryStatus>;

    executeQuery(queryExpr: string);

}

export const ISparqlServiceInjectionToken = new InjectionToken<ISparqlService>("DI.ISparqlService");

export const SparqlResultsNamespace = "http://www.w3.org/2005/sparql-results#";

const XmlMetaNamespace = "http://www.w3.org/XML/1998/namespace";

export function ParseQueryResult(rawResult: string): SparqlQueryResult {
    const result = new SparqlQueryResult();
    const parser = new DOMParser();
    const doc = parser.parseFromString(rawResult, "text/xml");
    const root = doc.documentElement;
    const nsResolver: XPathNSResolver = {
        lookupNamespaceURI: prefix => {
            if (prefix === "r") { return SparqlResultsNamespace; }
            return null;
        }
    };
    // c.f. https://www.w3.org/2001/sw/DataAccess/rf1/
    // Get variable names.
    const variables = evaluateXPathAndMap(doc, "/r:sparql/r:head/r:variable", root, nsResolver,
        node => (node as Element).getAttribute("name"));
    result.variables = variables;
    const booleanNode = evaluateXPathAndTakeFirst(doc, "/r:sparql/r:boolean", root, nsResolver);
    if (booleanNode) {
        const value = booleanNode.textContent.trim().toLowerCase();
        switch (value) {
            case "true": result.resultBoolean = true; break;
            case "false": result.resultBoolean = false; break;
            default:
                console.warn("Cannot parse <boolean> value: " + value + ".");
                break;
        }
        return;
    }
    result.records = evaluateXPathAndMap(doc, "/r:sparql/r:results/r:result", root, nsResolver,
        node => {
            const bindings: { [key: string]: SparqlVariableBindingValue } = {};
            for (let i = 0; i < node.childNodes.length; i++) {
                const bnode = node.childNodes[i];
                if (bnode.nodeType !== Node.ELEMENT_NODE) { continue; }
                if (bnode.localName !== "binding") { continue; }
                // <binding name="variable_name">
                const belement = bnode as Element;
                const name = belement.getAttribute("name");
                const uriNode = evaluateXPathAndTakeFirst(doc, "./r:uri", bnode, nsResolver);
                if (uriNode) {
                    bindings[name] = new SparqlUri(uriNode.textContent.trim());
                    continue;
                }
                const literalNode = evaluateXPathAndTakeFirst(doc, "./r:literal", bnode, nsResolver) as Element;
                if (literalNode) {
                    bindings[name] = new SparqlLiteral(literalNode.textContent.trim(),
                        literalNode.getAttributeNS(XmlMetaNamespace, "lang"),
                        literalNode.getAttribute("datatype"));
                    continue;
                }
                const blankNode = evaluateXPathAndTakeFirst(doc, "./r:bnode", bnode, nsResolver);
                if (blankNode) {
                    bindings[name] = new SparqlBlankNode(blankNode.textContent.trim());
                    continue;
                }
                console.warn("Cannot parse result value binding.", bnode);
            }
            return new SparqlQueryRecord(bindings);
        });
    return result;
}

function evaluateXPathAndTakeFirst(doc: Document, expression: string, contextNode: Node, resolver: XPathNSResolver): Node {
    const iterator = doc.evaluate(expression, contextNode, resolver, XPathResult.FIRST_ORDERED_NODE_TYPE, null);
    return iterator.singleNodeValue;
}

function evaluateXPathAndMap<T>(doc: Document, expression: string, contextNode: Node, resolver: XPathNSResolver,
    selector: (node: Node, index: Number) => T): T[] {
    const iterator = doc.evaluate(expression, contextNode, resolver, XPathResult.ORDERED_NODE_ITERATOR_TYPE, null);
    return mapXPathResult(iterator, selector);
}

function mapXPathResult<T>(result: XPathResult, selector: (node: Node, index: Number) => T): T[] {
    let node: Node;
    const mapped: T[] = [];
    while (node = result.iterateNext()) {
        mapped.push(selector(node, mapped.length));
    }
    return mapped;
}
