import { Routes, Route, Navigate } from 'react-router-dom';
import Login from './pages/Login';
import Register from './pages/Register';
import Dashboard from './pages/Dashboard';
import ReportsList from './pages/ReportsList';
import Home from './pages/Home';
import Layout from './components/Layout';
import DriverList from './pages/DriverList';
import DriverSetup from './pages/DriverSetup';

// Compliance pages
import TenkoList from './pages/compliance/TenkoList';
import TenkoForm from './pages/compliance/TenkoForm';
import InspectionList from './pages/compliance/InspectionList';
import InspectionForm from './pages/compliance/InspectionForm';
import TachographImport from './pages/compliance/TachographImport';
import AuditExport from './pages/compliance/AuditExport';

// Multi-industry support pages
import DriverRegistryList from './pages/registry/DriverRegistryList';
import DriverRegistryForm from './pages/registry/DriverRegistryForm';
import DriverRegistryDetail from './pages/registry/DriverRegistryDetail';
import HealthCheckupList from './pages/health/HealthCheckupList';
import HealthCheckupForm from './pages/health/HealthCheckupForm';
import AptitudeTestList from './pages/aptitude/AptitudeTestList';
import AptitudeTestForm from './pages/aptitude/AptitudeTestForm';
import TrainingList from './pages/training/TrainingList';
import TrainingForm from './pages/training/TrainingForm';
import AccidentList from './pages/accidents/AccidentList';
import AccidentForm from './pages/accidents/AccidentForm';

// Settings pages
import ApiManagement from './pages/settings/ApiManagement';
import SubscriptionManagement from './pages/settings/SubscriptionManagement';

// Report pages
import MonthlyYearlyReports from './pages/reports/MonthlyYearlyReports';

// Bus-specific pages
import OperationInstructionList from './pages/bus/OperationInstructionList';
import OperationInstructionForm from './pages/bus/OperationInstructionForm';

// Industry context
import { IndustryProvider } from './contexts/IndustryContext';

const PrivateRoute = ({ children }: { children: React.ReactNode }) => {
  const user = localStorage.getItem('user');
  return user ? <>{children}</> : <Navigate to="/login" />;
};

function App() {
  return (
    <IndustryProvider>
      <Layout>
        <Routes>
        <Route path="/" element={<Home />} />
        <Route path="/login" element={<Login />} />
        <Route path="/register" element={<Register />} />
        <Route path="/dashboard" element={
          <PrivateRoute>
            <Dashboard />
          </PrivateRoute>
        } />
        <Route path="/reports" element={
          <PrivateRoute>
            <ReportsList />
          </PrivateRoute>
        } />
        <Route path="/drivers" element={
          <PrivateRoute>
            <DriverList />
          </PrivateRoute>
        } />
        <Route path="/driver/setup" element={<DriverSetup />} />

        {/* Compliance Routes */}
        <Route path="/compliance/tenko" element={
          <PrivateRoute>
            <TenkoList />
          </PrivateRoute>
        } />
        <Route path="/compliance/tenko/new" element={
          <PrivateRoute>
            <TenkoForm />
          </PrivateRoute>
        } />
        <Route path="/compliance/inspections" element={
          <PrivateRoute>
            <InspectionList />
          </PrivateRoute>
        } />
        <Route path="/compliance/inspections/new" element={
          <PrivateRoute>
            <InspectionForm />
          </PrivateRoute>
        } />
        <Route path="/compliance/tachograph" element={
          <PrivateRoute>
            <TachographImport />
          </PrivateRoute>
        } />
        <Route path="/compliance/audit" element={
          <PrivateRoute>
            <AuditExport />
          </PrivateRoute>
        } />

        {/* Driver Registry Routes */}
        <Route path="/registry" element={
          <PrivateRoute>
            <DriverRegistryList />
          </PrivateRoute>
        } />
        <Route path="/registry/new" element={
          <PrivateRoute>
            <DriverRegistryForm />
          </PrivateRoute>
        } />
        <Route path="/registry/:id" element={
          <PrivateRoute>
            <DriverRegistryDetail />
          </PrivateRoute>
        } />
        <Route path="/registry/:id/edit" element={
          <PrivateRoute>
            <DriverRegistryForm />
          </PrivateRoute>
        } />

        {/* Health Checkup Routes */}
        <Route path="/health" element={
          <PrivateRoute>
            <HealthCheckupList />
          </PrivateRoute>
        } />
        <Route path="/health/new" element={
          <PrivateRoute>
            <HealthCheckupForm />
          </PrivateRoute>
        } />

        {/* Aptitude Test Routes */}
        <Route path="/aptitude" element={
          <PrivateRoute>
            <AptitudeTestList />
          </PrivateRoute>
        } />
        <Route path="/aptitude/new" element={
          <PrivateRoute>
            <AptitudeTestForm />
          </PrivateRoute>
        } />

        {/* Training Routes */}
        <Route path="/training" element={
          <PrivateRoute>
            <TrainingList />
          </PrivateRoute>
        } />
        <Route path="/training/new" element={
          <PrivateRoute>
            <TrainingForm />
          </PrivateRoute>
        } />

        {/* Accident Routes */}
        <Route path="/accidents" element={
          <PrivateRoute>
            <AccidentList />
          </PrivateRoute>
        } />
        <Route path="/accidents/new" element={
          <PrivateRoute>
            <AccidentForm />
          </PrivateRoute>
        } />

        {/* Settings Routes */}
        <Route path="/settings/api" element={
          <PrivateRoute>
            <ApiManagement />
          </PrivateRoute>
        } />
        <Route path="/settings/subscription" element={
          <PrivateRoute>
            <SubscriptionManagement />
          </PrivateRoute>
        } />

        {/* Report Routes */}
        <Route path="/reports/monthly-yearly" element={
          <PrivateRoute>
            <MonthlyYearlyReports />
          </PrivateRoute>
        } />

        {/* Bus-specific Routes */}
        <Route path="/bus/operation-instructions" element={
          <PrivateRoute>
            <OperationInstructionList />
          </PrivateRoute>
        } />
        <Route path="/bus/operation-instructions/new" element={
          <PrivateRoute>
            <OperationInstructionForm />
          </PrivateRoute>
        } />
        <Route path="/bus/operation-instructions/:id" element={
          <PrivateRoute>
            <OperationInstructionForm />
          </PrivateRoute>
        } />
      </Routes>
      </Layout>
    </IndustryProvider>
  );
}

export default App;
