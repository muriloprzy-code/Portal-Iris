Class MyOwn.Agent.Sanitize
{

/// Removes control and invisible format characters (C0 except tab/LF, DEL, C1,
/// zero-width, bidi overrides, BOM), then neutralizes anything a model could read
/// as an untrusted_data delimiter: any case, inner whitespace, attributes, HTML
/// entities or full-width brackets. Invisible characters go first so they cannot
/// hide a delimiter from the pattern.
ClassMethod Text(value As %String, maximum As %Integer = 1000) As %String
{
    Set clean = $Translate(value, ..InvisibleCharacters(), "")
    Set opening = "(?i)(?:<|&lt;|\x{FF1C})\s*"
    Set name = "untrusted[\s_-]*data\s*(?:>|&gt;|\x{FF1E})?"
    Set matcher = ##class(%Regex.Matcher).%New(opening _ "/\s*" _ name)
    Set matcher.Text = clean
    Set clean = matcher.ReplaceAll("[end marker removed]")
    Set matcher = ##class(%Regex.Matcher).%New(opening _ name)
    Set matcher.Text = clean
    Set clean = matcher.ReplaceAll("[data marker removed]")
    Quit $Extract(clean, 1, maximum)
}

ClassMethod InvisibleCharacters() As %String [ Private ]
{
    Set characters = ""
    For code = 0:1:8, 11:1:31, 127:1:159, 173, 8203:1:8207, 8232:1:8238, 8288:1:8292, 8294:1:8297, 65279 {
        Set characters = characters _ $Char(code)
    }
    Quit characters
}

ClassMethod Identifier(value As %String, maximum As %Integer = 160) As %String
{
    Set clean = ""
    For index = 1:1:$Length(value) {
        Set character = $Extract(value, index)
        If character?1AN Set clean = clean _ character
        If (character = "%") || (character = "_") || (character = "-") || (character = ".") || (character = "/") Set clean = clean _ character
    }
    Quit $Extract(clean, 1, maximum)
}

ClassMethod JSON(value As %String, maximum As %Integer = 1000) As %String
{
    Quit ..Text(value, maximum)
}

}
