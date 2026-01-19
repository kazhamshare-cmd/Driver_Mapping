// Driver App Settings Types
// オプション機能の設定型定義

export type AlcoholCheckMode = 'manual' | 'ble' | 'both';
export type IdentityVerificationMode = 'none' | 'photo' | 'face_recognition';
export type LocationDisplayMode = 'coordinates' | 'address';

export interface DriverAppSettings {
  // アルコールチェック設定
  alcoholCheckMode: AlcoholCheckMode;
  bleDeviceId?: string; // BLE機器のデバイスID

  // 本人確認設定
  identityVerificationMode: IdentityVerificationMode;
  requirePhotoOnTenko: boolean;

  // 位置情報設定
  locationDisplayMode: LocationDisplayMode;
  enableAddressLookup: boolean;

  // 点検設定
  enableInspectionPhotos: boolean;
  requirePhotoOnFailure: boolean;

  // GPS設定
  gpsUpdateInterval: number; // milliseconds
  gpsDistanceThreshold: number; // meters

  // 通知設定
  enableContinuousDrivingAlert: boolean;
  continuousDrivingAlertMinutes: number;
  enableRestPeriodAlert: boolean;
}

// デフォルト設定（スタータープラン）
export const DEFAULT_DRIVER_APP_SETTINGS: DriverAppSettings = {
  alcoholCheckMode: 'manual',
  identityVerificationMode: 'none',
  requirePhotoOnTenko: false,
  locationDisplayMode: 'coordinates',
  enableAddressLookup: false,
  enableInspectionPhotos: false,
  requirePhotoOnFailure: false,
  gpsUpdateInterval: 15000,
  gpsDistanceThreshold: 10,
  enableContinuousDrivingAlert: true,
  continuousDrivingAlertMinutes: 210, // 3.5時間 = 4時間の30分前
  enableRestPeriodAlert: true,
};

// プラン別機能制限
export interface PlanFeatures {
  bleAlcoholChecker: boolean;
  photoCapture: boolean;
  faceRecognition: boolean;
  addressLookup: boolean;
  inspectionPhotos: boolean;
}

export const PLAN_FEATURES: Record<string, PlanFeatures> = {
  starter: {
    bleAlcoholChecker: false,
    photoCapture: false,
    faceRecognition: false,
    addressLookup: false,
    inspectionPhotos: false,
  },
  standard: {
    bleAlcoholChecker: true,
    photoCapture: true,
    faceRecognition: false,
    addressLookup: true,
    inspectionPhotos: true,
  },
  pro: {
    bleAlcoholChecker: true,
    photoCapture: true,
    faceRecognition: true,
    addressLookup: true,
    inspectionPhotos: true,
  },
};

// BLE Alcohol Checker Service UUIDs (共通規格)
export const BLE_ALCOHOL_CHECKER = {
  SERVICE_UUID: '0000fff0-0000-1000-8000-00805f9b34fb',
  CHARACTERISTIC_UUID: '0000fff1-0000-1000-8000-00805f9b34fb',
  // 主要メーカー対応
  SUPPORTED_DEVICES: [
    { name: 'Tanita EA-100', prefix: 'EA-100' },
    { name: 'Tanita FC-1000', prefix: 'FC-1000' },
    { name: 'Tokai Denshi ALC-Mobile', prefix: 'ALC-M' },
    { name: 'JVC Kenwood CAX-AD100', prefix: 'CAX-AD' },
  ],
};
