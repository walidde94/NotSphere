const debounce = <T extends (...args: any[]) => void>(fn: T, delay = 300) => {
  let timeout: number | undefined;
  const debounced = (...args: Parameters<T>) => {
    window.clearTimeout(timeout);
    timeout = window.setTimeout(() => {
      fn(...args);
    }, delay);
  };
  return debounced;
};

export default debounce;
