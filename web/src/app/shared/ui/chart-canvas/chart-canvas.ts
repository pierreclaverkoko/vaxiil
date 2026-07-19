import {
  AfterViewInit,
  Component,
  ElementRef,
  OnDestroy,
  effect,
  input,
  viewChild,
} from '@angular/core';
import {
  Chart,
  ChartConfiguration,
  ChartType,
  Filler,
  Legend,
  LineController,
  LineElement,
  LinearScale,
  CategoryScale,
  PointElement,
  Tooltip,
  BarController,
  BarElement,
} from 'chart.js';

Chart.register(
  LineController,
  LineElement,
  PointElement,
  LinearScale,
  CategoryScale,
  Filler,
  Legend,
  Tooltip,
  BarController,
  BarElement,
);

@Component({
  selector: 'app-chart-canvas',
  standalone: true,
  templateUrl: './chart-canvas.html',
  styleUrl: './chart-canvas.scss',
})
export class ChartCanvasComponent implements AfterViewInit, OnDestroy {
  readonly type = input<ChartType>('line');
  readonly labels = input<string[]>([]);
  readonly datasets = input<ChartConfiguration['data']['datasets']>([]);
  readonly height = input(220);

  private readonly canvas = viewChild<ElementRef<HTMLCanvasElement>>('canvas');
  private chart: Chart | null = null;
  private viewReady = false;

  constructor() {
    effect(() => {
      this.labels();
      this.datasets();
      this.type();
      if (this.viewReady) {
        this.render();
      }
    });
  }

  ngAfterViewInit(): void {
    this.viewReady = true;
    this.render();
  }

  ngOnDestroy(): void {
    this.chart?.destroy();
    this.chart = null;
  }

  private render(): void {
    const el = this.canvas()?.nativeElement;
    if (!el) {
      return;
    }
    this.chart?.destroy();
    this.chart = new Chart(el, {
      type: this.type(),
      data: {
        labels: this.labels(),
        datasets: this.datasets() ?? [],
      },
      options: {
        responsive: true,
        maintainAspectRatio: false,
        plugins: {
          legend: { display: false },
        },
        scales: {
          x: {
            grid: { display: false },
            ticks: { maxRotation: 0, autoSkipPadding: 12 },
          },
          y: {
            beginAtZero: true,
            ticks: { precision: 0 },
          },
        },
      },
    });
  }
}
