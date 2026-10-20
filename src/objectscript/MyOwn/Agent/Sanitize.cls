Class MyOwn.Agent.Sanitize
{

ClassMethod Text(value As %String, maximum As %Integer = 1000) As %String
{
    Set clean = $Translate(value, $Char(0, 1, 2, 3, 4, 5, 6, 7, 8, 11, 12, 13, 14, 15, 16, 17, 18, 19, 20, 21, 22, 23, 24, 25, 26, 27, 28, 29, 30, 31), "")
    Set clean = $Replace(clean, "</untrusted_data>", "[end marker removed]")
    Set clean = $Replace(clean, "<untrusted_data>", "[data marker removed]")
    Quit $Extract(clean, 1, maximum)
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
