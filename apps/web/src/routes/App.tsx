import { Route, Routes } from 'react-router-dom';
import { Toaster } from 'sonner';
import DashboardPage from '../pages/DashboardPage';
import AuthPage from '../pages/AuthPage';
import AppLayout from '../components/AppLayout';
import ErrorBoundary from '../components/ErrorBoundary';

const App = () => {
  return (
    <ErrorBoundary>
      <AppLayout>
        <Routes>
          <Route path="/auth" element={<AuthPage />} />
          <Route path="/*" element={<DashboardPage />} />
        </Routes>
        <Toaster position="bottom-right" richColors />
      </AppLayout>
    </ErrorBoundary>
  );
};

export default App;
