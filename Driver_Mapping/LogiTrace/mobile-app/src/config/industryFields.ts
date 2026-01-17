// Industry-specific field configuration for LogiTrace mobile app
// Defines which fields are visible/hidden based on industry type

export type IndustryCode = 'trucking' | 'taxi' | 'bus';

export type FieldName =
  | 'distance'
  | 'cargo_weight'
  | 'actual_distance'
  | 'num_passengers'
  | 'revenue'
  | 'operation_type'
  | 'co_driver_id'
  | 'break_records'
  | 'operation_instruction';

export interface FieldConfig {
  labelJa: string;
  labelEn: string;
  type: 'number' | 'text' | 'select' | 'json' | 'reference';
  unit?: string;
  placeholder?: string;
}

export interface IndustryFieldConfig {
  visibleFields: FieldName[];
  hiddenFields: FieldName[];
  requiredFields: FieldName[];
  fieldConfigs: Record<FieldName, FieldConfig>;
}

// Field configurations (labels, types, units)
export const FIELD_CONFIGS: Record<FieldName, FieldConfig> = {
  distance: {
    labelJa: '走行距離',
    labelEn: 'Distance',
    type: 'number',
    unit: 'km',
    placeholder: '0.0'
  },
  cargo_weight: {
    labelJa: '積載量',
    labelEn: 'Cargo Weight',
    type: 'number',
    unit: 't',
    placeholder: '0.0'
  },
  actual_distance: {
    labelJa: '実車距離',
    labelEn: 'Loaded Distance',
    type: 'number',
    unit: 'km',
    placeholder: '0.0'
  },
  num_passengers: {
    labelJa: '乗客数',
    labelEn: 'Passengers',
    type: 'number',
    unit: '人',
    placeholder: '0'
  },
  revenue: {
    labelJa: '営業収入',
    labelEn: 'Revenue',
    type: 'number',
    unit: '円',
    placeholder: '0'
  },
  operation_type: {
    labelJa: '運行種別',
    labelEn: 'Operation Type',
    type: 'select',
    placeholder: '選択してください'
  },
  co_driver_id: {
    labelJa: '交替運転者',
    labelEn: 'Co-Driver',
    type: 'select',
    placeholder: 'なし'
  },
  break_records: {
    labelJa: '休憩記録',
    labelEn: 'Break Records',
    type: 'json',
    placeholder: '休憩を追加'
  },
  operation_instruction: {
    labelJa: '運行指示書',
    labelEn: 'Operation Instruction',
    type: 'reference',
    placeholder: '指示書を選択'
  }
};

// Industry-specific configuration
export const INDUSTRY_FIELD_CONFIG: Record<IndustryCode, IndustryFieldConfig> = {
  trucking: {
    visibleFields: ['distance', 'cargo_weight', 'actual_distance'],
    hiddenFields: ['num_passengers', 'revenue', 'operation_type', 'co_driver_id', 'break_records', 'operation_instruction'],
    requiredFields: ['distance'],
    fieldConfigs: FIELD_CONFIGS
  },
  taxi: {
    visibleFields: ['distance', 'num_passengers', 'revenue'],
    hiddenFields: ['cargo_weight', 'actual_distance', 'operation_type', 'co_driver_id', 'break_records', 'operation_instruction'],
    requiredFields: ['distance'],
    fieldConfigs: FIELD_CONFIGS
  },
  bus: {
    visibleFields: ['distance', 'num_passengers', 'operation_type', 'co_driver_id', 'break_records', 'operation_instruction'],
    hiddenFields: ['cargo_weight', 'actual_distance', 'revenue'],
    requiredFields: ['distance', 'operation_type'],
    fieldConfigs: FIELD_CONFIGS
  }
};

// Default configuration when industry is not set
export const DEFAULT_INDUSTRY_CODE: IndustryCode = 'trucking';

// Operation type options for bus industry
export interface OperationType {
  code: string;
  nameJa: string;
  nameEn: string;
}

export const BUS_OPERATION_TYPES: OperationType[] = [
  { code: 'regular', nameJa: '定期運行', nameEn: 'Regular Service' },
  { code: 'charter', nameJa: '貸切運行', nameEn: 'Charter Service' },
  { code: 'school', nameJa: 'スクールバス', nameEn: 'School Bus' },
  { code: 'shuttle', nameJa: 'シャトルバス', nameEn: 'Shuttle Bus' },
  { code: 'tour', nameJa: '観光バス', nameEn: 'Sightseeing Bus' },
  { code: 'highway', nameJa: '高速バス', nameEn: 'Highway Bus' }
];

// Break record type
export interface BreakRecord {
  id: string;
  startTime: string;
  endTime: string;
  location: string;
  reason?: string;
}

// Helper function to get field label
export const getFieldLabel = (fieldName: FieldName, language: 'ja' | 'en' = 'ja'): string => {
  const config = FIELD_CONFIGS[fieldName];
  return language === 'ja' ? config.labelJa : config.labelEn;
};

// Helper function to check if a field is visible for an industry
export const isFieldVisible = (industryCode: IndustryCode | undefined, fieldName: FieldName): boolean => {
  const code = industryCode || DEFAULT_INDUSTRY_CODE;
  return INDUSTRY_FIELD_CONFIG[code].visibleFields.includes(fieldName);
};

// Helper function to check if a field is required for an industry
export const isFieldRequired = (industryCode: IndustryCode | undefined, fieldName: FieldName): boolean => {
  const code = industryCode || DEFAULT_INDUSTRY_CODE;
  return INDUSTRY_FIELD_CONFIG[code].requiredFields.includes(fieldName);
};

// Helper function to get all visible fields for an industry
export const getVisibleFields = (industryCode: IndustryCode | undefined): FieldName[] => {
  const code = industryCode || DEFAULT_INDUSTRY_CODE;
  return INDUSTRY_FIELD_CONFIG[code].visibleFields;
};
