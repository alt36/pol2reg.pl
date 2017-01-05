# pol2reg.pl

A perl script to convert a Microsoft .pol file (e.g. from Group Policy) into a registry (.reg) file

Usage
-----

./pol2reg.pl -c HKLM|HKCU input.pol

will read input.pol and dump a corresponding .reg file to standard output. The -c option is mandatory, 
and must be either HKLM or HKCU, correpsonding to the HKEY_LOCAL_MACHINE and HKEY_CURRENT_USER brances
of the registry respectively.

Alternatively, the input can be read from stdin:

cat input.pol | ./pol2reg.pl -c HKLM|HKCU

Limitations
-----------
The script writes entries for the types REG_SZ, REG_EXPAND_SZ, REG_BINARY, REG_DWORD, 
REG_DWORD_BIG_ENDIAN, REG_QWORD . Other types are not yet handled.

Notes on the format
-------------------
Microsoft document the format of the pol file, but some of it is a little unclear/ambiguous/contradictory, 
mainly down to the details of the character encodings used (the file is a mix of 16 and 32 bit little-endian
bytes, which will sometimes be interpreted as encoding a sequence of UTF-16LE characters).

The [Registry Policy File Format][1] says the pol file begins with a signature of 0x67655250, whilst the
[Registry Policy Message Syntax][2] says the signature is %x50 %x52 %x65 %x67. In fact, the first 4 bytes 
of the file are 5250 6765; neither document states the byte ordering.

The signature is then followed by a version number (32 bit little-endian), which currently can only be 1. 
Thus the next 4 bytes will be 0100 0000.

The body then follows after the version number, as a sequence of messages of the form

[key;value;type;size;data]

The [Registry Policy Message Syntax][2] states that the key and the value are UTF-16LE encoded, but doesn't
specify that the "[", ";" and "]" characters are /also/ UTF-16LE encoded (i.e. the hex sequences to look 
for are 005b, 003b, and 005d respectively). Similarly, the key and value are null-terminated; this is a 
UTF-16LE null (0000)

Also, the [Registry Policy Message Syntax][2] gives a specification that is claimed to follow ABNF as 
specified in RFC4234, but strictly the syntax is /not/ RFC4234 compliant: RFC4234 defines rules such 
as SP, VCHAR in their ASCII representations, but the rule defining

 ValueCharacter = SP / VCHAR

needs to be read as the UTF-16LE versions of 0x20 or 0x21-7e respectively.

Links
-----
[Registry Policy File Format][1]

[Registry Policy Message Syntax][2]

[RFC4234][3]

[1]: https://msdn.microsoft.com/en-us/library/aa374407(v=vs.85).aspx
[2]: https://msdn.microsoft.com/en-us/library/cc232696.aspx
[3]: http://www.rfc-editor.org/rfc/rfc4234.txt
