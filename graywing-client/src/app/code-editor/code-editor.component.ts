import { Component, OnInit, Inject } from '@angular/core';
import { SparqlService } from '../sparql.service';
import { ISparqlService, ISparqlServiceInjectionToken } from '../sparql.service.contract';

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
  }

  public onExecuteClick() {
    this.sparqlService.executeQuery(this.codeContent);
  }

}
