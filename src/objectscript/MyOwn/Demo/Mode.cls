/// Public demo mode (MYOWN_DEMO_MODE=1). In this mode a confirmation may act only on the
/// synthetic targets of MyOwn.Demo.Target (seeded tasks, users and roles), and it changes only
/// those records: IRIS itself is never changed by a confirmation. Portal routes that change the
/// real system (users, roles, web applications, tasks) are refused for everyone.
/// <p>Settings come from the environment only. Tests may override the mode for the current
/// process through ^||MyOwnDemo("mode").</p>
Class MyOwn.Demo.Mode
{

Parameter DemoRole = "MyOwnDemo";

Parameter DemoResource = "MyOwn.Demo";

Parameter DEFAULTRESETHOURS = 6;

Parameter DEFAULTSIMULATIONSPERMINUTE = 6;

ClassMethod Enabled() As %Boolean
{
    Quit +$Get(^||MyOwnDemo("mode"), ($ZStrip($System.Util.GetEnviron("MYOWN_DEMO_MODE"), "<>WC") = "1"))
}

/// The signed-in user holds the demo role (and is not a portal administrator).
ClassMethod IsDemoUser() As %Boolean
{
    If ##class(MyOwn.Service.Access).CanManage() Quit 0
    Quit ($ListFind($ListFromString($Roles), ..#DemoRole) > 0) && $System.Security.Check(..#DemoResource, "USE")
}

/// Hours between automatic resets of the synthetic state (1 to 168).
ClassMethod ResetHours() As %Integer
{
    Quit ..Bounded("MYOWN_DEMO_RESET_HOURS", ..#DEFAULTRESETHOURS, 1, 168)
}

/// Demonstration scenarios allowed per minute for one client address and for one session.
ClassMethod SimulationsPerMinute() As %Integer
{
    Quit ..Bounded("MYOWN_DEMO_SIMULATIONS_PER_MINUTE", ..#DEFAULTSIMULATIONSPERMINUTE, 1, 120)
}

ClassMethod Bounded(name As %String, default As %Integer, minimum As %Integer, maximum As %Integer) As %Integer [ Private ]
{
    Set value = $ZStrip($System.Util.GetEnviron(name), "<>WC")
    If (value = "") || (value '? 1.N) Quit default
    Quit $Select(+value < minimum: minimum, +value > maximum: maximum, 1: +value)
}

}
