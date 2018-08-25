import { SparqlQueryResult } from './sparql-models';
import { Observable } from 'rxjs';
import { InjectionToken } from '@angular/core';

export interface ISparqlService {

  readonly currentResult: Observable<SparqlQueryResult>;

  executeQuery(queryExpr: string);

}

export let ISparqlServiceInjectionToken = new InjectionToken<ISparqlService>('DI.ISparqlService');

export function ParseQueryResult(rawResult: string) : SparqlQueryResult
{
    var result = new SparqlQueryResult();
    return result;
}
