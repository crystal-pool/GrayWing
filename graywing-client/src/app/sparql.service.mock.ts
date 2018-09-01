import { Injectable } from '@angular/core';
import { SparqlQueryResult } from './sparql-models';
import { BehaviorSubject, Observable } from 'rxjs';
import { HttpClient } from '@angular/common/http';
import { ISparqlService, ParseQueryResult, ISparqlQueryStatus } from './sparql.service.contract';
import { delay } from 'rxjs/operators';

@Injectable({
  providedIn: 'root'
})
export class SparqlMockService implements ISparqlService {

  constructor(private http: HttpClient) { }

  public readonly currentResult: BehaviorSubject<SparqlQueryResult> = new BehaviorSubject<SparqlQueryResult>(null);
  public readonly currentStatus: BehaviorSubject<ISparqlQueryStatus> = new BehaviorSubject<ISparqlQueryStatus>({});

  public executeQuery(queryExpr: string) {
    let delayedAction = () => {
      this.currentStatus.next({ status: "successful" });
      this.currentResult.next(ParseQueryResult(`<sparql xmlns="http://www.w3.org/2005/sparql-results#">
      <head>
        <variable name="cat"/>
        <variable name="test"/>
      </head>
      <results>
        <result>
          <binding name="cat">
            <uri>https://crystalpool.cxuesong.com/entity/Q621#${Math.random()}</uri>
          </binding>
        </result>
        <result>
          <binding name="cat">
            <uri>https://crystalpool.cxuesong.com/entity/Q711</uri>
          </binding>
        </result>
        <result>
          <binding name="cat">
            <uri>https://crystalpool.cxuesong.com/entity/Q712</uri>
          </binding>
        </result>
        <result>
          <binding name="cat">
            <uri>https://crystalpool.cxuesong.com/entity/Q713</uri>
          </binding>
        </result>
        <result>
          <binding name="cat">
            <literal>literal</literal>
          </binding>
        </result>
        <result>
          <binding name="cat">
            <bnode>blank</bnode>
          </binding>
        </result>
        </results></sparql>
    `));
    };
    window.setTimeout(delayedAction, 1000);
    this.currentStatus.next({ status: "busy" });
  }

}

