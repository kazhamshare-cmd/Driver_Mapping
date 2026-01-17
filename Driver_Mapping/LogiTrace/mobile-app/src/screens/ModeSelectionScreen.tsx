import React, { useState, useEffect } from 'react';
import { View, Text, TouchableOpacity, StyleSheet, SafeAreaView, ScrollView, Alert } from 'react-native';
import { useNavigation } from '@react-navigation/native';
import { authService, User } from '../services/authService';

export default function ModeSelectionScreen() {
    const navigation = useNavigation();
    const [user, setUser] = useState<User | null>(null);

    useEffect(() => {
        loadUser();
    }, []);

    const loadUser = async () => {
        const userData = await authService.getUser();
        setUser(userData);
    };

    const handleLogout = () => {
        Alert.alert(
            'ログアウト',
            'ログアウトしますか？',
            [
                { text: 'キャンセル', style: 'cancel' },
                {
                    text: 'ログアウト',
                    style: 'destructive',
                    onPress: async () => {
                        await authService.logout();
                        (navigation as any).replace('Login');
                    }
                }
            ]
        );
    };

    return (
        <SafeAreaView style={styles.container}>
            <ScrollView contentContainerStyle={styles.content}>
                {user && (
                    <View style={styles.userInfo}>
                        <Text style={styles.userName}>{user.name} さん</Text>
                        <TouchableOpacity onPress={handleLogout}>
                            <Text style={styles.logoutText}>ログアウト</Text>
                        </TouchableOpacity>
                    </View>
                )}
                <Text style={styles.headerTitle}>今日の記録方法は？</Text>
                <Text style={styles.headerSubtitle}>以下から選んで勤務を開始してください</Text>

                {/* コンプライアンス（点呼・点検） */}
                <Text style={styles.sectionHeader}>乗務前チェック</Text>

                <TouchableOpacity
                    style={[styles.card, styles.cardCompliance]}
                    onPress={() => (navigation as any).navigate('Tenko', { tenkoType: 'pre' })}
                >
                    <View style={[styles.iconCircle, { backgroundColor: '#FFF3E0' }]}>
                        <Text style={{ fontSize: 32 }}>📋</Text>
                    </View>
                    <View style={styles.textContainer}>
                        <Text style={styles.cardTitle}>乗務前点呼</Text>
                        <Text style={styles.cardDesc}>
                            健康状態・アルコールチェックを記録します。
                        </Text>
                    </View>
                    <View style={styles.arrow}>
                        <Text style={{ color: '#FF9800', fontWeight: 'bold' }}>実施 ＞</Text>
                    </View>
                </TouchableOpacity>

                <TouchableOpacity
                    style={[styles.card, styles.cardInspection]}
                    onPress={() => (navigation as any).navigate('Inspection')}
                >
                    <View style={[styles.iconCircle, { backgroundColor: '#FCE4EC' }]}>
                        <Text style={{ fontSize: 32 }}>🚚</Text>
                    </View>
                    <View style={styles.textContainer}>
                        <Text style={styles.cardTitle}>車両点検</Text>
                        <Text style={styles.cardDesc}>
                            日常点検15項目をチェックします。
                        </Text>
                    </View>
                    <View style={styles.arrow}>
                        <Text style={{ color: '#E91E63', fontWeight: 'bold' }}>実施 ＞</Text>
                    </View>
                </TouchableOpacity>

                <Text style={styles.sectionHeader}>業務記録</Text>

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

                <Text style={styles.sectionHeader}>乗務後チェック</Text>

                <TouchableOpacity
                    style={[styles.card, styles.cardCompliancePost]}
                    onPress={() => (navigation as any).navigate('Tenko', { tenkoType: 'post' })}
                >
                    <View style={[styles.iconCircle, { backgroundColor: '#E8EAF6' }]}>
                        <Text style={{ fontSize: 32 }}>📝</Text>
                    </View>
                    <View style={styles.textContainer}>
                        <Text style={styles.cardTitle}>乗務後点呼</Text>
                        <Text style={styles.cardDesc}>
                            乗務終了後の状態を記録します。
                        </Text>
                    </View>
                    <View style={styles.arrow}>
                        <Text style={{ color: '#3F51B5', fontWeight: 'bold' }}>実施 ＞</Text>
                    </View>
                </TouchableOpacity>

                <Text style={styles.sectionHeader}>マイページ</Text>

                <TouchableOpacity
                    style={[styles.card, styles.cardProfile]}
                    onPress={() => (navigation as any).navigate('DriverProfile')}
                >
                    <View style={[styles.iconCircle, { backgroundColor: '#E0F7FA' }]}>
                        <Text style={{ fontSize: 32 }}>👤</Text>
                    </View>
                    <View style={styles.textContainer}>
                        <Text style={styles.cardTitle}>運転者台帳</Text>
                        <Text style={styles.cardDesc}>
                            免許情報・健康診断・研修履歴を確認できます。
                        </Text>
                    </View>
                    <View style={styles.arrow}>
                        <Text style={{ color: '#00BCD4', fontWeight: 'bold' }}>確認 ＞</Text>
                    </View>
                </TouchableOpacity>

                <TouchableOpacity
                    style={[styles.card, styles.cardAlerts]}
                    onPress={() => (navigation as any).navigate('Alerts')}
                >
                    <View style={[styles.iconCircle, { backgroundColor: '#FFEBEE' }]}>
                        <Text style={{ fontSize: 32 }}>🔔</Text>
                    </View>
                    <View style={styles.textContainer}>
                        <Text style={styles.cardTitle}>通知・アラート</Text>
                        <Text style={styles.cardDesc}>
                            期限切れ警告や重要なお知らせを確認できます。
                        </Text>
                    </View>
                    <View style={styles.arrow}>
                        <Text style={{ color: '#F44336', fontWeight: 'bold' }}>確認 ＞</Text>
                    </View>
                </TouchableOpacity>

                <Text style={styles.footerNote}>
                    ※ 法令により点呼・点検は必須です。
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
    cardCompliance: {
        borderColor: '#FFF3E0', // Subtle orange border
    },
    cardInspection: {
        borderColor: '#FCE4EC', // Subtle pink border
    },
    cardCompliancePost: {
        borderColor: '#E8EAF6', // Subtle indigo border
    },
    cardProfile: {
        borderColor: '#E0F7FA', // Subtle cyan border
    },
    cardAlerts: {
        borderColor: '#FFEBEE', // Subtle red border
    },
    sectionHeader: {
        fontSize: 14,
        fontWeight: '600',
        color: '#666',
        marginBottom: 12,
        marginTop: 8,
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
    userInfo: {
        flexDirection: 'row',
        justifyContent: 'space-between',
        alignItems: 'center',
        marginBottom: 24,
        paddingBottom: 16,
        borderBottomWidth: 1,
        borderBottomColor: '#E0E0E0',
    },
    userName: {
        fontSize: 16,
        fontWeight: '600',
        color: '#333',
    },
    logoutText: {
        fontSize: 14,
        color: '#F44336',
    },
});
