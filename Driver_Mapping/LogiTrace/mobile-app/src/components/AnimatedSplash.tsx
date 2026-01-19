// AnimatedSplash.tsx
// ふわっとロゴが表示されるスプラッシュ画面

import React, { useEffect, useRef } from 'react';
import {
    View,
    StyleSheet,
    Animated,
    Dimensions,
    Image,
} from 'react-native';
import * as SplashScreen from 'expo-splash-screen';

// スプラッシュ画面を自動非表示にしない
SplashScreen.preventAutoHideAsync();

interface AnimatedSplashProps {
    children: React.ReactNode;
    isReady: boolean;
}

const { width } = Dimensions.get('window');
const LOGO_WIDTH = Math.min(width * 0.6, 280);

export default function AnimatedSplash({ children, isReady }: AnimatedSplashProps) {
    const fadeAnim = useRef(new Animated.Value(0)).current;
    const splashOpacity = useRef(new Animated.Value(1)).current;
    const [showChildren, setShowChildren] = React.useState(false);

    useEffect(() => {
        // ロゴをふわっとフェードイン
        Animated.timing(fadeAnim, {
            toValue: 1,
            duration: 800,
            useNativeDriver: true,
        }).start();
    }, []);

    useEffect(() => {
        if (isReady) {
            // アプリ準備完了後、少し待ってからスプラッシュをフェードアウト
            const timer = setTimeout(() => {
                // スプラッシュ画面をフェードアウト
                Animated.timing(splashOpacity, {
                    toValue: 0,
                    duration: 400,
                    useNativeDriver: true,
                }).start(async () => {
                    // ネイティブスプラッシュを非表示
                    await SplashScreen.hideAsync();
                    setShowChildren(true);
                });
            }, 500); // 0.5秒待機

            return () => clearTimeout(timer);
        }
    }, [isReady]);

    if (showChildren) {
        return <>{children}</>;
    }

    return (
        <View style={styles.container}>
            {/* 背景に子コンポーネントを配置（フェードイン用） */}
            <View style={styles.childrenContainer}>
                {children}
            </View>

            {/* スプラッシュオーバーレイ */}
            <Animated.View
                style={[
                    styles.splashContainer,
                    { opacity: splashOpacity }
                ]}
            >
                <Animated.View style={{ opacity: fadeAnim }}>
                    <Image
                        source={require('../../assets/b19_logo.png')}
                        style={styles.logo}
                        resizeMode="contain"
                    />
                </Animated.View>
            </Animated.View>
        </View>
    );
}

const styles = StyleSheet.create({
    container: {
        flex: 1,
    },
    childrenContainer: {
        flex: 1,
    },
    splashContainer: {
        ...StyleSheet.absoluteFillObject,
        backgroundColor: '#FFFFFF',
        justifyContent: 'center',
        alignItems: 'center',
    },
    logo: {
        width: LOGO_WIDTH,
        height: LOGO_WIDTH * 0.4, // アスペクト比を維持
    },
});
