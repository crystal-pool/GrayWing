import { Pipe, PipeTransform } from '@angular/core';
import { SparqlVariableBindingValue, SparqlBlankNode, SparqlUri } from './sparql-models';
import { DomSanitizer, SafeHtml } from '@angular/platform-browser';

const wellKnownUriPrefixes: { [prefix: string]: string } = {
  "wd": "https://crystalpool.cxuesong.com/entity/",
  "xml": "http://www.w3.org/XML/1998/namespace/",
  "rdf": "http://www.w3.org/1999/02/22-rdf-syntax-ns#",
  "owl": "http://www.w3.org/2002/07/owl#"
};

@Pipe({
  name: 'sparqlVariableBinding'
})
export class SparqlVariableBindingPipe implements PipeTransform {

  constructor(private sanitizer: DomSanitizer) {

  }

  transform(value: SparqlVariableBindingValue): SafeHtml | string {
    if (value instanceof SparqlUri) {
      const uri = (<SparqlUri>value).value;
      let label = uri;
      const link = document.createElement("a");
      link.target = "_blank";
      link.href = uri;
      for (const prefix in wellKnownUriPrefixes) {
        if (!wellKnownUriPrefixes.hasOwnProperty(prefix)) continue;
        const puri = wellKnownUriPrefixes[prefix];
        if (uri.startsWith(puri)) {
          label = prefix + ":" + uri.substr(puri.length);
        }
      }
      link.innerText = label;
      return this.sanitizer.bypassSecurityTrustHtml(link.outerHTML);
    }
    return value.toString();
  }

}
