import { Component, OnInit, Inject, Input, ViewChild } from "@angular/core";
import { ISparqlService, ISparqlServiceInjectionToken } from "../sparql.service.contract";
import { ISetCodeEditorContentMessage } from "../window-messages";
import { MonacoEditorDirective, MonacoFile } from "ngx-monaco";

@Component({
  selector: "app-code-editor",
  templateUrl: "./code-editor.component.html",
  styleUrls: ["./code-editor.component.css"]
})
export class CodeEditorComponent implements OnInit {

  public constructor(@Inject(ISparqlServiceInjectionToken) private sparqlService: ISparqlService) { }

  @ViewChild("codeEditor") public codeEditor: MonacoEditorDirective;

  public userConsented: boolean;

  public codeFile: MonacoFile = {
    content: `# Enter your SPARQL query here.
  SELECT ?cat WHERE {
    ?cat    wdt:P3      wd:Q622;       # should be fictional cat character
            wdt:P76     wd:Q627.       # should belong to ThunderClan
  }`,
    language: "sparql",
    uri: "query.sparql"
  };

  public get codeContent(): string {
    return this.codeFile.content;
  }

  public set codeContent(value: string) {
    this.codeFile.content = value;
  }

  public ngOnInit() {
    window.addEventListener("message", e => {
      if (!e.data) { return; }
      if (e.data.type === "SetCodeEditorContent") {
        this.codeContent = (<ISetCodeEditorContentMessage>e.data).content;
      }
    });
  }

  public onCodeFileChanged(newFile: MonacoFile) {
    this.codeFile.content = newFile.content;
  }

  public onExecuteClick() {
    this.sparqlService.executeQuery(this.codeContent);
    this.userConsented = true;
  }

}
