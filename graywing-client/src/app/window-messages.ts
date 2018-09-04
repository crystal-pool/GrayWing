// Used with window.postMessage

export interface ISetCodeEditorContentMessage {
    type: "SetCodeEditorContent";
    content: string;
}

export interface IApplicationReadyMessage {
    type: "ApplicationReady";
}
