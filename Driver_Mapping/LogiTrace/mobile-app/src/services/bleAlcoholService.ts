// BLE Alcohol Checker Service
// Bluetooth Low Energy アルコールチェッカー連携サービス

import { Platform, PermissionsAndroid } from 'react-native';
import { BLE_ALCOHOL_CHECKER } from '../config/driverAppSettings';

// BLE Manager型定義（react-native-ble-plx使用時）
interface BleDevice {
  id: string;
  name: string | null;
  rssi: number;
}

interface AlcoholReading {
  value: number; // mg/L
  timestamp: Date;
  deviceId: string;
  deviceName: string;
  isValid: boolean;
}

type ScanCallback = (device: BleDevice) => void;
type ReadingCallback = (reading: AlcoholReading) => void;
type ErrorCallback = (error: Error) => void;

class BleAlcoholService {
  private manager: any = null;
  private connectedDevice: BleDevice | null = null;
  private isScanning: boolean = false;
  private onReadingCallback: ReadingCallback | null = null;
  private onErrorCallback: ErrorCallback | null = null;

  // BLEマネージャー初期化（遅延ロード）
  private async initializeBleManager(): Promise<void> {
    if (this.manager) return;

    try {
      // react-native-ble-plxを動的インポート
      const { BleManager } = await import('react-native-ble-plx');
      this.manager = new BleManager();
    } catch (error) {
      console.warn('BLE Manager not available:', error);
      throw new Error('BLE機能が利用できません。react-native-ble-plxをインストールしてください。');
    }
  }

  // Bluetooth権限リクエスト
  async requestPermissions(): Promise<boolean> {
    if (Platform.OS === 'android') {
      const apiLevel = Platform.Version;

      if (apiLevel >= 31) {
        // Android 12+
        const results = await PermissionsAndroid.requestMultiple([
          PermissionsAndroid.PERMISSIONS.BLUETOOTH_SCAN,
          PermissionsAndroid.PERMISSIONS.BLUETOOTH_CONNECT,
          PermissionsAndroid.PERMISSIONS.ACCESS_FINE_LOCATION,
        ]);

        return (
          results['android.permission.BLUETOOTH_SCAN'] === 'granted' &&
          results['android.permission.BLUETOOTH_CONNECT'] === 'granted' &&
          results['android.permission.ACCESS_FINE_LOCATION'] === 'granted'
        );
      } else {
        // Android 11以下
        const result = await PermissionsAndroid.request(
          PermissionsAndroid.PERMISSIONS.ACCESS_FINE_LOCATION
        );
        return result === 'granted';
      }
    }

    // iOS - Info.plistでの設定が必要
    return true;
  }

  // デバイススキャン開始
  async startScan(onDeviceFound: ScanCallback, onError?: ErrorCallback): Promise<void> {
    await this.initializeBleManager();

    const hasPermission = await this.requestPermissions();
    if (!hasPermission) {
      const error = new Error('Bluetooth権限が許可されていません');
      onError?.(error);
      return;
    }

    if (this.isScanning) {
      await this.stopScan();
    }

    this.isScanning = true;

    try {
      this.manager.startDeviceScan(
        [BLE_ALCOHOL_CHECKER.SERVICE_UUID],
        null,
        (error: any, device: any) => {
          if (error) {
            console.error('Scan error:', error);
            onError?.(error);
            return;
          }

          if (device?.name) {
            // サポートデバイスかチェック
            const isSupported = BLE_ALCOHOL_CHECKER.SUPPORTED_DEVICES.some(
              (supported) => device.name?.startsWith(supported.prefix)
            );

            if (isSupported) {
              onDeviceFound({
                id: device.id,
                name: device.name,
                rssi: device.rssi,
              });
            }
          }
        }
      );

      // 30秒でスキャン自動停止
      setTimeout(() => {
        this.stopScan();
      }, 30000);
    } catch (error) {
      this.isScanning = false;
      onError?.(error as Error);
    }
  }

  // スキャン停止
  async stopScan(): Promise<void> {
    if (this.manager && this.isScanning) {
      this.manager.stopDeviceScan();
      this.isScanning = false;
    }
  }

