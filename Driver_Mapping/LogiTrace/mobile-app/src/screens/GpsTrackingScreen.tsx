import React, { useState, useEffect, useRef } from 'react';
import { View, Text, TouchableOpacity, StyleSheet, SafeAreaView, Alert, Platform } from 'react-native';
import * as Location from 'expo-location';

export default function GpsTrackingScreen({ navigation }: any) {
    const [duration, setDuration] = useState(0);
    const [distance, setDistance] = useState(0); // in meters
    const [status, setStatus] = useState('waiting'); // waiting, tracking, paused
    const [currentLocation, setCurrentLocation] = useState<Location.LocationObject | null>(null);
    const [routeCoordinates, setRouteCoordinates] = useState<Location.LocationObject[]>([]);

    const timerRef = useRef<NodeJS.Timeout | null>(null);
    const locationSubscription = useRef<Location.LocationSubscription | null>(null);

    // Manual Haversine to avoid dependency for MVP
    const calculateDistance = (lat1: number, lon1: number, lat2: number, lon2: number) => {
        const R = 6371e3; // metres
        const φ1 = lat1 * Math.PI / 180; // φ, λ in radians
        const φ2 = lat2 * Math.PI / 180;
        const Δφ = (lat2 - lat1) * Math.PI / 180;
        const Δλ = (lon2 - lon1) * Math.PI / 180;

        const a = Math.sin(Δφ / 2) * Math.sin(Δφ / 2) +
            Math.cos(φ1) * Math.cos(φ2) *
            Math.sin(Δλ / 2) * Math.sin(Δλ / 2);
        const c = 2 * Math.atan2(Math.sqrt(a), Math.sqrt(1 - a));

        return R * c;
    }

    const startTracking = async () => {
        let { status } = await Location.requestForegroundPermissionsAsync();
        if (status !== 'granted') {
            Alert.alert('許可が必要です', 'GPS追跡を行うには位置情報の許可が必要です。');
            return;
        }

        setStatus('tracking');
        setDuration(0);
        setDistance(0);
        setRouteCoordinates([]);

        // Start Timer
        timerRef.current = setInterval(() => {
            setDuration(prev => prev + 1);
        }, 1000);

        // Start Location Updates
        locationSubscription.current = await Location.watchPositionAsync(
            {
                accuracy: Location.Accuracy.High,
                timeInterval: 5000,
                distanceInterval: 10,
            },
            (location) => {
                setCurrentLocation(location);
                setRouteCoordinates(prev => {
                    const lastLoc = prev[prev.length - 1];
                    let newDist = 0;
                    if (lastLoc) {
                        newDist = calculateDistance(
                            lastLoc.coords.latitude, lastLoc.coords.longitude,
                            location.coords.latitude, location.coords.longitude
                        );
                    }
                    if (newDist > 0) {
                        setDistance(d => d + newDist);
                    }
                    return [...prev, location];
                });
            }
        );
    };

    const stopTracking = () => {
        if (timerRef.current) clearInterval(timerRef.current);
        if (locationSubscription.current) locationSubscription.current.remove();
        setStatus('stopped');

        Alert.alert(
            '勤務終了',
            `お疲れ様でした。\n走行距離: ${(distance / 1000).toFixed(2)} km\n勤務時間: ${formatTime(duration)}`,
            [
                {
                    text: 'データを送信して終了',
                    onPress: () => {
                        // TODO: Send data to API
                        navigation.navigate('ModeSelection');
                    }
                }
            ]
        );
    };

    useEffect(() => {
        startTracking();
        return () => {
            if (timerRef.current) clearInterval(timerRef.current);
            if (locationSubscription.current) locationSubscription.current.remove();
        };
    }, []);

    const formatTime = (seconds: number) => {
        const h = Math.floor(seconds / 3600);
        const m = Math.floor((seconds % 3600) / 60);
        const s = seconds % 60;
        return `${h.toString().padStart(2, '0')}:${m.toString().padStart(2, '0')}:${s.toString().padStart(2, '0')}`;
    };

    const handleStop = () => {
        Alert.alert(
            '勤務終了',
            '勤務を終了してデータを送信しますか？',
            [
                { text: 'キャンセル', style: 'cancel' },
                {
                    text: '終了する',
                    style: 'destructive',
                    onPress: stopTracking
                }
            ]
        );
    };

    return (
        <SafeAreaView style={styles.container}>
            <View style={styles.content}>
                <View style={styles.statusContainer}>
                    <View style={[styles.blinkingDot, { opacity: status === 'tracking' ? 1 : 0.5 }]} />
                    <Text style={styles.statusText}>
                        {status === 'tracking' ? 'GPS記録中' : '待機中...'}
                    </Text>
                </View>

                <View style={styles.metricsContainer}>
                    <Text style={styles.metricLabel}>経過時間</Text>
                    <Text style={styles.metricValue}>{formatTime(duration)}</Text>

                    <Text style={styles.metricLabel}>走行距離（推定）</Text>
                    <Text style={styles.metricValue}>{(distance / 1000).toFixed(2)} km</Text>
                </View>

                <View style={styles.locationContainer}>
                    <Text style={styles.locationLabel}>現在地 (緯度/経度)</Text>
                    <Text style={styles.locationValue}>
                        {currentLocation
                            ? `${currentLocation.coords.latitude.toFixed(4)}, ${currentLocation.coords.longitude.toFixed(4)}`
                            : '位置情報取得中...'}
                    </Text>
                    <Text style={{ fontSize: 12, color: '#aaa', marginTop: 4 }}>
                        精度: {currentLocation ? `±${currentLocation.coords.accuracy?.toFixed(1)}m` : '-'}
                    </Text>
                </View>

                <TouchableOpacity style={styles.stopButton} onPress={handleStop}>
                    <Text style={styles.stopButtonText}>勤務終了</Text>
                </TouchableOpacity>
            </View>
        </SafeAreaView>
    );
}

