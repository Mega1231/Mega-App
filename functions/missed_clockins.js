const AGENCY_TIME_ZONE = "America/Toronto";
const GRACE_MINUTES = 15;
// Shifts that started longer ago than this are ignored, so a fresh deploy
// doesn't alert on every shift that already began earlier in the day.
const LOOKBACK_MINUTES = 120;

/** Wall-clock parts of `date` in `timeZone`. */
function zonedParts(date, timeZone) {
  const parts = new Intl.DateTimeFormat("en-US", {
    timeZone,
    weekday: "short",
    year: "numeric",
    month: "2-digit",
    day: "2-digit",
    hour: "2-digit",
    minute: "2-digit",
    hourCycle: "h23",
  }).formatToParts(date);
  const get = (type) => parts.find((p) => p.type === type).value;
  return {
    weekday: get("weekday"), // "Mon"
    year: Number(get("year")),
    month: Number(get("month")),
    day: Number(get("day")),
    minutes: Number(get("hour")) * 60 + Number(get("minute")),
  };
}

/** UTC instant of local midnight for the day `date` falls on in `timeZone`. */
function startOfZonedDay(date, timeZone) {
  const p = zonedParts(date, timeZone);
  const wallAsUtc = Date.UTC(p.year, p.month - 1, p.day, 0, p.minutes);
  const offsetMs = wallAsUtc - Math.floor(date.getTime() / 60000) * 60000;
  return new Date(Date.UTC(p.year, p.month - 1, p.day) - offsetMs);
}

/** "9:00 AM" / "12:30 pm" → minutes after midnight, or null. */
function parseClockTime(text) {
  const m = /^\s*(\d{1,2}):(\d{2})\s*([AaPp][Mm])\s*$/.exec(text || "");
  if (!m) return null;
  let hour = Number(m[1]) % 12;
  if (m[3].toUpperCase() === "PM") hour += 12;
  return hour * 60 + Number(m[2]);
}

function dateKey(p) {
  const pad = (n) => String(n).padStart(2, "0");
  return `${p.year}-${pad(p.month)}-${pad(p.day)}`;
}

/** Local calendar date (y, m, d) of a Firestore Timestamp/Date in `timeZone`. */
function zonedDateKey(value, timeZone) {
  const date = typeof value?.toDate === "function" ? value.toDate() : value;
  return dateKey(zonedParts(date, timeZone));
}

/**
 * Assignments whose shift started between GRACE and LOOKBACK minutes ago today
 * and that have no clock-in today. `assignments` are {id, ...data} objects.
 */
function findMissedShifts({ now, assignments, clockedInAssignmentIds,
  timeZone = AGENCY_TIME_ZONE }) {
  const today = zonedParts(now, timeZone);
  const todayKey = dateKey(today);
  const missed = [];

  for (const a of assignments) {
    if (a.isActive === false || a.isLiveIn) continue;
    if (!String(a.schedule || "").includes(today.weekday)) continue;
    if (a.startDate && zonedDateKey(a.startDate, timeZone) > todayKey) continue;
    if (a.endDate && zonedDateKey(a.endDate, timeZone) < todayKey) continue;

    const start = parseClockTime(a.shiftStartTime);
    if (start === null) continue;
    const late = today.minutes - start;
    if (late < GRACE_MINUTES || late > LOOKBACK_MINUTES) continue;
    if (clockedInAssignmentIds.has(a.id)) continue;

    missed.push({ assignment: a, dateKey: todayKey, minutesLate: late });
  }
  return missed;
}

module.exports = {
  AGENCY_TIME_ZONE,
  GRACE_MINUTES,
  LOOKBACK_MINUTES,
  zonedParts,
  startOfZonedDay,
  parseClockTime,
  findMissedShifts,
};
