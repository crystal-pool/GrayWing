import { TestBed, inject } from "@angular/core/testing";

import { SparqlService } from "./sparql.service";

describe("SparqlService", () => {
  beforeEach(() => {
    TestBed.configureTestingModule({
      providers: [SparqlService]
    });
  });

  it("should be created", inject([SparqlService], (service: SparqlService) => {
    expect(service).toBeTruthy();
  }));
});
