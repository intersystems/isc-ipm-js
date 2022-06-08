/// Utility class to store last known hash for package.json/package-lock.json
Class pkg.isc.ipm.js.latestHash Extends %Persistent
{

Property Filename As %String(MAXLEN = "");

Property FilenameHash As %Binary [ Calculated, SqlComputeCode = {Set {*} = $System.Encryption.SHAHash(256,{Filename})}, SqlComputed ];

Property FileContentHash As %Binary;

Index FilenameHash On FilenameHash [ Unique ];

ClassMethod IsUpToDate(filename As %String) As %Boolean
{
    If '..FilenameExists(filename,.id) {
        Quit 0
    }
    Set currentHash = ..GetCurrentHash(filename)
    Set lastKnownHash = ..FileContentHashGetStored(id)
    Quit (currentHash = lastKnownHash)
}

ClassMethod FilenameExists(filename As %String, Output id As %Integer) As %Boolean
{
    Set filenameHash = $System.Encryption.SHAHash(256,filename)
    Quit ..FilenameHashExists(filenameHash,.id)
}

ClassMethod FilenameOpen(filename As %String, concurrency As %Integer, ByRef sc As %Status) As pkg.isc.ipm.js.latestHash
{
    Set filenameHash = $System.Encryption.SHAHash(256,filename)
    Quit ..FilenameHashOpen(filenameHash,.concurrency,.sc)
}

ClassMethod GetCurrentHash(filename As %String) As %Binary
{
    If '##class(%Library.File).Exists(filename) {
        $$$ThrowStatus($$$ERROR($$$FileDoesNotExist,filename))
    }
    Set fileStream = ##class(%Stream.FileCharacter).%OpenId(filename,,.sc)
    $$$ThrowOnError(sc)
    Set hash = $System.Encryption.SHAHashStream(256,fileStream,.sc)
    $$$ThrowOnError(sc)
    Quit hash
}

ClassMethod StoreHash(filename As %String, hash As %Binary)
{
    If ..FilenameExists(filename,.id) {
        Set inst = ..%OpenId(id,,.sc)
        $$$ThrowOnError(sc)
    } Else {
        Set inst = ..%New()
        Set inst.Filename = filename
    }
    Set inst.FileContentHash = hash
    $$$ThrowOnError(inst.%Save())
}

Storage Default
{
<Data name="latestHashDefaultData">
<Value name="1">
<Value>%%CLASSNAME</Value>
</Value>
<Value name="2">
<Value>Filename</Value>
</Value>
<Value name="3">
<Value>FileContentHash</Value>
</Value>
</Data>
<DataLocation>^pkg.isc.ipm.js.latestHashD</DataLocation>
<DefaultData>latestHashDefaultData</DefaultData>
<IdLocation>^pkg.isc.ipm.js.latestHashD</IdLocation>
<IndexLocation>^pkg.isc.ipm.js.latestHashI</IndexLocation>
<StreamLocation>^pkg.isc.ipm.js.latestHashS</StreamLocation>
<Type>%Storage.Persistent</Type>
}

}
