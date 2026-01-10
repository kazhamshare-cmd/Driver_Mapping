import React from 'react';
import { View, Text, TouchableOpacity, StyleSheet, SafeAreaView, ScrollView } from 'react-native';
import { useNavigation } from '@react-navigation/native';

export default function ModeSelectionScreen() {
    const navigation = useNavigation();
    return (
        <SafeAreaView style={styles.container}>
            <ScrollView contentContainerStyle={styles.content}>
                <Text style={styles.headerTitle}>今日の記録方法は？</Text>
                <Text style={styles.headerSubtitle}>以下から選んで勤務を開始してください</Text>

                <TouchableOpacity
                    style={[styles.card, styles.cardGps]}
                    onPress={() => (navigation as any).navigate('GpsTracking')}
                >
                    <View style={styles.iconCircle}>
                        <Text style={{ fontSize: 32 }}>📍</Text>
                    </View>
                    <View style={styles.textContainer}>
                        <Text style={styles.cardTitle}>GPSで自動記録</Text>
                        <Text style={styles.cardDesc}>
                            ボタンを押すだけで走行ルートと距離を自動で計算します。
                        </Text>
                    </View>
                    <View style={styles.arrow}>
                        <Text style={{ color: '#4CAF50', fontWeight: 'bold' }}>開始 ＞</Text>
                    </View>
                </TouchableOpacity>

                <TouchableOpacity
                    style={[styles.card, styles.cardManual]}
                    onPress={() => (navigation as any).navigate('ManualEntry')}
                >
                    <View style={[styles.iconCircle, { backgroundColor: '#E3F2FD' }]}>
                        <Text style={{ fontSize: 32 }}>✏️</Text>
                    </View>
                    <View style={styles.textContainer}>
                        <Text style={styles.cardTitle}>手入力で記録</Text>
                        <Text style={styles.cardDesc}>
                            メーターの値を確認して、勤務終了時に距離を入力します。
                        </Text>
                    </View>
                    <View style={styles.arrow}>
                        <Text style={{ color: '#2196F3', fontWeight: 'bold' }}>開始 ＞</Text>
                    </View>
                </TouchableOpacity>

                <Text style={styles.footerNote}>
                    ※ 記録方法は毎回選択できます。
                </Text>
            </ScrollView>
        </SafeAreaView>
    );
}

const styles = StyleSheet.create({
    container: {
        flex: 1,
        backgroundColor: '#F5F7FA',
    },
    content: {
        padding: 24,
    },
    headerTitle: {
        fontSize: 24,
        fontWeight: 'bold',
        color: '#333',
        marginBottom: 8,
    },
    headerSubtitle: {
        fontSize: 16,
        color: '#666',
        marginBottom: 32,
    },
    card: {
        backgroundColor: 'white',
        borderRadius: 16,
        padding: 24,
        marginBottom: 20,
        flexDirection: 'row',
        alignItems: 'center',
        shadowColor: '#000',
        shadowOffset: { width: 0, height: 2 },
        shadowOpacity: 0.05,
        shadowRadius: 8,
        elevation: 2,
        borderWidth: 2,
        borderColor: 'transparent',
    },
    cardGps: {
        borderColor: '#E8F5E9', // Subtle green border
    },
    cardManual: {
        borderColor: '#E3F2FD', // Subtle blue border
    },
    iconCircle: {
        width: 60,
        height: 60,
        borderRadius: 30,
        backgroundColor: '#E8F5E9',
        alignItems: 'center',
        justifyContent: 'center',
        marginRight: 16,
    },
    textContainer: {
        flex: 1,
    },
    cardTitle: {
        fontSize: 18,
        fontWeight: 'bold',
        color: '#333',
        marginBottom: 4,
    },
    cardDesc: {
        fontSize: 13,
        color: '#666',
        lineHeight: 18,
    },
    arrow: {
        marginLeft: 8,
    },
    footerNote: {
        textAlign: 'center',
        color: '#999',
        fontSize: 12,
        marginTop: 16,
    },
});
