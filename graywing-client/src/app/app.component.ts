import { Component } from "@angular/core";

@Component({
  selector: "app-root",
  templateUrl: "./app.component.html",
  styleUrls: ["./app.component.css"]
})
export class AppComponent {
  title = "Gray Wing Client";

  public onGotoCrystalPoolButtonClicked() {
    window.open("https://crystalpool.cxuesong.com/", "_blank");
  }

  public onGotoRepositoryButtonClicked() {
    window.open("https://github.com/crystal-pool/GrayWing", "_blank");
  }

}
