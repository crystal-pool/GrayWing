import { Component, OnInit, Inject, Input } from '@angular/core';
import { ISparqlService, ISparqlServiceInjectionToken } from '../sparql.service.contract';

interface ISetCodeEditorContentMessage
{
  type: "SetCodeEditorContent";
  content: string;
}

@Component({
  selector: 'app-code-editor',
  templateUrl: './code-editor.component.html',
  styleUrls: ['./code-editor.component.css']
})
export class CodeEditorComponent implements OnInit {

  public codeContent: string = `
SELECT ?cat WHERE {
  ?cat    wdt:P3      wd:Q622;       # should be fictional cat character
          wdt:P76     wd:Q627.       # should belong to ThunderClan
}`;

  public constructor(@Inject(ISparqlServiceInjectionToken) private sparqlService: ISparqlService) { }

  public ngOnInit() {
    window.addEventListener("message", e => {
      if (!e.data) return;
      if (e.data.type === "SetCodeEditorContent")
      {
        this.codeContent = (<ISetCodeEditorContentMessage>e.data).content;
      }
    });
  }

  public onExecuteClick() {
    this.sparqlService.executeQuery(this.codeContent);
  }

}
