// theme/constants.ts
// アプリ全体で使用するデザイン定数
// WCAG 2.1 AA準拠のコントラスト比を考慮

import { Dimensions, PixelRatio } from 'react-native';

const { width: SCREEN_WIDTH, height: SCREEN_HEIGHT } = Dimensions.get('window');

// iPad判定
export const isTablet = SCREEN_WIDTH >= 768;

// スケーリング関数（iPadでの適切なサイズ調整）
const scale = SCREEN_WIDTH / 375; // iPhone 8基準
export const normalize = (size: number): number => {
    const newSize = size * scale;
    // iPadでは大きくなりすぎないよう制限
    return Math.round(PixelRatio.roundToNearestPixel(
        isTablet ? Math.min(newSize, size * 1.3) : newSize
    ));
};

// カラーパレット（コントラスト比改善）
export const COLORS = {
    // プライマリカラー
    primary: '#4CAF50',       // メイングリーン
    primaryDark: '#388E3C',
    primaryLight: '#C8E6C9',

    // セカンダリカラー
    secondary: '#2196F3',     // ブルー
    secondaryDark: '#1976D2',
    secondaryLight: '#BBDEFB',

    // テキストカラー（コントラスト比4.5:1以上）
    textPrimary: '#212121',   // 主要テキスト（コントラスト比15.7:1）
    textSecondary: '#424242', // 二次テキスト（コントラスト比10.5:1）
    textTertiary: '#616161',  // 補助テキスト（コントラスト比6.1:1）
    textPlaceholder: '#9E9E9E', // プレースホルダー
    textDisabled: '#BDBDBD',
    textOnDark: '#FFFFFF',

    // 背景カラー
    background: '#F5F7FA',
    backgroundCard: '#FFFFFF',
    backgroundModal: 'rgba(0, 0, 0, 0.5)',

    // ボーダーカラー
    border: '#E0E0E0',
    borderLight: '#EEEEEE',
    borderDark: '#BDBDBD',

    // ステータスカラー
    success: '#4CAF50',
    successLight: '#E8F5E9',
    warning: '#FF9800',
    warningLight: '#FFF3E0',
    error: '#F44336',
    errorLight: '#FFEBEE',
    info: '#2196F3',
    infoLight: '#E3F2FD',

    // ダークモード用（将来拡張）
    dark: {
        background: '#121212',
        backgroundCard: '#1E1E1E',
        textPrimary: '#FFFFFF',
        textSecondary: '#B3B3B3',
        border: '#333333',
    },
};

// フォントサイズ（アクセシビリティ考慮：最小14px）
export const FONT_SIZE = {
    xs: normalize(14),        // 最小（ヘルパーテキスト）
    sm: normalize(15),        // 小さめ
    md: normalize(16),        // 標準本文
    lg: normalize(18),        // やや大きめ
    xl: normalize(20),        // 大きめ
    xxl: normalize(24),       // ヘッダータイトル
    xxxl: normalize(32),      // 大見出し
    display: normalize(48),   // メトリクス表示用
};

// フォントウェイト
export const FONT_WEIGHT = {
    normal: '400' as const,
    medium: '500' as const,
    semibold: '600' as const,
    bold: '700' as const,
};

// 間隔（8pxグリッド）
export const SPACING = {
    xs: 4,
    sm: 8,
    md: 12,
    lg: 16,
    xl: 20,
    xxl: 24,
    xxxl: 32,
};

// タップ領域の最小サイズ（アクセシビリティガイドライン準拠）
export const TAP_TARGET = {
    minSize: 48,              // 最小タップ領域（48dp = 約9mm）
    minSpacing: 8,            // タップ領域間の最小間隔
    hitSlop: {                // TouchableOpacity用のhitSlop
        top: 8,
        bottom: 8,
        left: 8,
        right: 8,
    },
};

// ボーダー半径
export const BORDER_RADIUS = {
    sm: 4,
    md: 8,
    lg: 12,
    xl: 16,
    round: 999,               // 完全に丸い
};

// シャドウ（iOS/Android共通）
export const SHADOW = {
    sm: {
        shadowColor: '#000',
        shadowOffset: { width: 0, height: 1 },
        shadowOpacity: 0.05,
        shadowRadius: 2,
        elevation: 1,
    },
    md: {
        shadowColor: '#000',
        shadowOffset: { width: 0, height: 2 },
        shadowOpacity: 0.08,
        shadowRadius: 4,
        elevation: 2,
    },
    lg: {
        shadowColor: '#000',
        shadowOffset: { width: 0, height: 4 },
        shadowOpacity: 0.12,
        shadowRadius: 8,
        elevation: 4,
    },
};

// iPad対応のレイアウト
export const LAYOUT = {
    // コンテンツの最大幅（iPadで広がりすぎないよう制限）
    maxContentWidth: 600,
    // パディング
    screenPadding: isTablet ? 32 : 20,
    // カードのパディング
    cardPadding: isTablet ? 20 : 16,
};

// 共通スタイル
export const COMMON_STYLES = {
    // 標準的なボタン
    button: {
        minHeight: TAP_TARGET.minSize,
        paddingHorizontal: SPACING.xl,
        paddingVertical: SPACING.md,
        borderRadius: BORDER_RADIUS.lg,
        alignItems: 'center' as const,
        justifyContent: 'center' as const,
    },
    // プライマリボタン
    primaryButton: {
        backgroundColor: COLORS.primary,
    },
    primaryButtonText: {
        color: COLORS.textOnDark,
        fontSize: FONT_SIZE.lg,
        fontWeight: FONT_WEIGHT.bold,
    },
    // セカンダリボタン
    secondaryButton: {
        backgroundColor: COLORS.secondary,
    },
    // カード
    card: {
        backgroundColor: COLORS.backgroundCard,
        borderRadius: BORDER_RADIUS.lg,
        padding: LAYOUT.cardPadding,
        ...SHADOW.md,
    },
    // 入力フィールド
    input: {
        backgroundColor: COLORS.backgroundCard,
        borderWidth: 1,
        borderColor: COLORS.border,
        borderRadius: BORDER_RADIUS.md,
        padding: SPACING.md,
        fontSize: FONT_SIZE.md,
        minHeight: TAP_TARGET.minSize,
    },
    // ラベル
    label: {
        fontSize: FONT_SIZE.md,
        fontWeight: FONT_WEIGHT.semibold,
        color: COLORS.textPrimary,
        marginBottom: SPACING.sm,
    },
    // ヘルパーテキスト
    helperText: {
        fontSize: FONT_SIZE.xs,
        color: COLORS.textTertiary,
        marginTop: SPACING.xs,
    },
    // エラーテキスト
    errorText: {
        fontSize: FONT_SIZE.xs,
        color: COLORS.error,
        marginTop: SPACING.xs,
    },
};
