import React, { createContext, useContext, useState, useEffect, ReactNode } from 'react';
import AsyncStorage from '@react-native-async-storage/async-storage';
import {
  DriverAppSettings,
  DEFAULT_DRIVER_APP_SETTINGS,
  PlanFeatures,
  PLAN_FEATURES,
} from '../config/driverAppSettings';
import { authService } from '../services/authService';
import { API_BASE_URL } from '../config/api';

interface DriverAppSettingsContextType {
  settings: DriverAppSettings;
  planFeatures: PlanFeatures;
  loading: boolean;
  error: string | null;
  refreshSettings: () => Promise<void>;
  isFeatureEnabled: (feature: keyof PlanFeatures) => boolean;
}

const DriverAppSettingsContext = createContext<DriverAppSettingsContextType | undefined>(undefined);

const SETTINGS_STORAGE_KEY = '@driver_app_settings';
const PLAN_STORAGE_KEY = '@subscription_plan';

interface ProviderProps {
  children: ReactNode;
}

export function DriverAppSettingsProvider({ children }: ProviderProps) {
  const [settings, setSettings] = useState<DriverAppSettings>(DEFAULT_DRIVER_APP_SETTINGS);
  const [planFeatures, setPlanFeatures] = useState<PlanFeatures>(PLAN_FEATURES.starter);
  const [loading, setLoading] = useState(true);
  const [error, setError] = useState<string | null>(null);

  const loadSettingsFromStorage = async () => {
    try {
      const storedSettings = await AsyncStorage.getItem(SETTINGS_STORAGE_KEY);
      const storedPlan = await AsyncStorage.getItem(PLAN_STORAGE_KEY);

      if (storedSettings) {
        setSettings(JSON.parse(storedSettings));
      }
      if (storedPlan) {
        const plan = storedPlan as keyof typeof PLAN_FEATURES;
        setPlanFeatures(PLAN_FEATURES[plan] || PLAN_FEATURES.starter);
      }
    } catch (e) {
      console.warn('Failed to load settings from storage:', e);
    }
  };

  const fetchSettingsFromServer = async () => {
    try {
      const response = await authService.authenticatedFetch(
        `${API_BASE_URL}/driver-app/settings`
      );

      if (response.ok) {
        const data = await response.json();
        const newSettings = { ...DEFAULT_DRIVER_APP_SETTINGS, ...data.settings };
        const plan = data.plan || 'starter';

        setSettings(newSettings);
        setPlanFeatures(PLAN_FEATURES[plan] || PLAN_FEATURES.starter);

        // Cache locally
        await AsyncStorage.setItem(SETTINGS_STORAGE_KEY, JSON.stringify(newSettings));
        await AsyncStorage.setItem(PLAN_STORAGE_KEY, plan);
      }
    } catch (e) {
      console.warn('Failed to fetch settings from server:', e);
      setError('設定の取得に失敗しました');
    }
  };

  const refreshSettings = async () => {
    setLoading(true);
    setError(null);
    await fetchSettingsFromServer();
    setLoading(false);
  };

  const isFeatureEnabled = (feature: keyof PlanFeatures): boolean => {
    return planFeatures[feature];
  };

  useEffect(() => {
    const initializeSettings = async () => {
      await loadSettingsFromStorage();
      await fetchSettingsFromServer();
      setLoading(false);
    };

    initializeSettings();
  }, []);

  const value: DriverAppSettingsContextType = {
    settings,
    planFeatures,
    loading,
    error,
    refreshSettings,
    isFeatureEnabled,
  };

  return (
    <DriverAppSettingsContext.Provider value={value}>
      {children}
    </DriverAppSettingsContext.Provider>
  );
}

export function useDriverAppSettings(): DriverAppSettingsContextType {
  const context = useContext(DriverAppSettingsContext);
  if (context === undefined) {
    throw new Error('useDriverAppSettings must be used within a DriverAppSettingsProvider');
  }
  return context;
}
