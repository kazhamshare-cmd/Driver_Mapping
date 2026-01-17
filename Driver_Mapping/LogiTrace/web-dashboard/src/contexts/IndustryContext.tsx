import React, { createContext, useContext, useState, useEffect, type ReactNode } from 'react';

export type IndustryCode = 'trucking' | 'taxi' | 'bus';

export interface IndustryInfo {
  industryTypeId: number | null;
  industryCode: IndustryCode | null;
  industryName: string | null;
}

export interface FieldConfig {
  visible: boolean;
  required: boolean;
  label: string;
  order: number;
  type: string;
}

export interface IndustryContextType {
  industryInfo: IndustryInfo;
  loading: boolean;
  isFieldVisible: (fieldName: string) => boolean;
  isFieldRequired: (fieldName: string) => boolean;
  getFieldLabel: (fieldName: string) => string;
  isBusIndustry: boolean;
  isTaxiIndustry: boolean;
  isTruckingIndustry: boolean;
  refreshIndustryInfo: () => void;
}

// Default field visibility config
const DEFAULT_FIELD_CONFIG: Record<IndustryCode, Record<string, FieldConfig>> = {
  trucking: {
    distance: { visible: true, required: true, label: '走行距離', order: 1, type: 'number' },
    cargo_weight: { visible: true, required: false, label: '積載量', order: 2, type: 'number' },
    actual_distance: { visible: true, required: false, label: '実車距離', order: 3, type: 'number' },
    num_passengers: { visible: false, required: false, label: '乗客数', order: 10, type: 'number' },
    revenue: { visible: false, required: false, label: '営業収入', order: 11, type: 'number' },
    operation_type: { visible: false, required: false, label: '運行種別', order: 12, type: 'select' },
    co_driver_id: { visible: false, required: false, label: '交替運転者', order: 13, type: 'select' },
    break_records: { visible: false, required: false, label: '休憩記録', order: 14, type: 'json' },
  },
  taxi: {
    distance: { visible: true, required: true, label: '走行距離', order: 1, type: 'number' },
    num_passengers: { visible: true, required: false, label: '乗客数', order: 2, type: 'number' },
    revenue: { visible: true, required: false, label: '営業収入', order: 3, type: 'number' },
    cargo_weight: { visible: false, required: false, label: '積載量', order: 10, type: 'number' },
    actual_distance: { visible: false, required: false, label: '実車距離', order: 11, type: 'number' },
    operation_type: { visible: false, required: false, label: '運行種別', order: 12, type: 'select' },
    co_driver_id: { visible: false, required: false, label: '交替運転者', order: 13, type: 'select' },
    break_records: { visible: false, required: false, label: '休憩記録', order: 14, type: 'json' },
  },
  bus: {
    distance: { visible: true, required: true, label: '走行距離', order: 1, type: 'number' },
    num_passengers: { visible: true, required: false, label: '乗客数', order: 2, type: 'number' },
    operation_type: { visible: true, required: true, label: '運行種別', order: 3, type: 'select' },
    co_driver_id: { visible: true, required: false, label: '交替運転者', order: 4, type: 'select' },
    break_records: { visible: true, required: false, label: '休憩記録', order: 5, type: 'json' },
    cargo_weight: { visible: false, required: false, label: '積載量', order: 10, type: 'number' },
    actual_distance: { visible: false, required: false, label: '実車距離', order: 11, type: 'number' },
    revenue: { visible: false, required: false, label: '営業収入', order: 12, type: 'number' },
  },
};

const IndustryContext = createContext<IndustryContextType | undefined>(undefined);

export const IndustryProvider: React.FC<{ children: ReactNode }> = ({ children }) => {
  const [industryInfo, setIndustryInfo] = useState<IndustryInfo>({
    industryTypeId: null,
    industryCode: null,
    industryName: null,
  });
  const [loading, setLoading] = useState(true);

  const loadIndustryInfo = () => {
    try {
      const userStr = localStorage.getItem('user');
      if (userStr) {
        const user = JSON.parse(userStr);
        setIndustryInfo({
          industryTypeId: user.industry_type_id || null,
          industryCode: (user.industry_code as IndustryCode) || null,
          industryName: user.industry_name || null,
        });
      }
    } catch (error) {
      console.error('Error loading industry info:', error);
    } finally {
      setLoading(false);
    }
  };

  useEffect(() => {
    loadIndustryInfo();
  }, []);

  const getFieldConfig = (fieldName: string): FieldConfig | undefined => {
    const code = industryInfo.industryCode || 'trucking';
    return DEFAULT_FIELD_CONFIG[code]?.[fieldName];
  };

  const isFieldVisible = (fieldName: string): boolean => {
    const config = getFieldConfig(fieldName);
    return config?.visible ?? false;
  };

  const isFieldRequired = (fieldName: string): boolean => {
    const config = getFieldConfig(fieldName);
    return config?.required ?? false;
  };

  const getFieldLabel = (fieldName: string): string => {
    const config = getFieldConfig(fieldName);
    return config?.label ?? fieldName;
  };

  const value: IndustryContextType = {
    industryInfo,
    loading,
    isFieldVisible,
    isFieldRequired,
    getFieldLabel,
    isBusIndustry: industryInfo.industryCode === 'bus',
    isTaxiIndustry: industryInfo.industryCode === 'taxi',
    isTruckingIndustry: industryInfo.industryCode === 'trucking' || industryInfo.industryCode === null,
    refreshIndustryInfo: loadIndustryInfo,
  };

  return (
    <IndustryContext.Provider value={value}>
      {children}
    </IndustryContext.Provider>
  );
};

export const useIndustry = (): IndustryContextType => {
  const context = useContext(IndustryContext);
  if (context === undefined) {
    throw new Error('useIndustry must be used within an IndustryProvider');
  }
  return context;
};

export default IndustryContext;
