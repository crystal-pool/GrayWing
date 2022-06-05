import { ComponentFixture, TestBed, waitForAsync } from "@angular/core/testing";

import { SparqlVariableBindingViewComponent } from "./sparql-variable-binding-view.component";

describe("SparqlVariableBindingViewComponent", () => {
  let component: SparqlVariableBindingViewComponent;
  let fixture: ComponentFixture<SparqlVariableBindingViewComponent>;

  beforeEach(waitForAsync(() => {
    TestBed.configureTestingModule({
      declarations: [ SparqlVariableBindingViewComponent ]
    })
    .compileComponents();
  }));

  beforeEach(() => {
    fixture = TestBed.createComponent(SparqlVariableBindingViewComponent);
    component = fixture.componentInstance;
    fixture.detectChanges();
  });

  it("should create", () => {
    expect(component).toBeTruthy();
  });
});
