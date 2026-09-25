Class MyOwn.Service.Security Extends %RegisteredObject
{

/// Returns security configuration metadata only. Secret values, passwords,
/// tokens, certificates, and private keys are intentionally never returned.
ClassMethod GetInventory(Output inventory As %DynamicObject) As %Status
{
    Set tSC = $$$OK
    Set inventory = {}
    Set inventory.errors = []
    Try {
        Set tSC = ..GetCertificates(.items)
        If $$$ISERR(tSC) Do ..RecordError(inventory.errors, "Certificates", tSC) Set items = []
        Set inventory.certificates = items

        Set tSC = ..GetOAuthConfigurations(.items)
        If $$$ISERR(tSC) Do ..RecordError(inventory.errors, "OAuth", tSC) Set items = []
        Set inventory.oauth = items

        Set tSC = ..GetWalletCollections(.items)
        If $$$ISERR(tSC) Do ..RecordError(inventory.errors, "Wallet collections", tSC) Set items = []
        Set inventory.walletCollections = items

        Set tSC = ..GetWalletSecrets(.items)
        If $$$ISERR(tSC) Do ..RecordError(inventory.errors, "Wallet secrets", tSC) Set items = []
        Set inventory.walletSecrets = items

        Set tSC = ..GetCredentialReferences(.items)
        If $$$ISERR(tSC) Do ..RecordError(inventory.errors, "Credentials", tSC) Set items = []
        Set inventory.credentials = items
        Set tSC = $$$OK
    } Catch exception {
        Set tSC = exception.AsStatus()
    }
    Quit tSC
}

/// Adds a short, single-line explanation for an inventory that could not be read,
/// so that a failure is shown to the administrator instead of looking like "no data".
ClassMethod RecordError(errors As %DynamicArray, category As %String, status As %Status) As %Status [ Private ]
{
    Set text = $System.Status.GetErrorText(status)
    Set text = $Translate(text, $Char(13, 10, 9), "   ")
    Set entry = {}
    Set entry.category = category
    Set entry.message = $Extract(text, 1, 160)
    Do errors.%Push(entry)
    Quit $$$OK
}

/// Return category counts and the current user's native security access.
ClassMethod GetSummary(Output summary As %DynamicObject) As %Status
{
    Set tSC = ..GetInventory(.inventory)
    If $$$ISERR(tSC) Quit tSC

    Set summary = {}
    Set summary.certificates = inventory.certificates.%Size()
    Set summary.oauth = inventory.oauth.%Size()
    Set summary.walletCollections = inventory.walletCollections.%Size()
    Set summary.walletSecrets = inventory.walletSecrets.%Size()
    Set summary.credentials = inventory.credentials.%Size()
    Set summary.protectedItems = summary.walletCollections + summary.walletSecrets + summary.credentials
    Set summary.canReadSecurity = $System.Security.Check("%Admin_Secure", "USE")
    Set summary.canUseWallet = $System.Security.Check("%Admin_Wallet", "USE")
    Set summary.mode = "Read-only metadata"
    Quit $$$OK
}

/// Return one sanitized inventory item without material that could be used as a secret.
ClassMethod GetDetail(category As %String, name As %String, type As %String, Output detail As %DynamicObject) As %Status
{
    Set tSC = ..GetInventory(.inventory)
    If $$$ISERR(tSC) Quit tSC

    Set detail = {}
    Set found = 0
    Set collectionNames = $ListBuild("certificates", "oauth", "walletCollections", "walletSecrets", "credentials")
    For collectionIndex = 1:1:$ListLength(collectionNames) {
        Set collection = inventory.%Get($List(collectionNames, collectionIndex))
        For itemIndex = 0:1:collection.%Size() - 1 {
            Set item = collection.%Get(itemIndex)
            If (item.category = category) && (item.name = name) && ((type = "") || (item.type = type)) {
                Set detail.name = item.name
                Set detail.category = item.category
                Set detail.type = item.type
                Set detail.status = item.status
                Set detail.issuer = item.issuer
                Set detail.validFrom = item.validFrom
                Set detail.expiresAt = item.expiresAt
                Set detail.association = item.association
                Set detail.detail = item.detail
                Set detail.redacted = 1
                Set detail.mode = "Read-only metadata"
                Set detail.safetyNotice = ..SafetyNotice(item.category)
                Set found = 1
                Quit
            }
        }
        If found Quit
    }
    If 'found Quit $$$ERROR($$$GeneralError, "The security item was not found.")
    Quit $$$OK
}

ClassMethod GetCategory(category As %String, Output items As %DynamicArray) As %Status
{
    If category = "certificates" Quit ..GetCertificates(.items)
    If category = "oauth" Quit ..GetOAuthConfigurations(.items)
    If category = "credentials" {
        Set tSC = ..GetInventory(.inventory)
        If $$$ISERR(tSC) Quit tSC
        Set items = []
        Do ..AppendItems(items, inventory.walletCollections)
        Do ..AppendItems(items, inventory.walletSecrets)
        Do ..AppendItems(items, inventory.credentials)
        Quit $$$OK
    }
    Quit $$$ERROR($$$GeneralError, "Unknown security category.")
}

ClassMethod AppendItems(target As %DynamicArray, source As %DynamicArray) As %Status [ Private ]
{
    For index = 0:1:source.%Size() - 1 Do target.%Push(source.%Get(index))
    Quit $$$OK
}

ClassMethod SafetyNotice(category As %String) As %String [ Private ]
{
    If category = "Certificate" Quit "Certificate metadata only. Certificate contents and private keys are never returned."
    If category = "OAuth" Quit "OAuth configuration metadata only. Tokens, client secrets, and registration credentials are never returned."
    If category = "Wallet" Quit "Secure Wallet metadata only. Secret values and cryptographic key material are never read or returned."
    Quit "Credential reference metadata only. Usernames and passwords are never returned."
}

ClassMethod GetCertificates(Output items As %DynamicArray) As %Status
{
    Set tSC = $$$OK
    Set items = []
    Try {
        New $Namespace
        Set $Namespace = "%SYS"
        Set alias = ""
        For  {
            Set credential = ##class(%SYS.X509Credentials).GetNext(.alias)
            Quit:credential=""
            Set item = {}
            Set item.name = alias
            Set item.category = "Certificate"
            Set item.type = "X.509"
            Set item.status = "Configured"
            Set item.issuer = credential.IssuerDN
            Set item.validFrom = credential.ValidityNotBefore
            Set item.expiresAt = credential.ValidityNotAfter
            Set item.association = credential.PeerNames
            Set item.detail = credential.SubjectDN
            Do items.%Push(item)
        }
    } Catch exception {
        Set tSC = exception.AsStatus()
    }
    Quit tSC
}

ClassMethod GetOAuthConfigurations(Output items As %DynamicArray) As %Status
{
    Set tSC = $$$OK
    Set items = []
    Try {
        New $Namespace
        Set $Namespace = "%SYS"

        Set statement = ##class(%SQL.Statement).%New()
        Set tSC = statement.%PrepareClassQuery("OAuth2.ServerDefinition", "List")
        $$$ThrowOnError(tSC)
        Set result = statement.%Execute()
        While result.%Next() {
            Set item = {}
            Set item.name = result.%Get("IssuerEndpoint")
            Set item.category = "OAuth"
            Set item.type = "Authorization server"
            Set item.status = "Configured"
            Set item.issuer = result.%Get("IssuerEndpoint")
            Set item.validFrom = ""
            Set item.expiresAt = ""
            Set item.association = result.%Get("ClientCount") _ " clients, " _ result.%Get("ResourceCount") _ " resource servers"
            Set item.detail = "Server definition"
            Do items.%Push(item)
        }

        Set statement = ##class(%SQL.Statement).%New()
        Set tSC = statement.%PrepareClassQuery("OAuth2.Client", "List")
        $$$ThrowOnError(tSC)
        Set result = statement.%Execute()
        While result.%Next() {
            Set item = {}
            Set item.name = result.%Get("ApplicationName")
            Set item.category = "OAuth"
            Set item.type = "Client"
            Set item.status = "Configured"
            Set item.issuer = ""
            Set item.validFrom = ""
            Set item.expiresAt = ""
            Set item.association = result.%Get("DefaultScope")
            Set item.detail = result.%Get("ClientType")
            Do items.%Push(item)
        }

        Set statement = ##class(%SQL.Statement).%New()
        Set tSC = statement.%PrepareClassQuery("OAuth2.ResourceServer", "List")
        $$$ThrowOnError(tSC)
        Set result = statement.%Execute()
        While result.%Next() {
            Set item = {}
            Set item.name = result.%Get("Name")
            Set item.category = "OAuth"
            Set item.type = "Resource server"
            Set item.status = "Configured"
            Set item.issuer = result.%Get("ServerDefinition")
            Set item.validFrom = ""
            Set item.expiresAt = ""
            Set item.association = result.%Get("ServerDefinition")
            Set item.detail = "Resource server"
            Do items.%Push(item)
        }
    } Catch exception {
        Set tSC = exception.AsStatus()
    }
    Quit tSC
}

/// Secure Wallet collections. The current wallet classes are %Wallet.Collection,
/// which are SQL-projected, so a plain SELECT of names and resources is used. The
/// older %SYS.Wallet.Collection:List query is kept as a fallback.
///
/// The code is intentionally self-contained: after the namespace switch only
/// system classes are called, because routines of this class may not be mapped
/// into %SYS.
ClassMethod GetWalletCollections(Output items As %DynamicArray) As %Status
{
    Set tSC = $$$OK
    Set items = []
    Try {
        New $Namespace
        Set $Namespace = "%SYS"

        Set result = ""
        Set statement = ##class(%SQL.Statement).%New()
        Set tSC = statement.%Prepare("SELECT Name, UseResource, EditResource FROM %Wallet.Collection ORDER BY Name")
        If $$$ISOK(tSC) {
            Set candidate = statement.%Execute()
            If candidate.%SQLCODE < 0 {
                Set tSC = $$$ERROR($$$GeneralError, candidate.%Message)
            } Else {
                Set result = candidate
            }
        }
        If '$IsObject(result) {
            // Older builds expose the same data through a class query.
            Set legacy = ##class(%SQL.Statement).%New()
            If $$$ISOK(legacy.%PrepareClassQuery("%SYS.Wallet.Collection", "List")) {
                Set result = legacy.%Execute("*")
                Set tSC = $$$OK
            }
        }
        $$$ThrowOnError(tSC)

        While result.%Next() {
            Set item = {}
            Set item.name = result.%Get("Name")
            Set item.category = "Wallet"
            Set item.type = "Collection"
            Set item.status = "Protected"
            Set item.issuer = ""
            Set item.validFrom = ""
            Set item.expiresAt = ""
            Set item.association = result.%Get("UseResource")
            Set item.detail = result.%Get("EditResource")
            Do items.%Push(item)
        }
    } Catch exception {
        Set tSC = exception.AsStatus()
    }
    Quit tSC
}

