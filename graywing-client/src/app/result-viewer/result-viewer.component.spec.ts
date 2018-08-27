import { async, ComponentFixture, TestBed } from '@angular/core/testing';

import { ResultViewerComponent } from './result-viewer.component';

describe('ResultViewerComponent', () => {
  let component: ResultViewerComponent;
  let fixture: ComponentFixture<ResultViewerComponent>;

  beforeEach(async(() => {
    TestBed.configureTestingModule({
      declarations: [ ResultViewerComponent ]
    })
    .compileComponents();
  }));

  beforeEach(() => {
    fixture = TestBed.createComponent(ResultViewerComponent);
    component = fixture.componentInstance;
    fixture.detectChanges();
  });

  it('should create', () => {
    expect(component).toBeTruthy();
  });
});
