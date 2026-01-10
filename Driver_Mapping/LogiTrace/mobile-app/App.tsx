import React from 'react';
import { NavigationContainer } from '@react-navigation/native';
import { createNativeStackNavigator } from '@react-navigation/native-stack';
import LoginScreen from './src/screens/LoginScreen';
import ModeSelectionScreen from './src/screens/ModeSelectionScreen';
import GpsTrackingScreen from './src/screens/GpsTrackingScreen';
import ManualEntryScreen from './src/screens/ManualEntryScreen';

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
      </Stack.Navigator>
    </NavigationContainer>
  );
}
