import {getFirestore, Timestamp} from 'firebase-admin/firestore';
import {HttpsError, onCall} from 'firebase-functions/v2/https';

/** Read-only, bounded, authenticated context; no model-supplied authority. */
export const getAiContext = onCall({enforceAppCheck: process.env.FUNCTIONS_EMULATOR !== 'true'}, async request => {
  const uid = request.auth?.uid;
  if (!uid) throw new HttpsError('unauthenticated', 'Masuk terlebih dahulu.');
  const siteId = request.data?.siteId;
  if (typeof siteId !== 'string' || !/^[\w-]{1,100}$/.test(siteId))
    throw new HttpsError('invalid-argument', 'Site tidak valid.');
  const db = getFirestore();
  const member = (await db.doc(`sites/${siteId}/members/${uid}`).get()).data();
  const user = (await db.doc(`users/${uid}`).get()).data();
  if (user?.active !== true || member?.active !== true || !member.permissions?.includes('dashboard.view'))
    throw new HttpsError('permission-denied', 'Tidak memiliki akses ke site ini.');
  const now = Timestamp.now();
  const bucket = db.doc(`aiUsage/${uid}_${siteId}_${Math.floor(now.toMillis() / 60000)}`);
  await db.runTransaction(async tx => {
    const previous = (await tx.get(bucket)).data();
    if ((previous?.count ?? 0) >= 6) throw new HttpsError('resource-exhausted', 'Batas konteks per menit tercapai.');
    tx.set(bucket, {count: (previous?.count ?? 0) + 1, expiresAt: Timestamp.fromMillis(now.toMillis() + 86400000)});
  });
  const site = (await db.doc(`sites/${siteId}`).get()).data();
  const devices = await db.collection('devices').where('siteId', '==', siteId).limit(15).get();
  const readings = [];
  for (const device of devices.docs) {
    const latest = (await db.doc(`telemetryLatest/${device.id}`).get()).data();
    const at = latest?.recordedAt instanceof Timestamp ? latest.recordedAt.toDate() : null;
    const age = at ? now.toMillis() - at.getTime() : Infinity;
    readings.push({deviceId: device.id, name: device.data().name, mode: device.data().mode,
      recordedAt: at?.toISOString() ?? null,
      dataState: age < -60000 ? 'INVALID_TIME' : age > 21600000 ? 'OFFLINE' : age > 300000 ? 'STALE'
        : latest?.source === 'SIMULATION' ? 'SIMULATION' : 'LIVE',
      quality: latest?.quality ?? 'MISSING',
      upstreamCm: latest?.upstreamCm ?? null, downstreamCm: latest?.downstreamCm ?? null,
      flowLiterPerSecond: latest?.flowLiterPerSecond ?? null});
  }
  const rules = await db.collection('waterRules').where('siteId', '==', siteId).where('status', '==', 'PUBLISHED').limit(5).get();
  const activeRules = rules.docs.filter(d => {
    const r = d.data(); return r.effectiveFrom instanceof Timestamp && r.effectiveTo instanceof Timestamp
      && r.effectiveFrom.toMillis() <= now.toMillis() && r.effectiveTo.toMillis() > now.toMillis();
  }).map(d => ({id: d.id, version: d.data().version, schedule: d.data().scheduleLabel,
    parumanReference: d.data().parumanReference, allocationShare: d.data().allocationShare}));
  const alerts = await db.collection('alerts').where('siteId', '==', siteId).where('acknowledged', '==', false).limit(10).get();
  return {siteId, siteName: site?.name ?? siteId, capturedAt: now.toDate().toISOString(), readings,
    activeRules, alerts: alerts.docs.map(d => ({id: d.id, title: d.data().title, severity: d.data().severity})),
    source: 'AUTHORIZED_FIRESTORE_CONTEXT', truncation: 'Max 15 devices, 5 published rules, 10 open alerts; no raw archive or other sites.'};
});
