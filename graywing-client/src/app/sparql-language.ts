export const languageId = "sparql";

export const extensionPoint: monaco.languages.ILanguageExtensionPoint = {
    id: "sparql",
    aliases: ["SPARQL"]
};

export const config: monaco.languages.LanguageConfiguration = {
    comments: {
        lineComment: "#",
    },
    brackets: [
        ["{", "}"],
        ["[", "]"],
        ["(", ")"],
    ],
    autoClosingPairs: [
        { open: "{", close: "}" },
        { open: "[", close: "]" },
        { open: "(", close: ")" },
        { open: "\"", close: "\"", notIn: ["string"] },
        { open: "'", close: "'", notIn: ["string"] },
    ],
    surroundingPairs: [
        { open: "{", close: "}" },
        { open: "[", close: "]" },
        { open: "(", close: ")" },
        { open: "\"", close: "\"" },
        { open: "'", close: "'" },
    ]
};

export const language = {
    defaultToken: "invalid",
    tokenPostfix: ".sparql",
    ignoreCase: true,
    keywords: [
        "BASE", "SELECT", "ORDER", "BY", "FROM", "GRAPH", "STR", "isURI", "PREFIX",
        "CONSTRUCT", "LIMIT", "FROM", "NAMED", "OPTIONAL", "LANG", "isIRI", "DESCRIBE", "OFFSET",
        "WHERE", "UNION", "LANGMATCHES", "isLITERAL", "ASK", "DISTINCT", "FILTER", "DATATYPE",
        "REGEX", "REDUCED", "BOUND", "true", "sameTERM", "false", "a"
    ],
    brackets: [
        ["(", ")", "delimiter.parenthesis"],
        ["{", "}", "delimiter.curly"],
        ["[", "]", "delimiter.square"]
    ],
    escapes: /\\[tbnrf\\"']/,
    tokenizer: {
        root: [
            { include: "@whitespace" },
            [/[{}()\[\]]/, "@brackets"],
            { include: "@IRI_REF" },
            { include: "@VAR" },
            { include: "@PNAME_LN" },
            { include: "@NumericLiteral" },
            [/[\w_$]+/, {
                cases: {
                    "@keywords": "keyword",
                    "@default": "identifier"
                }
            }],
            [/[;,.]/, "delimiter"],
            // Strings
            [/("""|''')/, { token: "string.delim", bracket: "@open", next: "@mstring.$1" }],
            [/"([^"\\]|\\.)*$/, "string.invalid"],  // non-teminated string
            [/'([^'\\]|\\.)*$/, "string.invalid"],  // non-teminated string
            [/(["'])/, { token: "string.delim", bracket: "@open", next: "@string.$1" }],
        ],
        whitespace: [
            [/\s+/, "white"],
            [/#.*$/, "comment"]
        ],
        IRI_REF: [[/<([^<>"{}|^`\[\u0000-\u0020])*>/, "constant.uri"]],
        VAR: [[/[\?\$][\w\d_]+/, "variable"]],
        PNAME_NS: [[/[\w\d]([\w\d\._]*[\w\d_])?:/, "identifier.PNAME_NS"]],
        PNAME_LN: [[/[\w\d]([\w\d\._]*[\w\d_])?:[\w\d]([\w\d\._]*[\w\d_])?/, "identifier.PNAME_LN"]],
        NumericLiteral: [
            [/[+-]?\d+/, "number"],
            [/[+-]?(\d+\.\d*|\.\d+)/, "number.float"],
            [/[+-]?(\d+\.?\d*|\.\d+)[Ee][+-]?\d+/, "number.float"],
        ],
        // Regular strings
        string: [
            { include: "@strcontent" },
            [/["']/, {
                cases: {
                    "$#==$S2": { token: "string.delim", bracket: "@close", next: "@pop" },
                    "@default": { token: "string" }
                }
            }],
            [/./, "string.invalid"],
        ],
        mstring: [
            { include: "@strcontent" },
            [/"""|'''/, {
                cases: {
                    "$#==$S2": { token: "string.delim", bracket: "@close", next: "@pop" },
                    "@default": { token: "string" }
                }
            }],
            [/["']/, "string"],
            [/./, "string.invalid"],
        ],
        strcontent: [
            [/[^\\"']+/, "string"],
            [/\\$/, "string.escape"],
            [/@escapes/, "string.escape"],
            [/\\./, "string.escape.invalid"],
        ],
    }
};

export function register() {
    monaco.languages.register(extensionPoint);
    monaco.languages.setLanguageConfiguration(languageId, config);
    monaco.languages.setMonarchTokensProvider(languageId, <monaco.languages.IMonarchLanguage><any>language);
}
