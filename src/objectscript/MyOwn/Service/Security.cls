Class MyOwn.Service.Security Extends %RegisteredObject
{

/// Returns security configuration metadata only. Secret values, passwords,
/// tokens, certificates, and private keys are intentionally never returned.
ClassMethod GetInventory(authorization As %String, Output inventory As %DynamicObject, Output source As %String) As %Status
{
    Set source = "sysadmin-v2"
    Quit ..GetInventoryFromSysAdmin(authorization, .inventory)
}

ClassMethod GetInventoryFromSysAdmin(authorization As %String, Output inventory As %DynamicObject) As %Status [ Private ]
{
    Set inventory = {}
    Set inventory.errors = []

    Set tSC = ..GetCertificatesFromSysAdmin(authorization, .items)
    If $$$ISERR(tSC) Do ..RecordError(inventory.errors, "Certificates", tSC) Set items = []
    Set inventory.certificates = items

    Set tSC = ..GetOAuthFromSysAdmin(authorization, .items)
    If $$$ISERR(tSC) Do ..RecordError(inventory.errors, "OAuth", tSC) Set items = []
    Set inventory.oauth = items

    Set tSC = ..GetWalletFromSysAdmin(authorization, .collections, .secrets)
    If $$$ISERR(tSC) {
        Do ..RecordError(inventory.errors, "Wallet", tSC)
        Set collections = []
        Set secrets = []
    }
    Set inventory.walletCollections = collections
    Set inventory.walletSecrets = secrets

    // SysAdmin API v2 does not expose Interoperability credential references.
    Set tSC = ..GetCredentialReferences(.items)
    If $$$ISERR(tSC) Do ..RecordError(inventory.errors, "Credentials", tSC) Set items = []
    Set inventory.credentials = items
    Quit $$$OK
}

ClassMethod GetCertificatesFromSysAdmin(authorization As %String, Output items As %DynamicArray) As %Status [ Private ]
{
    Set items = []
    Set tSC = ##class(MyOwn.Service.SysAdminClient).Request("GET", "/api/admin/v2/security/x509-credentials?maxRows=1000", authorization, "", .payload, .httpStatus)
    If $$$ISERR(tSC) Quit tSC
    Set records = payload.%Get("result")
    If '$IsObject(records) Quit $$$ERROR($$$GeneralError, "The SysAdmin certificate response did not include a result array.")
    For index = 0:1:(records.%Size() - 1) {
        Set record = records.%Get(index)
        Set alias = record.%Get("Alias")
        Set detailPath = "/api/admin/v2/security/x509-credential/certificate?alias=" _ ##class(MyOwn.Service.SysAdminClient).EncodeQueryValue(alias)
        Set detailStatus = ##class(MyOwn.Service.SysAdminClient).Request("GET", detailPath, authorization, "", .detailPayload, .detailHttpStatus)
        Set certificate = detailPayload.%Get("result")
        Set item = {}
        Set item.name = alias
        Set item.category = "Certificate"
        Set item.type = "X.509"
        Set item.status = "Configured"
        Set item.issuer = $Select($IsObject(certificate):certificate.%Get("IssuerDN"), 1:"")
        Set item.validFrom = $Select($IsObject(certificate):certificate.%Get("ValidityNotBefore"), 1:"")
        Set item.expiresAt = $Select($IsObject(certificate):certificate.%Get("ValidityNotAfter"), 1:"")
        Set item.association = ..JoinDynamicArray(record.%Get("PeerNames"))
        Set item.detail = $Select($IsObject(certificate):certificate.%Get("SubjectDN"), 1:"Certificate details unavailable")
        Do items.%Push(item)
    }
    Quit $$$OK
}

ClassMethod GetOAuthFromSysAdmin(authorization As %String, Output items As %DynamicArray) As %Status [ Private ]
{
    Set items = []
    Set tSC = ##class(MyOwn.Service.SysAdminClient).Request("GET", "/api/admin/v2/security/oauth2/client/server-definitions?maxRows=1000", authorization, "", .serverPayload, .httpStatus)
    If $$$ISERR(tSC) Quit tSC
    Set servers = serverPayload.%Get("result")
    If '$IsObject(servers) Quit $$$ERROR($$$GeneralError, "The SysAdmin OAuth server response did not include a result array.")
    For index = 0:1:(servers.%Size() - 1) {
        Set server = servers.%Get(index)
        Set serverId = server.%Get("ID")
        Set item = {}
        Set item.name = server.%Get("IssuerEndpoint")
        If item.name = "" Set item.name = serverId
        Set item.category = "OAuth"
        Set item.type = "Authorization server"
        Set item.status = "Configured"
        Set item.issuer = server.%Get("IssuerEndpoint")
        Set item.validFrom = ""
        Set item.expiresAt = ""
        Set item.association = server.%Get("ClientCount") _ " clients, " _ server.%Get("ResourceCount") _ " resource servers"
        Set item.detail = "Server definition"
        Do items.%Push(item)

        Set clientPath = "/api/admin/v2/security/oauth2/client/client-configurations?serverId=" _ ##class(MyOwn.Service.SysAdminClient).EncodeQueryValue(serverId) _ "&maxRows=1000"
        Set clientStatus = ##class(MyOwn.Service.SysAdminClient).Request("GET", clientPath, authorization, "", .clientPayload, .clientHttpStatus)
        If $$$ISOK(clientStatus) {
            Set clients = clientPayload.%Get("result")
            If $IsObject(clients) {
                For clientIndex = 0:1:(clients.%Size() - 1) {
                    Set client = clients.%Get(clientIndex)
                    Set item = {}
                    Set item.name = client.%Get("ApplicationName")
                    Set item.category = "OAuth"
                    Set item.type = "Client"
                    Set item.status = "Configured"
                    Set item.issuer = server.%Get("IssuerEndpoint")
                    Set item.validFrom = ""
                    Set item.expiresAt = ""
                    Set item.association = client.%Get("DefaultScope")
                    Set item.detail = client.%Get("ClientType")
                    Do items.%Push(item)
                }
            }
        }
    }

    Set tSC = ##class(MyOwn.Service.SysAdminClient).Request("GET", "/api/admin/v2/security/oauth2/resource-servers?maxRows=1000", authorization, "", .resourcePayload, .httpStatus)
    If $$$ISERR(tSC) Quit tSC
    Set resources = resourcePayload.%Get("result")
    If '$IsObject(resources) Quit $$$ERROR($$$GeneralError, "The SysAdmin OAuth resource-server response did not include a result array.")
    For index = 0:1:(resources.%Size() - 1) {
        Set resource = resources.%Get(index)
        Set item = {}
        Set item.name = resource.%Get("Name")
        Set item.category = "OAuth"
        Set item.type = "Resource server"
        Set item.status = "Configured"
        Set item.issuer = resource.%Get("ServerDefinition")
        Set item.validFrom = ""
        Set item.expiresAt = ""
        Set item.association = resource.%Get("ServerDefinition")
        Set item.detail = "Resource server"
        Do items.%Push(item)
    }
    Quit $$$OK
}

ClassMethod GetWalletFromSysAdmin(authorization As %String, Output collections As %DynamicArray, Output secrets As %DynamicArray) As %Status [ Private ]
{
    Set collections = []
    Set secrets = []
    Set tSC = ##class(MyOwn.Service.SysAdminClient).Request("GET", "/api/admin/v2/wallet/collections?names=*&maxRows=1000", authorization, "", .payload, .httpStatus)
    If $$$ISERR(tSC) Quit tSC
    Set records = payload.%Get("result")
    If '$IsObject(records) Quit $$$ERROR($$$GeneralError, "The SysAdmin wallet response did not include a result array.")
    For index = 0:1:(records.%Size() - 1) {
        Set record = records.%Get(index)
        Set collectionName = record.%Get("Name")
        Set item = {}
        Set item.name = collectionName
        Set item.category = "Wallet"
        Set item.type = "Collection"
        Set item.status = "Protected"
        Set item.issuer = ""
        Set item.validFrom = ""
        Set item.expiresAt = ""
        Set item.association = record.%Get("UseResource")
        Set item.detail = record.%Get("EditResource")
        Do collections.%Push(item)

        Set secretPath = "/api/admin/v2/wallet/secrets?collection=" _ ##class(MyOwn.Service.SysAdminClient).EncodeQueryValue(collectionName) _ "&maxRows=1000"
        Set secretStatus = ##class(MyOwn.Service.SysAdminClient).Request("GET", secretPath, authorization, "", .secretPayload, .secretHttpStatus)
        If $$$ISERR(secretStatus) Quit secretStatus
        Set secretRecords = secretPayload.%Get("result")
        If $IsObject(secretRecords) {
            For secretIndex = 0:1:(secretRecords.%Size() - 1) {
                Set secret = secretRecords.%Get(secretIndex)
                Set className = secret.%Get("Type")
                Set item = {}
                Set item.name = secret.%Get("Name")
                Set item.category = "Wallet"
                Set item.type = $Select(className [ "KeyValue":"Key/value secret", className [ "SymmetricKey":"Symmetric key", className [ "RSA":"RSA key", 1:"Secret reference")
                Set item.status = "Protected"
                Set item.issuer = ""
                Set item.validFrom = ""
                Set item.expiresAt = ""
                Set item.association = collectionName
                Set item.detail = "Value hidden"
                Do secrets.%Push(item)
            }
        }
    }
    Quit $$$OK
}

ClassMethod JoinDynamicArray(values As %DynamicAbstractObject) As %String [ Private ]
{
    If '$IsObject(values) Quit ""
    Set text = ""
    For index = 0:1:(values.%Size() - 1) {
        If text '= "" Set text = text _ ", "
        Set text = text _ values.%Get(index)
    }
    Quit text
}

/// Records a short inventory error without exposing implementation details.
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
ClassMethod GetSummary(authorization As %String, Output summary As %DynamicObject, Output source As %String) As %Status
{
    Set tSC = ..GetInventory(authorization, .inventory, .source)
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
ClassMethod GetDetail(category As %String, name As %String, type As %String, authorization As %String, Output detail As %DynamicObject, Output source As %String) As %Status
{
    Set tSC = ..GetInventory(authorization, .inventory, .source)
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

ClassMethod GetCategory(category As %String, authorization As %String, Output items As %DynamicArray, Output source As %String) As %Status
{
    Set tSC = ..GetInventory(authorization, .inventory, .source)
    If $$$ISERR(tSC) Quit tSC
    If category = "certificates" Set items = inventory.certificates Quit $$$OK
    If category = "oauth" Set items = inventory.oauth Quit $$$OK
    If category = "credentials" {
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

ClassMethod GetCredentialReferences(Output items As %DynamicArray) As %Status
{
    Set tSC = $$$OK
    Set items = []

    // This query is available only in Interoperability-enabled namespaces.
    // Missing classes or stored procedures mean no credential references here.
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

}
