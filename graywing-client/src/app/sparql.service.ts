import { Injectable } from '@angular/core';
import { SparqlQueryResult } from './sparql-models';
import { BehaviorSubject } from 'rxjs';
import { HttpClient } from '@angular/common/http';
import { ISparqlService, ParseQueryResult } from './sparql.service.contract';

@Injectable({
  providedIn: 'root'
})
export class SparqlService implements ISparqlService {

  constructor(private http: HttpClient) { }

  public readonly currentResult: BehaviorSubject<SparqlQueryResult> = new BehaviorSubject<SparqlQueryResult>(null);

  public executeQuery(queryExpr: string) {
    this.http.post("/sparql", queryExpr, { headers: { "Content-Type": "text/plain; charset=UTF-8" }, responseType: "text" }).subscribe(
      value => { this.currentResult.next(ParseQueryResult(value)); },
      error => { this.currentResult.error(error); }
    );
  }

}

