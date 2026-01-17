import React, { useState } from 'react';
import {
    View,
    Text,
    TextInput,
    TouchableOpacity,
    StyleSheet,
    Alert,
    SafeAreaView,
    ScrollView,
    ActivityIndicator,
    KeyboardAvoidingView,
    Platform,
} from 'react-native';
import { authService } from '../services/authService';

export default function RegisterScreen({ navigation }: any) {
    const [companyCode, setCompanyCode] = useState('');
    const [name, setName] = useState('');
    const [email, setEmail] = useState('');
    const [password, setPassword] = useState('');
    const [confirmPassword, setConfirmPassword] = useState('');
    const [loading, setLoading] = useState(false);

    const handleRegister = async () => {
        // Validation
        if (!companyCode || !name || !email || !password) {
            Alert.alert('エラー', '全ての項目を入力してください');
            return;
        }

        if (password.length < 6) {
            Alert.alert('エラー', 'パスワードは6文字以上で入力してください');
            return;
        }

        if (password !== confirmPassword) {
            Alert.alert('エラー', 'パスワードが一致しません');
            return;
        }

        setLoading(true);
        try {
            await authService.registerWithCompanyCode(companyCode, name, email, password);
            Alert.alert(
                '登録完了',
                'アカウントが作成されました',
                [{ text: 'OK', onPress: () => navigation.replace('ModeSelection') }]
            );
        } catch (error: any) {
            Alert.alert('登録エラー', error.message || '登録に失敗しました');
        } finally {
            setLoading(false);
        }
    };

    return (
        <SafeAreaView style={styles.container}>
            <KeyboardAvoidingView
                behavior={Platform.OS === 'ios' ? 'padding' : 'height'}
                style={styles.keyboardView}
            >
                <ScrollView
                    contentContainerStyle={styles.scrollContent}
                    keyboardShouldPersistTaps="handled"
                >
                    <View style={styles.content}>
                        <Text style={styles.title}>LogiTrace</Text>
                        <Text style={styles.subtitle}>ドライバー新規登録</Text>

                        <View style={styles.form}>
                            <Text style={styles.description}>
                                管理者から受け取った会社コードを入力して登録してください
                            </Text>

                            <Text style={styles.label}>会社コード</Text>
                            <TextInput
                                style={styles.input}
                                placeholder="例: ABC12345"
                                value={companyCode}
                                onChangeText={setCompanyCode}
                                autoCapitalize="characters"
                                maxLength={8}
                            />

                            <Text style={styles.label}>お名前</Text>
                            <TextInput
                                style={styles.input}
                                placeholder="山田 太郎"
                                value={name}
                                onChangeText={setName}
                            />

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
                                placeholder="6文字以上"
                                value={password}
                                onChangeText={setPassword}
                                secureTextEntry
                            />

                            <Text style={styles.label}>パスワード（確認）</Text>
                            <TextInput
                                style={styles.input}
                                placeholder="もう一度入力"
                                value={confirmPassword}
                                onChangeText={setConfirmPassword}
                                secureTextEntry
                            />

                            <TouchableOpacity
                                style={[styles.button, loading && styles.buttonDisabled]}
                                onPress={handleRegister}
                                disabled={loading}
                            >
                                {loading ? (
                                    <ActivityIndicator color="white" />
                                ) : (
                                    <Text style={styles.buttonText}>登録する</Text>
                                )}
                            </TouchableOpacity>

                            <TouchableOpacity
                                style={styles.backButton}
                                onPress={() => navigation.goBack()}
                            >
                                <Text style={styles.backButtonText}>ログイン画面に戻る</Text>
                            </TouchableOpacity>
                        </View>
                    </View>
                </ScrollView>
            </KeyboardAvoidingView>
        </SafeAreaView>
    );
}

const styles = StyleSheet.create({
    container: {
        flex: 1,
        backgroundColor: '#F5F7FA',
    },
    keyboardView: {
        flex: 1,
    },
    scrollContent: {
        flexGrow: 1,
    },
    content: {
        flex: 1,
        padding: 24,
        justifyContent: 'center',
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
        marginBottom: 32,
    },
    form: {
        gap: 12,
    },
    description: {
        fontSize: 14,
        color: '#666',
        textAlign: 'center',
        marginBottom: 16,
        backgroundColor: '#E8F5E9',
        padding: 12,
        borderRadius: 8,
    },
    label: {
        fontSize: 14,
        fontWeight: 'bold',
        color: '#444',
        marginBottom: 4,
        marginTop: 8,
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
        borderRadius: 999,
        alignItems: 'center',
        marginTop: 24,
        shadowColor: '#000',
        shadowOffset: { width: 0, height: 2 },
        shadowOpacity: 0.1,
        shadowRadius: 4,
        elevation: 3,
    },
    buttonDisabled: {
        opacity: 0.6,
    },
    buttonText: {
        color: 'white',
        fontSize: 18,
        fontWeight: 'bold',
    },
    backButton: {
        padding: 16,
        alignItems: 'center',
        marginTop: 8,
    },
    backButtonText: {
        color: '#666',
        fontSize: 14,
    },
});
