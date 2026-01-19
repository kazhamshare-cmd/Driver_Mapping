// AppHeader.tsx
// 共通ヘッダーコンポーネント - 全画面で一貫したナビゲーション体験を提供

import React from 'react';
import {
    View,
    Text,
    TouchableOpacity,
    StyleSheet,
    Platform,
    StatusBar,
    useWindowDimensions,
} from 'react-native';
import { useSafeAreaInsets } from 'react-native-safe-area-context';

interface AppHeaderProps {
    title: string;
    subtitle?: string;
    onBack?: () => void;
    backLabel?: string;
    rightAction?: React.ReactNode;
    backgroundColor?: string;
    showBorder?: boolean;
    // iPad対応：大画面でのレイアウト調整
    centerTitle?: boolean;
}

export default function AppHeader({
    title,
    subtitle,
    onBack,
    backLabel = '戻る',
    rightAction,
    backgroundColor = '#FFFFFF',
    showBorder = true,
    centerTitle = false,
}: AppHeaderProps) {
    const insets = useSafeAreaInsets();
    const { width } = useWindowDimensions();

    // iPad判定（768px以上をタブレットとみなす）
    const isTablet = width >= 768;

    return (
        <View
            style={[
                styles.container,
                {
                    backgroundColor,
                    paddingTop: insets.top,
                    borderBottomWidth: showBorder ? 1 : 0,
                },
            ]}
        >
            <StatusBar barStyle="dark-content" />
            <View style={[styles.content, isTablet && styles.contentTablet]}>
                {/* 戻るボタン */}
                <View style={styles.leftContainer}>
                    {onBack && (
                        <TouchableOpacity
                            style={styles.backButton}
                            onPress={onBack}
                            hitSlop={{ top: 12, bottom: 12, left: 12, right: 12 }}
                            accessibilityLabel="戻る"
                            accessibilityRole="button"
                        >
                            <Text style={styles.backIcon}>←</Text>
                            <Text style={styles.backLabel}>{backLabel}</Text>
                        </TouchableOpacity>
                    )}
                </View>

                {/* タイトル */}
                <View style={[
                    styles.titleContainer,
                    centerTitle && styles.titleContainerCenter,
                ]}>
                    <Text
                        style={[styles.title, isTablet && styles.titleTablet]}
                        numberOfLines={1}
                        ellipsizeMode="tail"
                    >
                        {title}
                    </Text>
                    {subtitle && (
                        <Text
                            style={[styles.subtitle, isTablet && styles.subtitleTablet]}
                            numberOfLines={1}
                        >
                            {subtitle}
                        </Text>
                    )}
                </View>

                {/* 右アクション */}
                <View style={styles.rightContainer}>
                    {rightAction}
                </View>
            </View>
        </View>
    );
}

const styles = StyleSheet.create({
    container: {
        borderBottomColor: '#E0E0E0',
    },
    content: {
        flexDirection: 'row',
        alignItems: 'center',
        justifyContent: 'space-between',
        paddingHorizontal: 16,
        paddingVertical: 12,
        minHeight: 56,
    },
    contentTablet: {
        paddingHorizontal: 24,
        minHeight: 64,
    },
    leftContainer: {
        minWidth: 80,
        alignItems: 'flex-start',
    },
    backButton: {
        flexDirection: 'row',
        alignItems: 'center',
        paddingVertical: 8,
        paddingHorizontal: 4,
        // 最小タップ領域48x48dpを確保
        minHeight: 48,
        minWidth: 48,
    },
    backIcon: {
        fontSize: 20,
        color: '#2196F3',
        marginRight: 4,
        fontWeight: '600',
    },
    backLabel: {
        fontSize: 17,
        color: '#2196F3',
        fontWeight: '500',
    },
    titleContainer: {
        flex: 1,
        alignItems: 'flex-start',
        paddingHorizontal: 8,
    },
    titleContainerCenter: {
        alignItems: 'center',
    },
    title: {
        fontSize: 18,
        fontWeight: '700',
        color: '#333333',
        letterSpacing: 0.3,
    },
    titleTablet: {
        fontSize: 22,
    },
    subtitle: {
        fontSize: 13,
        color: '#666666',
        marginTop: 2,
    },
    subtitleTablet: {
        fontSize: 15,
    },
    rightContainer: {
        minWidth: 80,
        alignItems: 'flex-end',
    },
});
