import { BrowserModule } from '@angular/platform-browser';
import { NgModule } from '@angular/core';

import { AppComponent } from './app.component';
import { MaterialRefModule } from './material-ref/material-ref.module';
import { CodeEditorComponent } from './code-editor/code-editor.component';
import { HttpClientModule } from '@angular/common/http';
import { FormsModule } from '@angular/forms';
import { ISparqlServiceInjectionToken } from './sparql.service.contract';
import { SparqlMockService } from './sparql.service.mock';

@NgModule({
  declarations: [
    AppComponent,
    CodeEditorComponent
  ],
  imports: [
    BrowserModule,
    FormsModule,
    MaterialRefModule,
    HttpClientModule
  ],
  providers: [{ provide: ISparqlServiceInjectionToken, useClass: SparqlMockService }],
  bootstrap: [AppComponent]
})
export class AppModule { }
