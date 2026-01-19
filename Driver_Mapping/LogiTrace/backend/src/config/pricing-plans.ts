export const PlanType = {
    FREE: 'free',
    STARTER: 'starter',
    PROFESSIONAL: 'professional',
    ENTERPRISE: 'enterprise',
} as const;

export type PlanType = typeof PlanType[keyof typeof PlanType];

export interface Plan {
    id: PlanType;
    name: string;
    price: number;
    minDrivers: number;
    maxDrivers: number | null;
    description: string;
    features: {
        adminCount: string;
        gpsTracking: boolean;
        dailyReports: boolean;
        pdfExport: boolean;
        monthlyReports: boolean;
        digitalSignature: boolean;
        tachographIntegration: boolean;
        dataRetention: string;
        apiAccess: boolean;
        support: string;
    };
    recommended?: boolean;
    hidden?: boolean;
}

export const PLANS: Plan[] = [
    {
        id: PlanType.FREE,
        name: 'フリー',
        price: 0,
        minDrivers: 1,
        maxDrivers: 3,
        description: '個人事業主・お試し用',
        features: {
            adminCount: '1名',
            gpsTracking: true,
            dailyReports: true,
            pdfExport: true,
            monthlyReports: false,
            digitalSignature: false,
            tachographIntegration: false,
            dataRetention: '3ヶ月',
            apiAccess: false,
            support: 'メール',
        },
        hidden: true,
    },
    {
        id: PlanType.STARTER,
        name: 'スターター',
        price: 5800,
        minDrivers: 1,
        maxDrivers: 10,
        description: '小規模事業者向け',
        features: {
            adminCount: '3名',
            gpsTracking: true,
            dailyReports: true,
            pdfExport: true,
            monthlyReports: true,
            digitalSignature: false,
            tachographIntegration: false,
            dataRetention: '1年',
            apiAccess: false,
            support: 'メール',
        },
    },
    {
        id: PlanType.PROFESSIONAL,
        name: 'プロフェッショナル',
        price: 9800,
        minDrivers: 1,
        maxDrivers: 50,
        description: '中規模事業者向け',
        features: {
            adminCount: '無制限',
            gpsTracking: true,
            dailyReports: true,
            pdfExport: true,
            monthlyReports: true,
            digitalSignature: true,
            tachographIntegration: true,
            dataRetention: '3年',
            apiAccess: true,
            support: 'メール+電話',
        },
        recommended: true,
    },
    {
        id: PlanType.ENTERPRISE,
        name: 'エンタープライズ',
        price: 0,
        minDrivers: 51,
        maxDrivers: null,
        description: '大規模事業者向けカスタマイズ',
        features: {
            adminCount: '無制限',
            gpsTracking: true,
            dailyReports: true,
            pdfExport: true,
            monthlyReports: true,
            digitalSignature: true,
            tachographIntegration: true,
            dataRetention: '無制限',
            apiAccess: true,
            support: '専任担当',
        },
    },
];

export const getAllPlans = () => PLANS;

export const getDisplayPlans = () => PLANS.filter(p => !p.hidden);

export const getPlanById = (id: string | null): Plan | undefined => {
    if (!id) return undefined;
    return PLANS.find((plan) => plan.id === id);
};

export const getRecommendedPlan = (driverCount: number): Plan | undefined => {
    return PLANS.filter(p => !p.hidden).find((plan) => {
        if (plan.maxDrivers === null) return driverCount >= plan.minDrivers;
        return driverCount >= plan.minDrivers && driverCount <= plan.maxDrivers;
    });
};

export const formatPrice = (price: number): string => {
    return `¥${price.toLocaleString()}`;
};
