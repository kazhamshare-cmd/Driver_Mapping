import React, { useState } from 'react';
import { View, Text, TextInput, TouchableOpacity, StyleSheet, SafeAreaView, Alert, KeyboardAvoidingView, Platform, ScrollView } from 'react-native';

export default function ManualEntryScreen({ navigation }: any) {
    const [distance, setDistance] = useState('');
    const [cargo, setCargo] = useState('');

    const handleSubmit = () => {
        Alert.alert(
            '送信確認',
            '入力した内容で日報を送信しますか？',
            [
                { text: '修正する', style: 'cancel' },
                {
                    text: '送信する',
                    onPress: () => {
                        Alert.alert('完了', '日報が送信されました', [
                            { text: 'OK', onPress: () => navigation.navigate('ModeSelection') }
                        ]);
                    }
                }
            ]
        );
    };

    return (
        <SafeAreaView style={styles.container}>
            <KeyboardAvoidingView behavior={Platform.OS === 'ios' ? 'padding' : 'height'} style={{ flex: 1 }}>
                <ScrollView contentContainerStyle={styles.content}>
                    <Text style={styles.title}>手入力モード</Text>
                    <Text style={styles.subtitle}>本日の業務実績を入力してください</Text>

                    <View style={styles.formGroup}>
                        <Text style={styles.label}>走行距離 (km)</Text>
                        <TextInput
                            style={styles.input}
                            placeholder="例: 120.5"
                            keyboardType="decimal-pad"
                            value={distance}
                            onChangeText={setDistance}
                        />
                        <Text style={styles.helper}>※ 車両のメーターを確認して入力</Text>
                    </View>

                    <View style={styles.formGroup}>
                        <Text style={styles.label}>輸送量 (トン)</Text>
                        <TextInput
                            style={styles.input}
                            placeholder="例: 4.5"
                            keyboardType="decimal-pad"
                            value={cargo}
                            onChangeText={setCargo}
                        />
                    </View>

                    <TouchableOpacity style={styles.submitButton} onPress={handleSubmit}>
                        <Text style={styles.submitButtonText}>確定して送信</Text>
                    </TouchableOpacity>

                    <TouchableOpacity style={styles.cancelButton} onPress={() => navigation.goBack()}>
                        <Text style={styles.cancelButtonText}>戻る</Text>
                    </TouchableOpacity>
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
    content: {
        padding: 24,
    },
    title: {
        fontSize: 24,
        fontWeight: 'bold',
        color: '#333',
        marginBottom: 8,
        textAlign: 'center',
    },
    subtitle: {
        fontSize: 14,
        color: '#666',
        marginBottom: 32,
        textAlign: 'center',
    },
    formGroup: {
        marginBottom: 24,
    },
    label: {
        fontSize: 16,
        fontWeight: 'bold',
        color: '#333',
        marginBottom: 8,
    },
    input: {
        backgroundColor: 'white',
        borderRadius: 12,
        padding: 16,
        fontSize: 24,
        borderWidth: 1,
        borderColor: '#ddd',
        textAlign: 'center',
        fontWeight: 'bold',
    },
    helper: {
        fontSize: 12,
        color: '#888',
        marginTop: 4,
    },
    submitButton: {
        backgroundColor: '#2196F3', // Primary Blue
        padding: 20,
        borderRadius: 999,
        alignItems: 'center',
        marginTop: 24,
        shadowColor: '#2196F3',
        shadowOffset: { width: 0, height: 4 },
        shadowOpacity: 0.3,
        shadowRadius: 8,
        elevation: 5,
    },
    submitButtonText: {
        color: 'white',
        fontSize: 18,
        fontWeight: 'bold',
    },
    cancelButton: {
        padding: 16,
        alignItems: 'center',
        marginTop: 16,
    },
    cancelButtonText: {
        color: '#666',
        fontSize: 16,
    },
});
