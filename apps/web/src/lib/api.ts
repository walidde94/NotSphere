const api = async <T>(input: RequestInfo, init?: RequestInit): Promise<T> => {
  const csrfToken = document.cookie
    .split('; ')
    .find((row) => row.startsWith('notsphere_csrf='))?.split('=')[1];
  const response = await fetch(input, {
    credentials: 'include',
    headers: {
      'Content-Type': 'application/json',
      ...(csrfToken ? { 'X-CSRF-Token': csrfToken } : {}),
      ...(init?.headers || {})
    },
    ...init
  });

  if (!response.ok) {
    throw new Error(await response.text());
  }

  if (response.status === 204) {
    return undefined as T;
  }

  return response.json();
};

export default api;
