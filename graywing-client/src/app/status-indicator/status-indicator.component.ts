import { Component, OnInit, Inject, OnDestroy } from '@angular/core';
import { ISparqlServiceInjectionToken, ISparqlService } from '../sparql.service.contract';
import { Subscription } from 'rxjs';

@Component({
  selector: 'app-status-indicator',
  templateUrl: './status-indicator.component.html',
  styleUrls: ['./status-indicator.component.css']
})
export class StatusIndicatorComponent implements OnInit, OnDestroy {

  private queryStatusSubscription: Subscription;

  constructor(@Inject(ISparqlServiceInjectionToken) private sparqlService: ISparqlService) { }

  statusLabel: string;

  statusMessage: string;

  isBusy: boolean;

  ngOnInit() {
    this.queryStatusSubscription = this.sparqlService.currentStatus.subscribe(
      status => {
        switch (status.status) {
          case "busy":
            this.isBusy = true;
            this.statusLabel = "Working on it…";
            this.statusMessage = "This may take a while, especially for the first time.";
            break;
          case "successful":
            this.isBusy = false;
            this.statusLabel = this.statusMessage = null;
            break;
          case "failed":
            this.isBusy = false;
            this.statusLabel = "Oops.";
            this.statusMessage = "Something went wrong.";
            break;
          default:
            this.isBusy = false;
            this.statusLabel = "Ready.";
            this.statusMessage = 'Enter your SPARQL query above; then click "Execute" to ask about the what we have in store.';
            break;
        }
        if (status.message) {
          this.statusMessage = status.message;
        }
      }
    )
  }

  ngOnDestroy(): void {
    this.queryStatusSubscription.unsubscribe();
  }

}
