import { settleRewardPlan, type ProfileDocument, type RewardPlan } from "./match_rewards.ts";

/** OAuth service-account access stays on the server; no Admin key reaches a client. */
export function createFirestoreRewardStore(project: string, token: () => Promise<string>, fetcher = fetch) {
  const base = `projects/${project}/databases/(default)/documents`;
  const url = `https://firestore.googleapis.com/v1/${base}`;
  async function request(path: string, body?: unknown) {
    const authorization = await token();
    let response: Response;
    try {
      response = await fetcher(`${url}${path}`, { method: body == null ? "GET" : "POST",
        headers: { Authorization: `Bearer ${authorization}`, "Content-Type": "application/json" },
        signal: AbortSignal.timeout(5000), ...(body == null ? {} : { body: JSON.stringify(body) }) });
    } catch { throw new Error("reward_transport_failed"); }
    let data: Record<string, any>;
    try { data = await response.json(); } catch { throw new Error("reward_transport_failed"); }
    return { response, data };
  }
  function failed(status: number) {
    throw new Error(status === 403 || status === 401 ? "reward_access_denied" : "reward_store_failed");
  }
  const store = {
    async readReceipt(id: string) {
      const { response, data } = await request(`/matchRewardReceipts/${id}`);
      if (response.status === 404) return null;
      if (!response.ok) failed(response.status);
      const fingerprint = data.fields?.fingerprint?.stringValue;
      if (typeof fingerprint !== "string") throw new Error("reward_receipt_conflict");
      return fingerprint;
    },
    async readProfiles(uids: string[]) {
      return Promise.all(uids.map(async uid => {
        const { response, data } = await request(`/users/${encodeURIComponent(uid)}`);
        if (response.status === 404) throw new Error("reward_profile_missing");
        if (!response.ok) failed(response.status);
        return data as ProfileDocument;
      }));
    },
    async commit(writes: Record<string, unknown>[]) {
      const { response, data } = await request(":commit", { writes });
      if (response.ok) return;
      if (["ABORTED", "ALREADY_EXISTS", "FAILED_PRECONDITION"].includes(data.error?.status)) {
        throw new Error("reward_commit_conflict");
      }
      if ([500, 502, 503, 504].includes(response.status)) throw new Error("reward_transport_failed");
      failed(response.status);
    },
  };
  return { settle: (plan: RewardPlan) => settleRewardPlan(base, plan, store) };
}