/// Secure Wallet secrets. Only names and classes are selected; the Secret property
/// is transient and is never read.
ClassMethod GetWalletSecrets(Output items As %DynamicArray) As %Status
{
    Set tSC = $$$OK
    Set items = []
    Try {
        New $Namespace
        Set $Namespace = "%SYS"

        Set result = ""
        Set typeColumn = "ClassName"
        Set candidates = $ListBuild("SELECT Name, %CLASSNAME AS ClassName FROM %Wallet.Secret ORDER BY Name", "SELECT Name, '%Wallet.KeyValue' AS ClassName FROM %Wallet.KeyValue ORDER BY Name")
        For index = 1:1:$ListLength(candidates) {
            Set statement = ##class(%SQL.Statement).%New()
            Set tSC = statement.%Prepare($List(candidates, index))
            If $$$ISERR(tSC) Continue
            Set candidate = statement.%Execute()
            If candidate.%SQLCODE < 0 {
                Set tSC = $$$ERROR($$$GeneralError, candidate.%Message)
                Continue
            }
            Set result = candidate
            Quit
        }
        If '$IsObject(result) {
            // Older builds expose the same data through a class query.
            Set legacy = ##class(%SQL.Statement).%New()
            If $$$ISOK(legacy.%PrepareClassQuery("%SYS.Wallet.Secret", "List")) {
                Set result = legacy.%Execute("*", "*")
                Set typeColumn = "Type"
                Set tSC = $$$OK
            }
        }
        $$$ThrowOnError(tSC)

        While result.%Next() {
            Set className = result.%Get(typeColumn)
            Set item = {}
            Set item.name = result.%Get("Name")
            Set item.category = "Wallet"
            Set item.type = $Select(className [ "KeyValue":"Key/value secret", className [ "SymmetricKey":"Symmetric key", className [ "RSA":"RSA key", 1:"Secret reference")
            Set item.status = "Protected"
            Set item.issuer = ""
            Set item.validFrom = ""
            Set item.expiresAt = ""
            Set item.association = $Piece(item.name, ".", 1)
            Set item.detail = "Value hidden"
            Do items.%Push(item)
        }
    } Catch exception {
        Set tSC = exception.AsStatus()
    }
    Quit tSC
}

ClassMethod GetCredentialReferences(Output items As %DynamicArray) As %Status
{
    Set tSC = $$$OK
    Set items = []

    // Ens.Config.Credentials only exists -- and only has a working SQL class
    // query -- when Interoperability is properly enabled for this namespace.
    // A plain IRIS Community namespace has no such class at all; a namespace
    // where the class is merely visible through a database mapping (without
    // being fully Interoperability-enabled) can have the class compiled but
    // no matching SQL stored procedure, which fails with SQLCODE -428
    // ("stored procedure not found"). Both situations mean "no credential
    // references available here", not an error worth surfacing to the
    // administrator, so any failure below is treated the same as the class
    // not existing at all -- consistent with the class-existence check above,
    // and avoids depending on the wording of a localized error message too.
    If '##class(%Dictionary.CompiledClass).%ExistsId("Ens.Config.Credentials") Quit tSC

    Try {
        Set statement = ##class(%SQL.Statement).%New()
        Set prepStatus = statement.%PrepareClassQuery("Ens.Config.Credentials", "List")
        If $$$ISOK(prepStatus) {
            Set result = statement.%Execute()
            While result.%Next() {
                Set item = {}
                Set item.name = result.%Get("ID")
                Set item.category = "Credential"
                Set item.type = "Credential reference"
                Set item.status = "Protected"
                Set item.issuer = ""
                Set item.validFrom = ""
                Set item.expiresAt = ""
                Set item.association = result.%Get("BusinessPartner")
                Set item.detail = "Secret hidden"
                Do items.%Push(item)
            }
        }
    } Catch {
        Set items = []
    }
    Quit tSC
}

ClassMethod WalletType(className As %String) As %String
{
    If className [ "KeyValue" Quit "Key/value secret"
    If className [ "SymmetricKey" Quit "Symmetric key"
    If className [ "RSA" Quit "RSA key"
    Quit "Secret reference"
}

}
