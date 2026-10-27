/// What MyOwn.Production.Adapter.LogEntriesInbound hands the LogWatcher: the serious log entries of
/// one scan, already sanitized, as a JSON array. It stays inside the service job, so it is not persistent.
Class MyOwn.Production.Adapter.LogBatch Extends %RegisteredObject
{

Property ItemsJSON As %String(MAXLEN = "");

}
