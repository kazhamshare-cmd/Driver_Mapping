// Type declarations for react-native-ble-plx
// This is a placeholder for when the package is not installed

declare module 'react-native-ble-plx' {
  export class BleManager {
    startDeviceScan(
      serviceUUIDs: string[] | null,
      options: any | null,
      callback: (error: any, device: any) => void
    ): void;
    stopDeviceScan(): void;
    connectToDevice(deviceId: string): Promise<any>;
    cancelDeviceConnection(deviceId: string): Promise<void>;
    monitorCharacteristicForDevice(
      deviceId: string,
      serviceUUID: string,
      characteristicUUID: string,
      callback: (error: any, characteristic: any) => void
    ): Promise<void>;
    writeCharacteristicWithResponseForDevice(
      deviceId: string,
      serviceUUID: string,
      characteristicUUID: string,
      base64Value: string
    ): Promise<any>;
  }
}
