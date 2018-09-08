import { Component, OnInit, Inject, Input, ViewChild, OnDestroy } from "@angular/core";
import { ISparqlService, ISparqlServiceInjectionToken } from "../sparql.service.contract";
import { ISetCodeEditorContentMessage } from "../window-messages";

@Component({
  selector: "app-code-editor",
  templateUrl: "./code-editor.component.html",
  styleUrls: ["./code-editor.component.css"]
})
export class CodeEditorComponent implements OnInit, OnDestroy {

  public static readonly MaxAllowedBrowserHashLength = 8000;

  public constructor(@Inject(ISparqlServiceInjectionToken) private sparqlService: ISparqlService) { }

  public userConsented: boolean;

  public editorOptions = {
    language: "sparql"
  };

  public codeContent = `# Enter your SPARQL query here.
  SELECT ?cat WHERE {
    ?cat    wdt:P3      wd:Q622;       # should be fictional cat character
            wdt:P76     wd:Q627.       # should belong to ThunderClan
  }`;

  private isHashBasedCodeContentSuppressed = false;

  private loadCodeContentFromHash() {
    let content = location.hash;
    if (!content) { return false; }
    if (content.startsWith("#")) { content = content.substr(1); }
    content = decodeURIComponent(content);
    this.codeContent = content;
    return true;
  }

  private onMessage = (e: MessageEvent) => {
    if (!e.data) { return; }
    if (e.data.type === "SetCodeEditorContent") {
      this.codeContent = (<ISetCodeEditorContentMessage>e.data).content;
    }
  }

  private onHashChange = (e: HashChangeEvent) => {
    if (this.isHashBasedCodeContentSuppressed) { return; }
    this.loadCodeContentFromHash();
  }

  public ngOnInit() {
    window.addEventListener("message", this.onMessage);
    window.addEventListener("hashchange", this.onHashChange);
  }

  public ngOnDestroy(): void {
    window.removeEventListener("message", this.onMessage);
    window.removeEventListener("hashchange", this.onHashChange);
  }

  public onExecuteClick() {
    this.sparqlService.executeQuery(this.codeContent);
    if (this.codeContent.length <= CodeEditorComponent.MaxAllowedBrowserHashLength) {
      this.isHashBasedCodeContentSuppressed = true;
      location.hash = this.codeContent;
      this.isHashBasedCodeContentSuppressed = false;
    }
    this.userConsented = true;
  }

}
