// Geocoding Service
// 緯度経度から住所を取得するサービス

import * as Location from 'expo-location';

interface AddressResult {
  fullAddress: string;
  prefecture: string;
  city: string;
  street: string;
  postalCode: string | null;
  formattedAddress: string;
}

interface GeocodingCache {
  [key: string]: {
    result: AddressResult;
    timestamp: number;
  };
}

class GeocodingService {
  private cache: GeocodingCache = {};
  private readonly CACHE_DURATION = 5 * 60 * 1000; // 5分キャッシュ
  private readonly COORDINATE_PRECISION = 4; // 小数点以下4桁で丸める（約11m精度）

  // 座標を丸めてキャッシュキーを生成
  private getCacheKey(latitude: number, longitude: number): string {
    const lat = latitude.toFixed(this.COORDINATE_PRECISION);
    const lng = longitude.toFixed(this.COORDINATE_PRECISION);
    return `${lat},${lng}`;
  }

  // キャッシュをチェック
  private checkCache(key: string): AddressResult | null {
    const cached = this.cache[key];
    if (cached && Date.now() - cached.timestamp < this.CACHE_DURATION) {
      return cached.result;
    }
    return null;
  }

  // キャッシュに保存
  private saveToCache(key: string, result: AddressResult): void {
    this.cache[key] = {
      result,
      timestamp: Date.now(),
    };

    // キャッシュサイズを制限（最大100件）
    const keys = Object.keys(this.cache);
    if (keys.length > 100) {
      const oldestKey = keys.reduce((oldest, current) => {
        return this.cache[current].timestamp < this.cache[oldest].timestamp
          ? current
          : oldest;
      });
      delete this.cache[oldestKey];
    }
  }

  // Expo Location APIを使用した逆ジオコーディング
  async reverseGeocode(latitude: number, longitude: number): Promise<AddressResult> {
    const cacheKey = this.getCacheKey(latitude, longitude);

    // キャッシュチェック
    const cached = this.checkCache(cacheKey);
    if (cached) {
      return cached;
    }

    try {
      const results = await Location.reverseGeocodeAsync({
        latitude,
        longitude,
      });

      if (results && results.length > 0) {
        const address = results[0];
        const result: AddressResult = {
          fullAddress: this.buildFullAddress(address),
          prefecture: address.region || '',
          city: address.city || address.subregion || '',
          street: this.buildStreetAddress(address),
          postalCode: address.postalCode || null,
          formattedAddress: this.formatJapaneseAddress(address),
        };

        this.saveToCache(cacheKey, result);
        return result;
      }

      throw new Error('住所が見つかりませんでした');
    } catch (error) {
      console.error('Geocoding error:', error);
      // フォールバック：座標のみ返す
      return {
        fullAddress: `${latitude.toFixed(6)}, ${longitude.toFixed(6)}`,
        prefecture: '',
        city: '',
        street: '',
        postalCode: null,
        formattedAddress: `緯度: ${latitude.toFixed(6)}, 経度: ${longitude.toFixed(6)}`,
      };
    }
  }

  // 完全な住所を構築
  private buildFullAddress(address: Location.LocationGeocodedAddress): string {
    const parts: string[] = [];

    if (address.postalCode) {
      parts.push(`〒${address.postalCode}`);
    }
    if (address.region) {
      parts.push(address.region);
    }
    if (address.city) {
      parts.push(address.city);
    }
    if (address.subregion && address.subregion !== address.city) {
      parts.push(address.subregion);
    }
    if (address.street) {
      parts.push(address.street);
    }
    if (address.streetNumber) {
      parts.push(address.streetNumber);
    }
    if (address.name && !address.street?.includes(address.name)) {
      parts.push(address.name);
    }

    return parts.join(' ');
  }

  // 番地を構築
  private buildStreetAddress(address: Location.LocationGeocodedAddress): string {
    const parts: string[] = [];

    if (address.street) {
      parts.push(address.street);
    }
    if (address.streetNumber) {
      parts.push(address.streetNumber);
    }
    if (address.name && !address.street?.includes(address.name)) {
      parts.push(address.name);
    }

    return parts.join(' ');
  }

  // 日本式住所フォーマット
  private formatJapaneseAddress(address: Location.LocationGeocodedAddress): string {
    // 日本の住所形式: 〒郵便番号 都道府県市区町村番地
    const parts: string[] = [];

    if (address.postalCode) {
      parts.push(`〒${address.postalCode}`);
    }

    // 都道府県
    if (address.region) {
      parts.push(address.region);
    }

    // 市区町村
    if (address.city) {
      parts.push(address.city);
    }

    // 町名・番地
    if (address.subregion && address.subregion !== address.city) {
      parts.push(address.subregion);
    }

    if (address.street) {
      parts.push(address.street);
    }

    if (address.streetNumber) {
      parts.push(address.streetNumber);
    }

    // 建物名等
    if (address.name &&
        !address.street?.includes(address.name) &&
        !address.city?.includes(address.name)) {
      parts.push(address.name);
    }

    return parts.join('');
  }

  // 現在地の住所を取得
  async getCurrentAddress(): Promise<AddressResult> {
    const { status } = await Location.requestForegroundPermissionsAsync();
    if (status !== 'granted') {
      throw new Error('位置情報の権限が許可されていません');
    }

    const location = await Location.getCurrentPositionAsync({
      accuracy: Location.Accuracy.High,
    });

    return this.reverseGeocode(
      location.coords.latitude,
      location.coords.longitude
    );
  }

  // キャッシュをクリア
  clearCache(): void {
    this.cache = {};
  }
}

// シングルトンインスタンス
export const geocodingService = new GeocodingService();
export type { AddressResult };
