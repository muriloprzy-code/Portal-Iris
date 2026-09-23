Class MeuPortal.Service.Applications
{

Parameter ProtectedApplication = "/meuportal/api";

Parameter ProtectedRoot = "/meuportal";

/// Read-only inventory of web applications through the published security API.
ClassMethod GetApplications(Output items As %DynamicArray) As %Status
{
    Set tSC = $$$OK
    Set items = []
    Try {
        New $Namespace
        Set $Namespace = "%SYS"

        Set statement = ##class(%SQL.Statement).%New()
        Set tSC = statement.%PrepareClassQuery("Security.Applications", "List")
        $$$ThrowOnError(tSC)
        Set result = statement.%Execute("*", 2, "").%NextResult()

        While result.%Next() {
            Set item = {}
            Set item.name = result.%Get("Name")
            Set item.namespace = result.%Get("Namespace")
            Set item.namespaceDefault = result.%Get("Namespace Default")
            Set item.enabled = result.%Get("Enabled")
            Set item.type = result.%Get("Type")
            Set item.resource = result.%Get("Resource")
            Set item.authenticationMethods = result.%Get("Authentication Methods")
            Set item.systemApplication = result.%Get("IsSystemApp")
            Set item.dispatchClass = result.%Get("Dispatch Class")
            Do items.%Push(item)
        }
    } Catch exception {
        Set tSC = exception.AsStatus()
    }
    Quit tSC
}

/// Return the published configuration for one web application.
ClassMethod GetApplication(application As %String, Output item As %DynamicObject) As %Status
{
    Set tSC = $$$OK
    Set item = {}
    Try {
        New $Namespace
        Set $Namespace = "%SYS"

        Set tSC = ##class(Security.Applications).Get(application, .properties)
        $$$ThrowOnError(tSC)

        Set namespace = $Get(properties("NameSpace"))
        If namespace = "" Set namespace = $Get(properties("Namespace"))
        Set reason = ..ProtectionReason(application, namespace)

        Set item.name = application
        Set item.description = $Get(properties("Description"))
        Set item.namespace = namespace
        Set item.enabled = +$Get(properties("Enabled"))
        Set item.dispatchClass = $Get(properties("DispatchClass"))
        Set item.resource = $Get(properties("Resource"))
        Set item.authenticationCode = $Get(properties("AutheEnabled"))
        Set item.cookiePath = $Get(properties("CookiePath"))
        Set item.sessionUse = $Get(properties("SessionUse"))
        Set item.namespaceDefault = +$Get(properties("IsNameSpaceDefault"))
        Set item.canManage = ..CanManage()
        Set item.manageable = (reason = "")
        Set item.protectionReason = reason
    } Catch exception {
        Set tSC = exception.AsStatus()
    }
    Quit tSC
}

/// Enable or disable a project-owned application using the published security API.
ClassMethod SetApplicationEnabled(application As %String, enabled As %Boolean, Output item As %DynamicObject) As %Status
{
    Set tSC = $$$OK
    Set item = {}
    Try {
        If '..CanManage() {
            Set tSC = $$$ERROR($$$GeneralError, "The current user cannot manage web applications.")
            $$$ThrowStatus(tSC)
        }

        New $Namespace
        Set $Namespace = "%SYS"
        Set tSC = ##class(Security.Applications).Get(application, .properties)
        $$$ThrowOnError(tSC)

        Set namespace = $Get(properties("NameSpace"))
        If namespace = "" Set namespace = $Get(properties("Namespace"))
        Set reason = ..ProtectionReason(application, namespace)
        If reason '= "" {
            Set tSC = $$$ERROR($$$GeneralError, reason)
            $$$ThrowStatus(tSC)
        }

        Kill updates
        Set updates("Enabled") = +enabled
        Set tSC = ##class(Security.Applications).Modify(application, .updates)
        $$$ThrowOnError(tSC)

        Set item.name = application
        Set item.enabled = +enabled
        Set item.action = $Select(enabled:"enabled", 1:"disabled")
    } Catch exception {
        Set tSC = exception.AsStatus()
    }
    Quit tSC
}

/// The native application API requires the %Admin_Secure resource.
ClassMethod CanManage() As %Boolean
{
    Quit $System.Security.Check("%Admin_Secure", "USE")
}

/// Keep state changes inside this project and protect every application that
/// serves the portal itself (the REST API and the static React frontend).
ClassMethod ProtectionReason(application As %String, namespace As %String) As %String [ Private ]
{
    Set lower = $ZConvert(application, "L")
    If (lower = ..#ProtectedApplication) || (lower = ..#ProtectedRoot) || ($Extract(lower, 1, $Length(..#ProtectedRoot) + 1) = (..#ProtectedRoot _ "/")) Quit "The Meu Portal applications are protected from state changes."
    If namespace '= "MEUPORTAL" Quit "Only applications in the MEUPORTAL namespace can be changed."
    Quit ""
}

}
