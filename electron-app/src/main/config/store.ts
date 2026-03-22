import { app } from 'electron';
import { readFileSync, writeFileSync, existsSync, mkdirSync } from 'fs';
import { join } from 'path';
import type { CaptureMode } from '../../shared/types';

interface StoreData {
  apiKey: string;
  captureMode: CaptureMode;
  promptTemplate: string;
}

const DEFAULTS: StoreData = {
  apiKey: '',
  captureMode: 'ocr',
  promptTemplate: '',
};

class ConfigStore {
  private filePath: string;
  private data: StoreData;

  constructor() {
    const userDataPath = app.getPath('userData');
    if (!existsSync(userDataPath)) {
      mkdirSync(userDataPath, { recursive: true });
    }
    this.filePath = join(userDataPath, 'glazer-config.json');
    this.data = this.load();
  }

  private load(): StoreData {
    try {
      if (existsSync(this.filePath)) {
        const raw = readFileSync(this.filePath, 'utf-8');
        return { ...DEFAULTS, ...JSON.parse(raw) };
      }
    } catch {
      // Corrupted file, use defaults.
    }
    return { ...DEFAULTS };
  }

  private save(): void {
    writeFileSync(this.filePath, JSON.stringify(this.data, null, 2), 'utf-8');
  }

  get<K extends keyof StoreData>(key: K): StoreData[K] {
    return this.data[key];
  }

  set<K extends keyof StoreData>(key: K, value: StoreData[K]): void {
    this.data[key] = value;
    this.save();
  }
}

const store = new ConfigStore();
export default store;
