/// Fixed one-minute windows in IRISTEMP, per key (client address or session). Used in demo mode
/// to cap demonstration scenarios; old windows are removed as new ones start.
Class MyOwn.Demo.RateLimit
{

/// Counts one use of key in the current minute; 0 when the limit was already reached.
ClassMethod Allow(key As %String, limit As %Integer, Output retryAfter As %Integer) As %Boolean
{
    Set now = $ZTimestamp
    Set minute = ($Piece(now, ",", 1) * 1440) + ($Piece(now, ",", 2) \ 60)
    Set retryAfter = 60 - ($Piece(now, ",", 2) # 60 \ 1)
    Set key = $Extract(key, 1, 200)
    ; Keep only the current window for this key.
    Set previous = $Order(^IRIS.Temp.MyOwnDemoRate(key, minute), -1)
    While previous '= "" {
        Kill ^IRIS.Temp.MyOwnDemoRate(key, previous)
        Set previous = $Order(^IRIS.Temp.MyOwnDemoRate(key, previous), -1)
    }
    If $Get(^IRIS.Temp.MyOwnDemoRate(key, minute)) >= limit Quit 0
    Do $Increment(^IRIS.Temp.MyOwnDemoRate(key, minute))
    Quit 1
}

/// Test helper: forget the counters of key.
ClassMethod Clear(key As %String)
{
    Kill ^IRIS.Temp.MyOwnDemoRate($Extract(key, 1, 200))
}

}