  // デバイス接続
  async connect(deviceId: string): Promise<BleDevice> {
    await this.initializeBleManager();

    try {
      const device = await this.manager.connectToDevice(deviceId);
      await device.discoverAllServicesAndCharacteristics();

      this.connectedDevice = {
        id: device.id,
        name: device.name,
        rssi: device.rssi,
      };

      // 切断イベント監視
      device.onDisconnected(() => {
        this.connectedDevice = null;
        console.log('Device disconnected');
      });

      return this.connectedDevice;
    } catch (error) {
      console.error('Connection error:', error);
      throw new Error('デバイスへの接続に失敗しました');
    }
  }

  // デバイス切断
  async disconnect(): Promise<void> {
    if (this.manager && this.connectedDevice) {
      try {
        await this.manager.cancelDeviceConnection(this.connectedDevice.id);
      } catch (error) {
        console.warn('Disconnect error:', error);
      }
      this.connectedDevice = null;
    }
  }

  // 計測値の監視開始
  async startReadingMonitor(
    onReading: ReadingCallback,
    onError?: ErrorCallback
  ): Promise<void> {
    if (!this.connectedDevice) {
      throw new Error('デバイスが接続されていません');
    }

    this.onReadingCallback = onReading;
    this.onErrorCallback = onError || null;

    try {
      await this.manager.monitorCharacteristicForDevice(
        this.connectedDevice.id,
        BLE_ALCOHOL_CHECKER.SERVICE_UUID,
        BLE_ALCOHOL_CHECKER.CHARACTERISTIC_UUID,
        (error: any, characteristic: any) => {
          if (error) {
            this.onErrorCallback?.(error);
            return;
          }

          if (characteristic?.value) {
            const reading = this.parseAlcoholReading(characteristic.value);
            if (reading) {
              this.onReadingCallback?.(reading);
            }
          }
        }
      );
    } catch (error) {
      console.error('Monitor error:', error);
      throw new Error('計測値の監視開始に失敗しました');
    }
  }

  // 計測値のパース
  private parseAlcoholReading(base64Value: string): AlcoholReading | null {
    try {
      // Base64デコード
      const bytes = this.base64ToBytes(base64Value);

      if (bytes.length < 4) {
        return null;
      }

      // メーカーによってフォーマットが異なるため、一般的なパターンで解析
      // 多くのBLEアルコールチェッカーは mg/L * 1000 の整数値を送信
      const rawValue = (bytes[0] << 8) | bytes[1];
      const alcoholValue = rawValue / 1000; // mg/L

      return {
        value: alcoholValue,
        timestamp: new Date(),
        deviceId: this.connectedDevice?.id || '',
        deviceName: this.connectedDevice?.name || '',
        isValid: alcoholValue >= 0 && alcoholValue < 2.0, // 妥当性チェック
      };
    } catch (error) {
      console.error('Parse error:', error);
      return null;
    }
  }

  // Base64→バイト配列変換
  private base64ToBytes(base64: string): number[] {
    const binaryString = atob(base64);
    const bytes: number[] = [];
    for (let i = 0; i < binaryString.length; i++) {
      bytes.push(binaryString.charCodeAt(i));
    }
    return bytes;
  }

  // 接続状態取得
  isConnected(): boolean {
    return this.connectedDevice !== null;
  }

  // 接続中デバイス情報取得
  getConnectedDevice(): BleDevice | null {
    return this.connectedDevice;
  }

  // 手動測定リクエスト（一部デバイス対応）
  async requestMeasurement(): Promise<void> {
    if (!this.connectedDevice) {
      throw new Error('デバイスが接続されていません');
    }

    try {
      // 測定開始コマンドを送信（デバイス依存）
      const command = new Uint8Array([0x01]); // 一般的な開始コマンド
      await this.manager.writeCharacteristicWithResponseForDevice(
        this.connectedDevice.id,
        BLE_ALCOHOL_CHECKER.SERVICE_UUID,
        BLE_ALCOHOL_CHECKER.CHARACTERISTIC_UUID,
        this.bytesToBase64(Array.from(command))
      );
    } catch (error) {
      console.warn('Measurement request failed:', error);
      // 多くのデバイスはボタン操作で測定開始するため、エラーは警告のみ
    }
  }

  // バイト配列→Base64変換
  private bytesToBase64(bytes: number[]): string {
    const binaryString = String.fromCharCode(...bytes);
    return btoa(binaryString);
  }
}

// シングルトンインスタンス
export const bleAlcoholService = new BleAlcoholService();
export type { BleDevice, AlcoholReading };
