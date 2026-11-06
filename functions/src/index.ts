import { createHash } from "crypto";
import { initializeApp } from "firebase-admin/app";
import { FieldValue, Timestamp, getFirestore } from "firebase-admin/firestore";
import { HttpsError, onCall } from "firebase-functions/v2/https";
import { onSchedule } from "firebase-functions/v2/scheduler";
import { setGlobalOptions } from "firebase-functions/v2";

initializeApp();
const db = getFirestore();

setGlobalOptions({ region: "asia-southeast2", maxInstances: 10 });

const PERM = {
  command: "gate.command",
  acknowledge: "alert.acknowledge",
  manageRules: "rule.manage",
  approveRules: "rule.approve",
} as const;

interface Membership {
  role: string;
  permissions: string[];
}

async function requireMembership(siteId: string, uid: string): Promise<Membership> {
  const profile = (await db.doc(`users/${uid}`).get()).data();
  if (profile?.active !== true) throw new HttpsError("permission-denied", "Akun tidak aktif.");
  const snap = await db.doc(`sites/${siteId}/members/${uid}`).get();
  if (!snap.exists || snap.data()?.active !== true) {
    throw new HttpsError("permission-denied", "Anda bukan anggota situs ini.");
  }
  const data = snap.data() ?? {};
  return {
    role: String(data.role ?? ""),
    permissions: Array.isArray(data.permissions) ? (data.permissions as string[]) : [],
  };
}

function requirePermission(member: Membership, permission: string): void {
  if (!member.permissions.includes(permission)) {
    throw new HttpsError("permission-denied", `Izin ${permission} diperlukan.`);
  }
}

function requireAuth(auth: { uid?: string } | undefined): string {
  if (!auth?.uid) {
    throw new HttpsError("unauthenticated", "Autentikasi diperlukan.");
  }
  return auth.uid;
}

async function audit(event: {
  siteId: string;
  actorUid: string;
  action: string;
  target: string;
  result: string;
  reason?: string;
}): Promise<void> {
  await db.collection("auditEvents").add({
    ...event,
    source: "FUNCTION",
    createdAt: FieldValue.serverTimestamp(),
  });
}

/**
 * Membuat command pintu. Klien tidak pernah menulis koleksi commands.
 * Dispatch fisik dilakukan Cloud Run command-dispatcher, bukan di sini.
 */
export const createGateCommand = onCall({enforceAppCheck: process.env.FUNCTIONS_EMULATOR !== "true"}, async (request) => {
  requireAuth(request.auth);
  throw new HttpsError("failed-precondition", "Aktuasi fisik belum diaktifkan pada foundation. Gunakan simulasi lokal; dispatcher dan interlock belum dikomisioning.");
});

export const acknowledgeAlert = onCall({enforceAppCheck: process.env.FUNCTIONS_EMULATOR !== "true"}, async (request) => {
  const uid = requireAuth(request.auth);
  const alertId = String((request.data as Record<string, unknown>).alertId ?? "");
  const ref = db.doc(`alerts/${alertId}`);
  const snap = await ref.get();
  if (!snap.exists) {
    throw new HttpsError("not-found", "Alert tidak ditemukan.");
  }
  const alert = snap.data() ?? {};
  const siteId = String(alert.siteId ?? "");
  const member = await requireMembership(siteId, uid);
  requirePermission(member, PERM.acknowledge);

  await db.runTransaction(async tx => {
    const current = (await tx.get(ref)).data();
    if (!current || current.acknowledged === true) return;
    tx.update(ref, {acknowledged: true, acknowledgedBy: uid, acknowledgedAt: FieldValue.serverTimestamp()});
    tx.create(db.collection("auditEvents").doc(), {siteId, actorUid: uid,
      action: "alert.acknowledge", target: alertId, result: "OK", source: "FUNCTION", createdAt: FieldValue.serverTimestamp()});
  });
  return { ok: true };
});

export const createWaterRuleDraft = onCall({enforceAppCheck: process.env.FUNCTIONS_EMULATOR !== "true"}, async (request) => {
  const uid = requireAuth(request.auth);
  const data = request.data as Record<string, unknown>;
  const siteId = String(data.siteId ?? "");
  const member = await requireMembership(siteId, uid);
  requirePermission(member, PERM.manageRules);

  const share = Number(data.allocationShare);
  if (!Number.isFinite(share) || share <= 0 || share > 1) {
    throw new HttpsError("invalid-argument", "Porsi alokasi harus 0-1.");
  }

  const ref = db.collection("waterRules").doc();
  await ref.set({
    siteId,
    tempek: String(data.tempek ?? ""),
    version: 1,
    status: "DRAFT",
    allocationShare: share,
    scheduleLabel: String(data.scheduleLabel ?? ""),
    parumanReference: String(data.parumanReference ?? ""),
    effectiveFrom: Timestamp.fromDate(new Date(String(data.effectiveFrom))),
    effectiveTo: Timestamp.fromDate(new Date(String(data.effectiveTo))),
    createdBy: uid,
    createdAt: FieldValue.serverTimestamp(),
    updatedAt: FieldValue.serverTimestamp(),
  });
  return { ruleId: ref.id, status: "DRAFT" };
});

