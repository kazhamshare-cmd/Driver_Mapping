import React from 'react';
import { NavigationContainer } from '@react-navigation/native';
import { createNativeStackNavigator } from '@react-navigation/native-stack';
import LoginScreen from './src/screens/LoginScreen';
import RegisterScreen from './src/screens/RegisterScreen';
import ModeSelectionScreen from './src/screens/ModeSelectionScreen';
import GpsTrackingScreen from './src/screens/GpsTrackingScreen';
import ManualEntryScreen from './src/screens/ManualEntryScreen';
import TenkoScreen from './src/screens/TenkoScreen';
import InspectionScreen from './src/screens/InspectionScreen';
import DriverProfileScreen from './src/screens/DriverProfileScreen';
import AlertsScreen from './src/screens/AlertsScreen';
import OperationInstructionScreen from './src/screens/OperationInstructionScreen';

const Stack = createNativeStackNavigator();

export default function App() {
  return (
    <NavigationContainer>
      <Stack.Navigator initialRouteName="Login">
        <Stack.Screen
          name="Login"
          component={LoginScreen}
          options={{ headerShown: false }}
        />
        <Stack.Screen
          name="Register"
          component={RegisterScreen}
          options={{ headerShown: false }}
        />
        <Stack.Screen
          name="ModeSelection"
          component={ModeSelectionScreen}
          options={{
            title: 'LogiTrace',
            headerStyle: { backgroundColor: '#F5F7FA' },
            headerTintColor: '#333',
          }}
        />
        <Stack.Screen
          name="GpsTracking"
          component={GpsTrackingScreen}
          options={{ headerShown: false }}
        />
        <Stack.Screen
          name="ManualEntry"
          component={ManualEntryScreen}
          options={{
            title: '日報入力',
            headerStyle: { backgroundColor: '#F5F7FA' },
          }}
        />
        <Stack.Screen
          name="Tenko"
          component={TenkoScreen}
          options={{
            title: '点呼',
            headerStyle: { backgroundColor: '#F5F7FA' },
          }}
        />
        <Stack.Screen
          name="Inspection"
          component={InspectionScreen}
          options={{
            title: '日常点検',
            headerStyle: { backgroundColor: '#F5F7FA' },
          }}
        />
        <Stack.Screen
          name="DriverProfile"
          component={DriverProfileScreen}
          options={{
            title: '運転者台帳',
            headerStyle: { backgroundColor: '#F5F7FA' },
          }}
        />
        <Stack.Screen
          name="Alerts"
          component={AlertsScreen}
          options={{
            title: '通知・アラート',
            headerStyle: { backgroundColor: '#F5F7FA' },
          }}
        />
        <Stack.Screen
          name="OperationInstruction"
          component={OperationInstructionScreen}
          options={{
            headerShown: false,
          }}
        />
      </Stack.Navigator>
    </NavigationContainer>
  );
}
