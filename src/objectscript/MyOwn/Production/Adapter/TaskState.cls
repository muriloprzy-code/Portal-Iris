/// What MyOwn.Production.Adapter.TaskHistoryInbound hands the TaskWatcher for one task worth triaging.
/// It stays inside the service job (it is not a production message), so it is not persistent.
Class MyOwn.Production.Adapter.TaskState Extends %RegisteredObject
{

Property TaskId As %Integer;

Property Name As %String(MAXLEN = "");

Property Namespace As %String;

Property Manageable As %Boolean;

Property Suspended As %Boolean;

/// Consecutive failures, newest run first.
Property Failures As %Integer;

/// Error text of the newest failed run (untrusted: written by the task).
Property LastError As %String(MAXLEN = "");

/// Whether the newest run succeeded.
Property LastOk As %Boolean;

}