export const submitWaterRule = onCall({enforceAppCheck: process.env.FUNCTIONS_EMULATOR !== "true"}, async (request) => {
  const uid = requireAuth(request.auth);
  const ruleId = String((request.data as Record<string, unknown>).ruleId ?? "");
  const ref = db.doc(`waterRules/${ruleId}`);
  const snap = await ref.get();
  if (!snap.exists) {
    throw new HttpsError("not-found", "Aturan tidak ditemukan.");
  }
  const rule = snap.data() ?? {};
  const member = await requireMembership(String(rule.siteId), uid);
  requirePermission(member, PERM.manageRules);
  if (rule.status !== "DRAFT") {
    throw new HttpsError("failed-precondition", "Hanya draf yang dapat diajukan.");
  }
  await ref.update({ status: "SUBMITTED", updatedAt: FieldValue.serverTimestamp() });
  return { ok: true, status: "SUBMITTED" };
});

/**
 * Menyetujui dan menerbitkan aturan. Aturan terbit bersifat immutable:
 * versi lama diarsipkan ke subkoleksi versions, dokumen aktif naik versi.
 */
export const approveWaterRule = onCall({enforceAppCheck: process.env.FUNCTIONS_EMULATOR !== "true"}, async (request) => {
  const uid = requireAuth(request.auth);
  const ruleId = String((request.data as Record<string, unknown>).ruleId ?? "");
  const ref = db.doc(`waterRules/${ruleId}`);
  const snap = await ref.get();
  if (!snap.exists) {
    throw new HttpsError("not-found", "Aturan tidak ditemukan.");
  }
  const rule = snap.data() ?? {};
  const member = await requireMembership(String(rule.siteId), uid);
  requirePermission(member, PERM.approveRules);
  if (member.role !== "pekaseh") {
    throw new HttpsError(
      "permission-denied",
      "Hanya Pekaseh yang boleh menyetujui aturan air.",
    );
  }
  if (rule.status !== "SUBMITTED" && rule.status !== "APPROVED") {
    throw new HttpsError("failed-precondition", "Aturan belum diajukan.");
  }

  const currentVersion = Number(rule.version ?? 1);
  await ref.collection("versions").doc(String(currentVersion)).set({
    ...rule,
    archivedAt: FieldValue.serverTimestamp(),
    archivedBy: uid,
  });
  await ref.update({
    status: "PUBLISHED",
    version: currentVersion + 1,
    approvedBy: uid,
    approvedAt: FieldValue.serverTimestamp(),
    updatedAt: FieldValue.serverTimestamp(),
  });
  await audit({
    siteId: String(rule.siteId),
    actorUid: uid,
    action: "rule.publish",
    target: ruleId,
    result: "PUBLISHED",
  });
  return { ok: true, version: currentVersion + 1 };
});

/** Recompute hash chain; angka & format harus sama dengan klien Dart. */
export const verifyLedger = onCall({enforceAppCheck: process.env.FUNCTIONS_EMULATOR !== "true"}, async (request) => {
  const uid = requireAuth(request.auth);
  const siteId = String((request.data as Record<string, unknown>).siteId ?? "");
  await requireMembership(siteId, uid);

  const snap = await db
    .collection("waterLedger")
    .where("siteId", "==", siteId)
    .orderBy("recordedAt", "asc")
    .limit(1000)
    .get();

  let prev = "GENESIS";
  for (const doc of snap.docs) {
    const data = doc.data();
    if (data.prevHash !== prev) {
      return { valid: false, brokenEntryId: doc.id, checked: snap.size };
    }
    const payload = canonicalJson({
      id: doc.id,
      siteId: data.siteId,
      tempek: data.tempek,
      gateId: data.gateId,
      ruleId: data.ruleId,
      ruleVersion: data.ruleVersion,
      recordedAt: (data.recordedAt as Timestamp).toDate().toISOString(),
      volumeCubicMeter: Number(data.volumeCubicMeter).toFixed(3),
      actor: data.actor,
      source: data.source,
      ...(data.correctionOf ? { correctionOf: data.correctionOf } : {}),
    });
    const expected = createHash("sha256").update(`${prev}|${payload}`).digest("hex");
    if (expected !== data.hash) {
      return { valid: false, brokenEntryId: doc.id, checked: snap.size };
    }
    prev = expected;
  }
  return { valid: true, checked: snap.size };
});

function canonicalJson(value: unknown): string {
  if (value === null || value === undefined) {
    return "null";
  }
  if (Array.isArray(value)) {
    return `[${value.map(canonicalJson).join(",")}]`;
  }
  if (typeof value === "object") {
    const obj = value as Record<string, unknown>;
    const keys = Object.keys(obj).sort();
    return `{${keys.map((k) => `${JSON.stringify(k)}:${canonicalJson(obj[k])}`).join(",")}}`;
  }
  return JSON.stringify(value);
}

/** Tandai command yang melewati batas waktu; tidak pernah dikirim ulang. */
export const expireCommands = onSchedule("every 5 minutes", async () => {
  const now = Timestamp.now();
  const stale = await db
    .collection("commands")
    .where("status", "in", ["CREATED", "VALIDATING", "QUEUED", "SENT"])
    .where("expiresAt", "<", now)
    .limit(200)
    .get();

  for (const doc of stale.docs) {
    await doc.ref.update({
      status: "EXPIRED",
      updatedAt: now,
      failureReason: "expiresAt terlewati",
    });
    await audit({
      siteId: String(doc.data().siteId ?? ""),
      actorUid: "system",
      action: "command.expire",
      target: doc.id,
      result: "EXPIRED",
    });
  }
});

export {getAiContext} from './ai_context';
