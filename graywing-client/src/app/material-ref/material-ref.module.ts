import { NgModule } from "@angular/core";
import { CommonModule } from "@angular/common";
import { BrowserAnimationsModule } from "@angular/platform-browser/animations";
import { MatButtonModule, MatCheckboxModule, MatCardModule, MatFormFieldModule, MatInputModule, MatProgressBarModule, MatIconModule, MatToolbarModule, MatTooltipModule } from "@angular/material";

@NgModule({
  imports: [
    CommonModule,
    BrowserAnimationsModule,
    MatButtonModule,
    MatCheckboxModule,
    MatCardModule,
    MatFormFieldModule,
    MatInputModule,
    MatProgressBarModule,
    MatIconModule,
    MatToolbarModule,
    MatTooltipModule
  ],
  exports: [
    BrowserAnimationsModule,
    MatButtonModule,
    MatCheckboxModule,
    MatCardModule,
    MatFormFieldModule,
    MatInputModule,
    MatProgressBarModule,
    MatIconModule,
    MatToolbarModule,
    MatTooltipModule
  ],
  declarations: []
})
export class MaterialRefModule { }
