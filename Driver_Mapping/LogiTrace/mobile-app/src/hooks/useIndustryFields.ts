import { useCallback, useEffect, useState } from 'react';
import {
  IndustryCode,
  FieldName,
  FieldConfig,
  INDUSTRY_FIELD_CONFIG,
  FIELD_CONFIGS,
  DEFAULT_INDUSTRY_CODE,
  BUS_OPERATION_TYPES,
  OperationType,
  isFieldVisible,
  isFieldRequired,
  getVisibleFields,
  getFieldLabel
} from '../config/industryFields';
import { authService } from '../services/authService';
import { API_BASE_URL } from '../config/api';

interface Driver {
  id: number;
  name: string;
  employee_number?: string;
}

interface UseIndustryFieldsReturn {
  industryCode: IndustryCode | undefined;
  industryName: string | undefined;
  loading: boolean;
  // Field visibility
  isFieldVisible: (fieldName: FieldName) => boolean;
  isFieldRequired: (fieldName: FieldName) => boolean;
  getVisibleFields: () => FieldName[];
  getFieldLabel: (fieldName: FieldName) => string;
  getFieldConfig: (fieldName: FieldName) => FieldConfig;
  // Data fetching for select fields
  operationTypes: OperationType[];
  coDrivers: Driver[];
  fetchOperationTypes: () => Promise<void>;
  fetchCoDrivers: () => Promise<void>;
  // Bus-specific helpers
  isBusIndustry: boolean;
  isTaxiIndustry: boolean;
  isTruckingIndustry: boolean;
}

export const useIndustryFields = (): UseIndustryFieldsReturn => {
  const [industryCode, setIndustryCode] = useState<IndustryCode | undefined>(undefined);
  const [industryName, setIndustryName] = useState<string | undefined>(undefined);
  const [loading, setLoading] = useState(true);
  const [operationTypes, setOperationTypes] = useState<OperationType[]>(BUS_OPERATION_TYPES);
  const [coDrivers, setCoDrivers] = useState<Driver[]>([]);

  // Load industry info from stored user data
  useEffect(() => {
    const loadIndustryInfo = async () => {
      try {
        const user = await authService.getUser();
        if (user?.industry_code) {
          setIndustryCode(user.industry_code as IndustryCode);
          setIndustryName(user.industry_name);
        } else {
          setIndustryCode(DEFAULT_INDUSTRY_CODE);
        }
      } catch (error) {
        console.error('Error loading industry info:', error);
        setIndustryCode(DEFAULT_INDUSTRY_CODE);
      } finally {
        setLoading(false);
      }
    };
    loadIndustryInfo();
  }, []);

  // Check if a field is visible
  const checkFieldVisible = useCallback((fieldName: FieldName): boolean => {
    return isFieldVisible(industryCode, fieldName);
  }, [industryCode]);

  // Check if a field is required
  const checkFieldRequired = useCallback((fieldName: FieldName): boolean => {
    return isFieldRequired(industryCode, fieldName);
  }, [industryCode]);

  // Get all visible fields
  const getAllVisibleFields = useCallback((): FieldName[] => {
    return getVisibleFields(industryCode);
  }, [industryCode]);

  // Get field label
  const getLabel = useCallback((fieldName: FieldName): string => {
    return getFieldLabel(fieldName, 'ja');
  }, []);

  // Get field config
  const getFieldConfig = useCallback((fieldName: FieldName): FieldConfig => {
    return FIELD_CONFIGS[fieldName];
  }, []);

  // Fetch operation types from API (for bus industry)
  const fetchOperationTypes = useCallback(async () => {
    if (industryCode !== 'bus') return;

    try {
      const response = await authService.authenticatedFetch(
        `/industries/${industryCode}/operation-types`
      );
      const data = await response.json();
      if (Array.isArray(data)) {
        setOperationTypes(data.map((item: any) => ({
          code: item.code,
          nameJa: item.name_ja,
          nameEn: item.name_en
        })));
      }
    } catch (error) {
      console.error('Error fetching operation types:', error);
      // Fall back to static data
      setOperationTypes(BUS_OPERATION_TYPES);
    }
  }, [industryCode]);

  // Fetch co-drivers from API
  const fetchCoDrivers = useCallback(async () => {
    try {
      const user = await authService.getUser();
      if (!user?.company_id) return;

      const response = await authService.authenticatedFetch(
        `/industries/company/${user.company_id}/drivers`
      );
      const data = await response.json();
      if (Array.isArray(data)) {
        // Filter out current user
        const currentUserId = user.id;
        setCoDrivers(data.filter((driver: Driver) => driver.id !== currentUserId));
      }
    } catch (error) {
      console.error('Error fetching co-drivers:', error);
      setCoDrivers([]);
    }
  }, []);

  // Fetch data when industry code changes
  useEffect(() => {
    if (industryCode === 'bus') {
      fetchOperationTypes();
      fetchCoDrivers();
    }
  }, [industryCode, fetchOperationTypes, fetchCoDrivers]);

  return {
    industryCode,
    industryName,
    loading,
    isFieldVisible: checkFieldVisible,
    isFieldRequired: checkFieldRequired,
    getVisibleFields: getAllVisibleFields,
    getFieldLabel: getLabel,
    getFieldConfig,
    operationTypes,
    coDrivers,
    fetchOperationTypes,
    fetchCoDrivers,
    isBusIndustry: industryCode === 'bus',
    isTaxiIndustry: industryCode === 'taxi',
    isTruckingIndustry: industryCode === 'trucking'
  };
};

export default useIndustryFields;
