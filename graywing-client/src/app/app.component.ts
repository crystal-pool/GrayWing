import { Component, AfterViewInit } from "@angular/core";
import { IApplicationReadyMessage } from "./window-messages";

@Component({
  selector: "app-root",
  templateUrl: "./app.component.html",
  styleUrls: ["./app.component.css"]
})
export class AppComponent implements AfterViewInit {
  public title = "Gray Wing Client";

  public ngAfterViewInit(): void {
    if (window.opener && typeof (window.opener.postMessage) === "function") {
      window.opener.postMessage(<IApplicationReadyMessage>{ type: "ApplicationReady" }, "*");
    }
  }

  public onGotoCrystalPoolButtonClicked() {
    window.open("https://crystalpool.cxuesong.com/", "_blank");
  }

  public onGotoRepositoryButtonClicked() {
    window.open("https://github.com/crystal-pool/GrayWing", "_blank");
  }

}
