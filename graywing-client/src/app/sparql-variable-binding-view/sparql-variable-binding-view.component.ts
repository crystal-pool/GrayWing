import { Component, OnInit, Input } from "@angular/core";
import { SparqlVariableBindingValue, SparqlUri, SparqlBlankNode } from "../sparql-models";

const wellKnownUriPrefixes: { [prefix: string]: string } = {
  "wd": "https://crystalpool.cxuesong.com/entity/",
  "xml": "http://www.w3.org/XML/1998/namespace/",
  "rdf": "http://www.w3.org/1999/02/22-rdf-syntax-ns#",
  "owl": "http://www.w3.org/2002/07/owl#"
};

@Component({
  selector: "app-sparql-variable-binding-view",
  templateUrl: "./sparql-variable-binding-view.component.html",
  styleUrls: ["./sparql-variable-binding-view.component.css"]
})
export class SparqlVariableBindingViewComponent implements OnInit {

  private _value: SparqlVariableBindingValue;

  constructor() { }

  public get value(): SparqlVariableBindingValue { return this._value; }

  @Input()
  public set value(value: SparqlVariableBindingValue) {
    this.label = null;
    this.linkTarget = null;
    this.annotation = null;
    if (value instanceof SparqlUri) {
      const uri = value.value;
      this.linkTarget = uri;
      this.label = uri;
      for (const prefix in wellKnownUriPrefixes) {
        if (!wellKnownUriPrefixes.hasOwnProperty(prefix)) { continue; }
        const puri = wellKnownUriPrefixes[prefix];
        if (uri.startsWith(puri)) {
          this.label = prefix + ":" + uri.substr(puri.length);
          break;
        }
      }
    } else if (value instanceof SparqlBlankNode) {
      this.label = "_:" + value.name;
      this.annotation = "Blank Node";
    } else {
      this.label = value.toString();
    }
    this._value = value;
  }

  public linkTarget: string;

  public label: string;

  public annotation: string;

  public ngOnInit() {
  }

}
