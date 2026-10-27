/// Loaded and compiled by IPM before the rest of the module (module.xml, Preload): the production
/// classes extend Ens.*, so the namespace must be interoperability-enabled before they compile.
Class MyOwn.Bootstrap
{

/// IPM, before the Compile phase. Does nothing where interoperability is already enabled.
ClassMethod EnableInteroperability() As %Status
{
    If ##class(%EnsembleMgr).IsEnsembleNamespace($Namespace) Quit $$$OK
    Write !, "MyOwn Portal: enabling interoperability in namespace ", $Namespace, " (on IRIS for Health this also loads the FHIR packages and takes a few minutes).", !
    Quit ##class(%EnsembleMgr).EnableNamespace($Namespace, 0, .isPrimary, 0, 0)
}

}
