import { Injectable } from '@angular/core';
import { SparqlQueryResult } from './sparql-models';
import { BehaviorSubject, Observable } from 'rxjs';
import { HttpClient } from '@angular/common/http';
import { ISparqlService, ParseQueryResult } from './sparql.service.contract';
import { delay } from 'rxjs/operators';

@Injectable({
  providedIn: 'root'
})
export class SparqlMockService implements ISparqlService {

  constructor(private http: HttpClient) { }

  private readonly currentResultDirect = new BehaviorSubject<SparqlQueryResult>(null);
  public readonly currentResult: Observable<SparqlQueryResult> = this.currentResultDirect.pipe(delay(1000));

  public executeQuery(queryExpr: string)
  {
      this.currentResultDirect.next(ParseQueryResult(`<sparql xmlns="http://www.w3.org/2005/sparql-results#">
      <head>
        <variable name="cat"/>
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
        </result></results></sparql>
    `));
  }

}

