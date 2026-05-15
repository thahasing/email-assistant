import { useEffect } from "react";
import { insightsApi } from "../api/client";
import { useEmailStore } from "../store/emailStore";

export function useInsights() {
  const setInsights = useEmailStore((s) => s.setInsights);

  useEffect(() => {
    insightsApi.summary().then((res) => setInsights(res.data));
  }, []);
}
