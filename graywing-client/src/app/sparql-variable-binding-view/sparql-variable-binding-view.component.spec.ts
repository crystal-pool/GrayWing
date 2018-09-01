import { async, ComponentFixture, TestBed } from '@angular/core/testing';

import { SparqlVariableBindingViewComponent } from './sparql-variable-binding-view.component';

describe('SparqlVariableBindingViewComponent', () => {
  let component: SparqlVariableBindingViewComponent;
  let fixture: ComponentFixture<SparqlVariableBindingViewComponent>;

  beforeEach(async(() => {
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

  it('should create', () => {
    expect(component).toBeTruthy();
  });
});
