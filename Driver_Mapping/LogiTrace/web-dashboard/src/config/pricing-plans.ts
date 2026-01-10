export const PlanType = {
    SMALL: 'small',
    STANDARD: 'standard',
    PRO: 'pro',
    ENTERPRISE: 'enterprise',
} as const;

export type PlanType = typeof PlanType[keyof typeof PlanType];

export interface Plan {
    id: PlanType;
    name: string;
    price: number; // Monthly price
    minDrivers: number;
    maxDrivers: number | null; // null for unlimited (or consult)
    description: string;
    features: {
        adminCount: string; // '1名' or '無制限'
        gpsTracking: boolean;
        dailyReports: boolean;
        pdfExport: boolean;
        monthlyReports: boolean;
        yearlyReports: boolean;
        dataRetention: string; // '3ヶ月', '1年', '無制限'
        apiAccess: boolean;
        support: string;
    };
    recommended?: boolean;
}

export const PLANS: Plan[] = [
    {
        id: PlanType.SMALL,
        name: 'スモールプラン',
        price: 1980,
        minDrivers: 1,
        maxDrivers: 3,
        description: '小規模事業者向け',
        features: {
            adminCount: '1名',
            gpsTracking: true,
            dailyReports: true,
            pdfExport: true,
            monthlyReports: false,
            yearlyReports: false,
            dataRetention: '3ヶ月',
            apiAccess: false,
            support: 'メール',
        },
    },
    {
        id: PlanType.STANDARD,
        name: 'スタンダードプラン',
        price: 4980,
        minDrivers: 4,
        maxDrivers: 10,
        description: '中小規模事業者向け',
        features: {
            adminCount: '無制限',
            gpsTracking: true,
            dailyReports: true,
            pdfExport: true,
            monthlyReports: true,
            yearlyReports: false,
            dataRetention: '1年',
            apiAccess: false,
            support: 'メール',
        },
        recommended: true,
    },
    {
        id: PlanType.PRO,
        name: 'プロプラン',
        price: 9980,
        minDrivers: 11,
        maxDrivers: 30,
        description: '大規模事業者向け',
        features: {
            adminCount: '無制限',
            gpsTracking: true,
            dailyReports: true,
            pdfExport: true,
            monthlyReports: true,
            yearlyReports: true,
            dataRetention: '無制限',
            apiAccess: true,
            support: 'メール+電話',
        },
    },
    {
        id: PlanType.ENTERPRISE,
        name: 'エンタープライズ',
        price: 0, // Price on request
        minDrivers: 31,
        maxDrivers: null,
        description: '特大規模向けカスタマイズ対応',
        features: {
            adminCount: '無制限',
            gpsTracking: true,
            dailyReports: true,
            pdfExport: true,
            monthlyReports: true,
            yearlyReports: true,
            dataRetention: '無制限',
            apiAccess: true,
            support: '専任担当者',
        },
    },
];

export const getAllPlans = () => PLANS;

export const getPlanById = (id: string | null): Plan | undefined => {
    if (!id) return undefined;
    // Helper to check if string matches PlanType value
    const values = Object.values(PlanType) as string[];
    if (values.includes(id)) {
        return PLANS.find((plan) => plan.id === id);
    }
    return undefined;
};

export const getRecommendedPlan = (driverCount: number): Plan | undefined => {
    return PLANS.find((plan) => {
        if (plan.maxDrivers === null) return driverCount >= plan.minDrivers;
        return driverCount >= plan.minDrivers && driverCount <= plan.maxDrivers;
    });
};
