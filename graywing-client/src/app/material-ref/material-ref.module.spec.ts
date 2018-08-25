import { MaterialRefModule } from './material-ref.module';

describe('MaterialRefModule', () => {
  let materialRefModule: MaterialRefModule;

  beforeEach(() => {
    materialRefModule = new MaterialRefModule();
  });

  it('should create an instance', () => {
    expect(materialRefModule).toBeTruthy();
  });
});
