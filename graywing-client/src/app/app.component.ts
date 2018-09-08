import { Component, AfterViewInit, Inject, OnInit, OnDestroy } from "@angular/core";
import { IApplicationReadyMessage } from "./window-messages";
import { ISparqlServiceInjectionToken, ISparqlService } from "./sparql.service.contract";
import { Subscription } from "rxjs";

const applicationTitle = "Crystal Pool Query Client";

@Component({
  selector: "app-root",
  templateUrl: "./app.component.html",
  styleUrls: ["./app.component.css"]
})
export class AppComponent implements OnInit, OnDestroy, AfterViewInit {

  private subscriptions: Subscription[] = [];

  public constructor(@Inject(ISparqlServiceInjectionToken) private sparqlService: ISparqlService) {

  }

  public ngOnInit(): void {
    document.title = applicationTitle;
    this.subscriptions.push(this.sparqlService.currentStatus.subscribe(next => {
      switch (next.status) {
        case "busy":
          document.title = "Working… - " + applicationTitle;
          break;
        case "successful":
          document.title = applicationTitle;
          break;
        case "failed":
          document.title = "Failed - " + applicationTitle;
          break;
      }
    }));
    this.subscriptions.push(this.sparqlService.currentResult.subscribe(next => {
      if (next.records) {
        document.title = `${next.variables.length}V ${next.records.length}R - ${applicationTitle}`;
      } else if (next.resultBoolean !== undefined) {
        document.title = `ASK:${next.resultBoolean} - ${applicationTitle}`;
      }
    }));
  }

  public ngAfterViewInit(): void {
    if (window.opener && typeof (window.opener.postMessage) === "function") {
      window.opener.postMessage(<IApplicationReadyMessage>{ type: "ApplicationReady" }, "*");
    }
  }

  public ngOnDestroy(): void {
    this.subscriptions.forEach(s => s.unsubscribe());
  }

  public onGotoCrystalPoolButtonClicked(path: string = "") {
    window.open("https://crystalpool.cxuesong.com/" + path, "_blank");
  }

  public onGotoRepositoryButtonClicked(path: string = "") {
    window.open("https://github.com/crystal-pool/GrayWing/" + path, "_blank");
  }

}
