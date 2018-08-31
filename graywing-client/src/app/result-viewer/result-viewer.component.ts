import { Component, OnInit, Input, Inject, OnDestroy, ViewChild, TemplateRef } from '@angular/core';
import { TableColumn } from '@swimlane/ngx-datatable';
import { SparqlQueryResult } from '../sparql-models';
import { ISparqlServiceInjectionToken, ISparqlService } from '../sparql.service.contract';
import { Subscription } from 'rxjs';

@Component({
  selector: 'app-result-viewer',
  templateUrl: './result-viewer.component.html',
  styleUrls: ['./result-viewer.component.css']
})
export class ResultViewerComponent implements OnInit, OnDestroy {

  private _sparqlResult: SparqlQueryResult;
  private sparqlResultSubscription: Subscription;

  public constructor(@Inject(ISparqlServiceInjectionToken) private sparqlService: ISparqlService) { }

  @ViewChild('variableValueCellTemplate') public variableValueCellTemplate: TemplateRef<any>;

  public rows: any[];

  public columns: TableColumn[];

  get sparqlResult() { return this._sparqlResult; }

  set sparqlResult(value: SparqlQueryResult) {
    value = value || SparqlQueryResult.Empty;
    this._sparqlResult = value;
    if (!this._sparqlResult.records) {
      this.rows = [];
      this.columns = [];
    } else {
      this.columns = value.variables.map((varName): TableColumn => {
        return { name: varName, prop: "bindings." + varName, cellTemplate: this.variableValueCellTemplate };
      })
      this.rows = value.records;
    }
  }

  public ngOnInit() {
    this.sparqlResultSubscription = this.sparqlService.currentResult.subscribe(value => { this.sparqlResult = value; });
  }

  ngOnDestroy(): void {
    this.sparqlResultSubscription.unsubscribe();
  }

}
