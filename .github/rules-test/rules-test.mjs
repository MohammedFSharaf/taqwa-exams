import { initializeTestEnvironment, assertFails, assertSucceeds } from "@firebase/rules-unit-testing";
import { readFileSync } from "node:fs";
import { doc, getDoc, setDoc, collection, getDocs, deleteDoc } from "firebase/firestore";

const env = await initializeTestEnvironment({
  projectId: "demo-taqwa",
  firestore: { rules: readFileSync("firestore.rules", "utf8"), host: "127.0.0.1", port: 8080 },
});
let fails = 0;
async function t(name, p){ try { await p; console.log("OK  ", name); } catch(e){ fails++; console.log("FAIL", name, e.message); } }

await env.withSecurityRulesDisabled(async c => {
  const db = c.firestore();
  await setDoc(doc(db, "students/s1"), { name: "أحمد", halaqaId: "h1", status: "approved" });
  await setDoc(doc(db, "halaqat/h1"), { name: "حلقة" });
  await setDoc(doc(db, "sheikhs/k1"), { name: "شيخ", halaqaId: "h1" });
  await setDoc(doc(db, "settings/app"), { sessionDays: [6,0,2,4] });
  await setDoc(doc(db, "secrets/app"), { password: "1234" });
  await setDoc(doc(db, "secrets/pins"), { k1: "5555" });
});
const admin = env.authenticatedContext("adminuid", { email: "admin@taqwa.com" }).firestore();
const anon = env.authenticatedContext("anon1").firestore();
const dev = env.authenticatedContext("dev1").firestore();
const shd = env.authenticatedContext("dev2").firestore();
const nobody = env.unauthenticatedContext().firestore();

// ---- قبل التفعيل (لا يوجد secrets/security)
await t("pre: anon reads students", assertSucceeds(getDocs(collection(anon, "students"))));
await t("pre: anon writes log", assertSucceeds(setDoc(doc(anon, "logs/s1_2026-11-23"), { studentId: "s1", date: "2026-11-23" })));
await t("pre: unauth cannot read", assertFails(getDocs(collection(nobody, "students"))));
await t("anon cannot read secrets", assertFails(getDoc(doc(anon, "secrets/app"))));
await t("admin reads secrets", assertSucceeds(getDoc(doc(admin, "secrets/app"))));
await t("pending student ok", assertSucceeds(setDoc(doc(anon, "students/p1"), { name: "طالب جديد", status: "pending", halaqaId: "h1" })));
await t("pending long name denied", assertFails(setDoc(doc(anon, "students/p2"), { name: "x".repeat(101), status: "pending", halaqaId: "h1" })));
// ---- تسجيل الأجهزة
await t("wrong pass denied", assertFails(setDoc(doc(dev, "devices/dev1"), { pass: "0000", role: "examiner" })));
await t("other uid denied", assertFails(setDoc(doc(dev, "devices/dev9"), { pass: "1234", role: "examiner" })));
await t("right pass ok", assertSucceeds(setDoc(doc(dev, "devices/dev1"), { pass: "1234", role: "examiner" })));
await t("name merge ok", assertSucceeds(setDoc(doc(dev, "devices/dev1"), { name: "مختبر" }, { merge: true })));
await t("wrong pin denied", assertFails(setDoc(doc(shd, "devices/dev2"), { sheikhId: "k1", pin: "1111", role: "sheikh" })));
await t("unknown sheikh denied", assertFails(setDoc(doc(shd, "devices/dev2"), { sheikhId: "kX", pin: "5555", role: "sheikh" })));
await t("right pin ok", assertSucceeds(setDoc(doc(shd, "devices/dev2"), { sheikhId: "k1", pin: "5555", role: "sheikh" })));
await t("device reads own", assertSucceeds(getDoc(doc(dev, "devices/dev1"))));
await t("device cannot read other", assertFails(getDoc(doc(dev, "devices/dev2"))));
await t("device cannot delete self", assertFails(deleteDoc(doc(dev, "devices/dev1"))));
await t("admin lists devices", assertSucceeds(getDocs(collection(admin, "devices"))));

// ---- بعد التفعيل
await env.withSecurityRulesDisabled(async c => { await setDoc(doc(c.firestore(), "secrets/security"), { enforce: true }); });
await t("enforced: anon cannot read students", assertFails(getDocs(collection(anon, "students"))));
await t("enforced: anon cannot write log", assertFails(setDoc(doc(anon, "logs/s1_2026-11-24"), { studentId: "s1" })));
await t("enforced: anon cannot read settings", assertFails(getDoc(doc(anon, "settings/app"))));
await t("enforced: anon reads sheikh names", assertSucceeds(getDocs(collection(anon, "sheikhs"))));
await t("enforced: anon reads halaqat", assertSucceeds(getDocs(collection(anon, "halaqat"))));
await t("enforced: device reads students", assertSucceeds(getDocs(collection(dev, "students"))));
await t("enforced: sheikh device writes log", assertSucceeds(setDoc(doc(shd, "logs/s1_2026-11-24"), { studentId: "s1", date: "2026-11-24" })));
await t("enforced: anon registers with right pass", assertSucceeds(setDoc(doc(anon, "devices/anon1"), { pass: "1234", role: "examiner" })));
await t("enforced: then reads students", assertSucceeds(getDocs(collection(anon, "students"))));
await t("enforced: admin reads all", assertSucceeds(getDocs(collection(admin, "logs"))));
// ---- إلغاء الاعتماد
await t("admin revokes", assertSucceeds(deleteDoc(doc(admin, "devices/dev1"))));
await t("revoked cannot read", assertFails(getDocs(collection(dev, "students"))));
// ---- تغيير كلمة السر: الجهاز القديم لا يستطيع إعادة التسجيل بالقديمة
await env.withSecurityRulesDisabled(async c => { await setDoc(doc(c.firestore(), "secrets/app"), { password: "9999" }); });
await t("old pass re-register denied", assertFails(setDoc(doc(dev, "devices/dev1"), { pass: "1234", role: "examiner" })));
await t("new pass ok", assertSucceeds(setDoc(doc(dev, "devices/dev1"), { pass: "9999", role: "examiner" })));

await env.cleanup();
console.log(fails ? `RULES TESTS FAILED: ${fails}` : "ALL RULES TESTS PASSED");
process.exit(fails ? 1 : 0);
