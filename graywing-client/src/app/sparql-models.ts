export class SparqlQueryResult {

    public variables: string[];

    public results;

}

export class SparqlQueryResultItem {
    public bindings: { [name: string]: SparqlVariableBindingValue }
}


export class SparqlUri {

    public value: string;

}

export class SparqlLiteral {

    public value: string;

    public language?: string;

    public dateType?: string;

}

export class SparqlBlankNode {

    public name: string;

}

export type SparqlVariableBindingValue = SparqlUri | SparqlLiteral | SparqlBlankNode;
