import { createHash, timingSafeEqual } from "crypto";
import express, { Request, Response } from "express";
import { initializeApp } from "firebase-admin/app";
import { FieldValue, Timestamp, getFirestore } from "firebase-admin/firestore";
import { z } from "zod";

initializeApp();
const db = getFirestore();
const app = express();
app.use(express.json({ limit: "64kb" }));

/**
 * Kontrak uplink SUBAKO v0.2.
 * Bridge menolak payload di luar skema, bukan mencoba menebak.
 */
const UplinkSchema = z.object({
  deviceEui: z.string().min(8),
  deviceId: z.string().min(1),
  siteId: z.string().min(1),
  sequence: z.number().int().nonnegative(),
  recordedAt: z.string().datetime(),
  upstreamCm: z.number().min(0).max(500),
  downstreamCm: z.number().min(0).max(500),
  flowLiterPerSecond: z.number().min(0).max(500),
  batteryPercent: z.number().min(0).max(100).optional(),
  rssi: z.number().int().min(-200).max(0).optional(),
  snr: z.number().min(-30).max(30).optional(),
  quality: z.string().default("Tidak diketahui"),
  source: z.enum(["DEVICE", "SIMULATION"]).default("DEVICE"),
});

type Uplink = z.infer<typeof UplinkSchema>;

function authorized(req: Request): boolean {
  const expected = process.env.BRIDGE_SHARED_SECRET ?? "";
  const provided = req.header("x-bridge-token") ?? "";
  if (expected.length === 0) {
    return false;
  }
  const a = createHash("sha256").update(provided).digest();
  const b = createHash("sha256").update(expected).digest();
  return timingSafeEqual(a, b);
}

app.get("/healthz", (_req: Request, res: Response) => {
  res.json({ ok: true, service: "subako-iot-bridge" });
});

app.post("/chirpstack/uplink", async (req: Request, res: Response) => {
  if (!authorized(req)) {
    res.status(401).json({ error: "unauthorized" });
    return;
  }
  const parsed = UplinkSchema.safeParse(req.body);
  if (!parsed.success) {
    res.status(422).json({ error: "invalid_payload", issues: parsed.error.issues });
    return;
  }
  const uplink: Uplink = parsed.data;

  const deviceSnap = await db.doc(`devices/${uplink.deviceId}`).get();
  if (!deviceSnap.exists) {
    res.status(404).json({ error: "unknown_device" });
    return;
  }
  const device = deviceSnap.data() ?? {};
  if (device.siteId !== uplink.siteId || device.deviceEui !== uplink.deviceEui) {
    res.status(403).json({ error: "device_site_mismatch" });
    return;
  }

  const recordedAt = Timestamp.fromDate(new Date(uplink.recordedAt));
  const ageMs = Date.now() - recordedAt.toMillis();
  if (ageMs > 24 * 60 * 60 * 1000) {
    res.status(409).json({ error: "stale_uplink" });
    return;
  }

  await db.doc(`telemetryLatest/${uplink.deviceId}`).set(
    {
      deviceId: uplink.deviceId,
      siteId: uplink.siteId,
      upstreamCm: uplink.upstreamCm,
      downstreamCm: uplink.downstreamCm,
      flowLiterPerSecond: uplink.flowLiterPerSecond,
      batteryPercent: uplink.batteryPercent ?? null,
      rssi: uplink.rssi ?? null,
      snr: uplink.snr ?? null,
      quality: uplink.quality,
      sequence: uplink.sequence,
      recordedAt,
      source: uplink.source,
      updatedAt: FieldValue.serverTimestamp(),
    },
    { merge: true },
  );

  await db.collection("telemetryEvents").add({
    ...uplink,
    recordedAt,
    receivedAt: FieldValue.serverTimestamp(),
  });

  if ((uplink.batteryPercent ?? 100) < 20) {
    await db.collection("alerts").add({
      siteId: uplink.siteId,
      deviceId: uplink.deviceId,
      severity: "CRITICAL",
      title: `Baterai ${uplink.deviceId} kritis`,
      evidence: `Baterai ${uplink.batteryPercent}% pada ${uplink.recordedAt}.`,
      suggestedAction: "Periksa panel solar dan ganti/isi baterai.",
      raisedAt: FieldValue.serverTimestamp(),
      acknowledged: false,
      source: "IOT_BRIDGE",
    });
  }

  res.status(202).json({ ok: true });
});

const port = Number(process.env.PORT ?? 8080);
app.listen(port, () => {
  // eslint-disable-next-line no-console
  console.log(`subako-iot-bridge listening on ${port}`);
});