const styles = StyleSheet.create({
    container: {
        flex: 1,
        backgroundColor: '#fff',
    },
    content: {
        flex: 1,
        padding: 24,
        alignItems: 'center',
        justifyContent: 'space-between',
    },
    statusContainer: {
        flexDirection: 'row',
        alignItems: 'center',
        backgroundColor: '#E8F5E9',
        paddingHorizontal: 20,
        paddingVertical: 10,
        borderRadius: 999,
        marginTop: 20,
    },
    blinkingDot: {
        width: 12,
        height: 12,
        borderRadius: 6,
        backgroundColor: '#4CAF50',
        marginRight: 8,
    },
    statusText: {
        color: '#4CAF50',
        fontWeight: 'bold',
        fontSize: 16,
    },
    metricsContainer: {
        alignItems: 'center',
        width: '100%',
    },
    metricLabel: {
        fontSize: 14,
        color: '#666',
        marginBottom: 4,
        marginTop: 32,
    },
    metricValue: {
        fontSize: 48,
        fontWeight: 'bold',
        color: '#333',
        fontVariant: ['tabular-nums'],
    },
    locationContainer: {
        width: '100%',
        padding: 16,
        backgroundColor: '#F5F5F5',
        borderRadius: 12,
    },
    locationLabel: {
        fontSize: 12,
        color: '#888',
        marginBottom: 4,
    },
    locationValue: {
        fontSize: 16,
        color: '#333',
    },
    stopButton: {
        width: '100%',
        backgroundColor: '#F44336', // Warning Red
        padding: 24,
        borderRadius: 16,
        alignItems: 'center',
        marginBottom: 20,
        shadowColor: '#F44336',
        shadowOffset: { width: 0, height: 4 },
        shadowOpacity: 0.3,
        shadowRadius: 8,
        elevation: 5,
    },
    stopButtonText: {
        color: 'white',
        fontSize: 24,
        fontWeight: 'bold',
    },
});
