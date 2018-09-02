import { BrowserModule } from "@angular/platform-browser";
import { NgModule } from "@angular/core";

import { AppComponent } from "./app.component";
import { MaterialRefModule } from "./material-ref/material-ref.module";
import { HttpClientModule } from "@angular/common/http";
import { FormsModule } from "@angular/forms";
import { NgxDatatableModule } from "@swimlane/ngx-datatable";

import { ISparqlServiceInjectionToken } from "./sparql.service.contract";
import { CodeEditorComponent } from "./code-editor/code-editor.component";
import { SparqlMockService } from "./sparql.service.mock";
import { ResultViewerComponent } from "./result-viewer/result-viewer.component";
import { environment } from "../environments/environment";
import { SparqlService } from "./sparql.service";
import { StatusIndicatorComponent } from "./status-indicator/status-indicator.component";
import { SparqlVariableBindingViewComponent } from "./sparql-variable-binding-view/sparql-variable-binding-view.component";

@NgModule({
  declarations: [
    AppComponent,
    CodeEditorComponent,
    ResultViewerComponent,
    StatusIndicatorComponent,
    SparqlVariableBindingViewComponent
  ],
  imports: [
    BrowserModule,
    FormsModule,
    MaterialRefModule,
    NgxDatatableModule,
    HttpClientModule
  ],
  providers: [{ provide: ISparqlServiceInjectionToken, useClass: environment.production ? SparqlService : SparqlMockService }],
  bootstrap: [AppComponent]
})
export class AppModule { }
