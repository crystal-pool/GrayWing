export class SparqlQueryResult {

    public static readonly Empty: SparqlQueryResult = new SparqlQueryResult();

    public variables: string[];

    public resultBoolean?: boolean;

    public records: SparqlQueryRecord[];

}

/**
 * This is actually a `<result>` node of the SPARQL query result.
 * Used "record" here to distinguish a single result from the whole SPARQL query results.
 */
export class SparqlQueryRecord {
    public constructor(public readonly bindings: { [name: string]: SparqlVariableBindingValue }) {

    }
}


export class SparqlUri {

    public constructor(public readonly value: string) {

    }

    public toString() {
        return this.value;
    }

}

export class SparqlLiteral {

    public constructor(public readonly value: string, public readonly language?: string, public readonly dataType?: string) {

    }

    public toString() {
        let s = this.value;
        if (this.language) { s = s + "@" + this.language; }
        if (this.dataType) { s = s + "^^" + this.dataType; }
        return s;
    }

}

export class SparqlBlankNode {

    public constructor(public readonly name: string) {

    }

    public toString() {
        return "_:" + name;
    }

}

export type SparqlVariableBindingValue = SparqlUri | SparqlLiteral | SparqlBlankNode;
