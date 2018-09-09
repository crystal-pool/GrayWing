import { Injectable } from "@angular/core";
import { SparqlQueryResult } from "./sparql-models";
import { BehaviorSubject } from "rxjs";
import { HttpClient } from "@angular/common/http";
import { ISparqlService, ParseQueryResult, ISparqlQueryStatus } from "./sparql.service.contract";

@Injectable({
  providedIn: "root"
})
export class SparqlService implements ISparqlService {

  public constructor(private http: HttpClient) { }

  public readonly currentResult: BehaviorSubject<SparqlQueryResult> = new BehaviorSubject<SparqlQueryResult>(SparqlQueryResult.Empty);
  public readonly currentStatus: BehaviorSubject<ISparqlQueryStatus> = new BehaviorSubject<ISparqlQueryStatus>({});

  public executeQuery(queryExpr: string) {
    this.currentStatus.next({ status: "busy" });
    this.http.post("/sparql", queryExpr, { headers: { "Content-Type": "text/plain; charset=UTF-8" }, responseType: "text" }).subscribe(
      value => {
        try {
          this.currentStatus.next({ status: "successful" });
          this.currentResult.next(ParseQueryResult(value));
        } catch (error) {
          this.currentStatus.next({ status: "failed", message: error.toString() });
        }
      },
      error => { this.currentStatus.next({ status: "failed", message: error.error || error.message || error.toString() }); }
    );
  }

}

