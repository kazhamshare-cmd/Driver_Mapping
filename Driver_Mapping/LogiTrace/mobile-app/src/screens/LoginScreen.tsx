import React, { useState, useEffect } from 'react';
import { View, Text, TextInput, TouchableOpacity, StyleSheet, Alert, SafeAreaView, Linking, ActivityIndicator } from 'react-native';
import { authService } from '../services/authService';

export default function LoginScreen({ navigation }: any) {
    const [email, setEmail] = useState('');
    const [password, setPassword] = useState('');
    const [loading, setLoading] = useState(false);
    const [checkingAuth, setCheckingAuth] = useState(true);

    // Check if user is already logged in
    useEffect(() => {
        checkAuth();
    }, []);

    const checkAuth = async () => {
        try {
            const isLoggedIn = await authService.isLoggedIn();
            if (isLoggedIn) {
                navigation.replace('ModeSelection');
            }
        } catch (error) {
            console.error('Auth check failed:', error);
        } finally {
            setCheckingAuth(false);
        }
    };

    const handleLogin = async () => {
        if (!email || !password) {
            Alert.alert('エラー', 'メールアドレスとパスワードを入力してください');
            return;
        }

        setLoading(true);
        try {
            await authService.login(email, password);
            navigation.replace('ModeSelection');
        } catch (error: any) {
            Alert.alert('ログインエラー', error.message || 'ログインに失敗しました');
        } finally {
            setLoading(false);
        }
    };

    if (checkingAuth) {
        return (
            <SafeAreaView style={styles.container}>
                <View style={styles.loadingContainer}>
                    <ActivityIndicator size="large" color="#4CAF50" />
                </View>
            </SafeAreaView>
        );
    }

    return (
        <SafeAreaView style={styles.container}>
            <View style={styles.content}>
                <Text style={styles.title}>LogiTrace</Text>
                <Text style={styles.subtitle}>ドライバー用アプリ</Text>

                <View style={styles.form}>
                    <Text style={styles.label}>メールアドレス</Text>
                    <TextInput
                        style={styles.input}
                        placeholder="example@company.com"
                        value={email}
                        onChangeText={setEmail}
                        autoCapitalize="none"
                        keyboardType="email-address"
                    />

                    <Text style={styles.label}>パスワード</Text>
                    <TextInput
                        style={styles.input}
                        placeholder="••••••••"
                        value={password}
                        onChangeText={setPassword}
                        secureTextEntry
                    />

                    <TouchableOpacity
                        style={[styles.button, loading && styles.buttonDisabled]}
                        onPress={handleLogin}
                        disabled={loading}
                    >
                        {loading ? (
                            <ActivityIndicator color="white" />
                        ) : (
                            <Text style={styles.buttonText}>ログイン</Text>
                        )}
                    </TouchableOpacity>

                    <TouchableOpacity
                        style={styles.registerButton}
                        onPress={() => navigation.navigate('Register')}
                    >
                        <Text style={styles.registerButtonText}>新規登録（会社コードをお持ちの方）</Text>
                    </TouchableOpacity>

                    <View style={styles.helpContainer}>
                        <TouchableOpacity onPress={() => Linking.openURL('https://b19.co.jp/support/')}>
                            <Text style={styles.linkText}>サポート</Text>
                        </TouchableOpacity>
                        <View style={styles.divider} />
                        <TouchableOpacity onPress={() => Linking.openURL('https://b19.co.jp/terms-of-service/')}>
                            <Text style={styles.linkText}>利用規約</Text>
                        </TouchableOpacity>
                        <View style={styles.divider} />
                        <TouchableOpacity onPress={() => Linking.openURL('https://b19.co.jp/privacy-policy/')}>
                            <Text style={styles.linkText}>プライバシーポリシー</Text>
                        </TouchableOpacity>
                    </View>
                </View>
            </View>
        </SafeAreaView>
    );
}

const styles = StyleSheet.create({
    container: {
        flex: 1,
        backgroundColor: '#F5F7FA',
    },
    loadingContainer: {
        flex: 1,
        justifyContent: 'center',
        alignItems: 'center',
    },
    content: {
        flex: 1,
        justifyContent: 'center',
        padding: 24,
    },
    title: {
        fontSize: 32,
        fontWeight: 'bold',
        color: '#4CAF50',
        textAlign: 'center',
        marginBottom: 8,
    },
    subtitle: {
        fontSize: 16,
        color: '#666',
        textAlign: 'center',
        marginBottom: 48,
    },
    form: {
        gap: 16,
    },
    label: {
        fontSize: 14,
        fontWeight: 'bold',
        color: '#444',
        marginBottom: 4,
    },
    input: {
        backgroundColor: 'white',
        borderRadius: 12,
        padding: 16,
        fontSize: 16,
        borderWidth: 1,
        borderColor: '#ddd',
    },
    button: {
        backgroundColor: '#4CAF50',
        padding: 18,
        borderRadius: 999, // Pill shape
        alignItems: 'center',
        marginTop: 24,
        shadowColor: '#000',
        shadowOffset: { width: 0, height: 2 },
        shadowOpacity: 0.1,
        shadowRadius: 4,
        elevation: 3,
    },
    buttonText: {
        color: 'white',
        fontSize: 18,
        fontWeight: 'bold',
    },
    helpContainer: {
        flexDirection: 'row',
        justifyContent: 'center',
        alignItems: 'center',
        marginTop: 32,
    },
    linkText: {
        color: '#999',
        fontSize: 12,
        paddingHorizontal: 8,
    },
    divider: {
        width: 1,
        height: 12,
        backgroundColor: '#ddd',
    },
    buttonDisabled: {
        opacity: 0.6,
    },
    registerButton: {
        padding: 16,
        alignItems: 'center',
        marginTop: 16,
    },
    registerButtonText: {
        color: '#4CAF50',
        fontSize: 14,
        fontWeight: '600',
    },
});
