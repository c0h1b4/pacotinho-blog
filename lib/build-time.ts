export function getBuildDate(): Date {
  const sourceDateEpoch = process.env.SOURCE_DATE_EPOCH;
  if (sourceDateEpoch === undefined) {
    return new Date();
  }
  if (!/^(0|[1-9][0-9]*)$/.test(sourceDateEpoch)) {
    throw new Error("SOURCE_DATE_EPOCH must be a non-negative integer");
  }

  const milliseconds = Number(sourceDateEpoch) * 1000;
  const date = new Date(milliseconds);
  if (!Number.isSafeInteger(milliseconds) || Number.isNaN(date.getTime())) {
    throw new Error("SOURCE_DATE_EPOCH is outside the supported date range");
  }
  return date;
}
