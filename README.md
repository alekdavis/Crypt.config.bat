# Crypt.config.bat

Crypt.config.bat is a command-line tool (Windows batch script) that use the .NET Framework's aspnet_regiis.exe utility to:

- encrypt or decrypt sensitive data in the application configuration (.config) files;
- create or delete RSA key containers;
- grant or revoke access to the RSA key containers for userss or groups;
- export or import RSA keys to or from files.

Crypt.config.bat can encrypt any .config files, including web.config, app.exe.config, or custom-named files.

## Syntax

Crypt.config [OPERATION] [SWITCHES]

### Operation

*encrypt*
> Encrypt a section in a .config file (default).

*decrypt*
> Decrypt a section in a .config file.

*create*
> Create an RSA key container.

*delete*
> Delete an RSA key container.

*export*
> Export RSA keys to a file.

*import*
> Import RSA keys from a file.

*grant*
> Grant access to RSA key container to user/group.

*revoke*
> Remove access to RSA key container from user/group.

*print*
> Show runtime parameters (for debugging purposes).

*license*
> Display license information.

*version*
> Print version information.

*help*
> Print this help information.

### Switches

*/section:value*
> Name of configuration section in .config file(s) to be encrypted or decrypted. Default value: 'secureAppSettings'. Required for operations: encrypt, decrypt.

*/include:value*
> Name(s) or mask(s) used identify the configuration file(s) to be processed. Separate multiple values by colons (:). Name(s) of the file(s) will be appended to the folder (see description of the '/dir' switch) to build the full path(s). If not specified, all files with extension '.exe.config' found in the folder identified by the '/dir' switch will be processed along with the 'web.config' file. Default value: \*.exe.config:web.config. Optional for operations: encrypt, decrypt.

*/exclude:value*
> Name(s) or mask(s) used identify the configuration file(s) to be excluded from processing. The value of this switch uses the same format as the value of the '/include' switch. Optional for operations: encrypt, decrypt.

*/dir:value*
> Path to the folder holding configuration file(s) to be processed. If not specified, the folder hosting this batch script will be used. Optional for operations: encrypt, decrypt, export, import.

*/container:value*
> Name of the RSA key container. Required for operations: create, delete, export, import, grant, revoke.

*/provider:value*
> Name of the RSA cryptographic provider defined in the .config file's 'configProtectedData\providers' section. If not specified, the default provider set in the 'configProtectedData' section's 'defaultpProvider' attribute will be used. Optional for operations: encrypt.

*/key:value*
> Name or path to the export/import file holding the RSA key. If the key is missing, the name will be generated from the name of the RSA key container specified via the '/container' switch (it will have the '.xml' extension). If the key name contains a folder information -- detected by the presense of the backslash (\) character -- it will be left as is; otherwise, the name of the folder identified by the '/dir' switch or the default folder name will be added at the beginning of the key name to generate the absolute path. Optional for operations: export, import.

*/account:value*
> Name of user or group account that will have access to the RSA key container granted/revoked. To specify multiple account names, separate them by colons (:), e.g. /account:"NT AUTHORITY\Network Service:NT AUTHORITY\Local Service". Default value: NT AUTHORITY\NETWORK SERVICE. Required for operations: grant, revoke.

*/bakup:[value]*
> When this switch is set, a backup of the configuration file(s) to be processed will be created before running the encryption/decryption operation. If the switch does not have a value, only configuration file(s) will be processed; otherwise, in addition to the configuration file(s) files identified by the switch will be processed as well (this could be helpful when configuration files reference sections holding sensitive settings from external files). The value of this switch uses the same format as the value of the '/include' switch. If a generated backup file name points to an existing file, the file will be overwritten. Optional for operations: export, import.

*/bak:value*
> File extension (such as '.txt') that will be used for naming backup files. If this switch is set, it will turn the 'backup' switch on as well. Default value: .bak. Optional for operations: export, import.

*/print*
> When this switch is set, the script will print important runtime parameters.

*/quiet*
> When this switch is set, informational messages non-essential for the intended operaytion will not be displayed. Error messages may be displayed regardless.

## Examples

*Crypt.config encrypt /section:myAppSettings /provider:myRsaProv*
> Encrypts section 'myAppSettings' in all .exe.config and web.config files found in the same directory from which the script runs using the provider named 'myRsaProv'.

*Crypt.config encrypt /section:myAppSettings /dir:"C:\Program Files\MyApp" /include:MyApp.exe.config*
> Encrypts section 'myAppSettings' in the MyApp.exe.config file located in the 'C:\Program Files\MyApp' folderusing the default provider (per configuration file).

*Crypt.config decrypt /section:myAppSettings /dir:. /backup:"db.config:secure\*.config"*
> Decrypts section 'myAppSettings' in all .exe.config and web.config files found in the current directory using a default provider. Before performing the operation, it will copy each affected file to a backup file with the .bak extension. It will also back up external files (supposedly referenced by the configuration files): 'db.config' and all files matching the 'secure*.config' mask.

*Crypt.config create /container:myRsaKey*
> Creates an RSA key container named 'myRsaKey'. The key will be exportable, so it can be imported on other machines to allow decryption of the same encrypted settings.*

*Crypt.config delete /container:myRsaKey*
> Deletes the RSA key container named 'myRsaKey'.

*Crypt.config grant /container:myRsaKey /account:.\MyAppPoolUsers*
> Grants access to the RSA key names 'myRsaKey' to a local group called 'myAppPoolUsers'.

*Crypt.config revoke /container:myRsaKey /account:.\MyAppPoolUsers*
> Revokes access to the RSA key names 'myRsaKey' from a local group called 'myAppPoolUsers'.

*Crypt.config export /container:myRsaKey /key:myRsaKey.txt*
> Exports RSA key from container named 'myRsaKey' to the 'myRsaKey.txt' file in the current directory.

*Crypt.config import /container:myRsaKey /key:myRsaKey.txt*
> Imports RSA key from the 'myRsaKey.txt' file in the current directory into a new container named 'myRsaKey'.

## Remarks
Use the following command to display this help info one echo screen at
a time:

>*Crypt.config /? | more*

## Usage
For a detailed example of setting up encryption and using it from a C# application see [this sample](SAMPLE.md).

## Tips
You can hard code required switch values in your copy of the Crypt.config.bat file (see the *INITIALIZE RUNTIME DEFAULTS* section of the batch file).

## Resources

[How to encrypt .config file](https://desflanagan.wordpress.com/2016/07/04/encrytion-in-web-config/ "Encrypting your Web Config") (also [here](https://magenic.com/thinking/encrypting-configuration-sections-in-net "Encrypting Configuration Sections in .NET"))

[How to encrypt config settings on multiple machines](https://mywebanecdotes.com/2016/09/17/encrypting-credentials-in-app-config-for-multiple-machines/ "Encrypting Credentials in App.config for Multiple Machines") (also [here](https://www.c-sharpcorner.com/article/encrypting-app-config-for-multiple-machines/ "Encrypting App.config For Multiple Machines"))

[How to encrypt config sections in external files](https://stackoverflow.com/questions/40650793/is-it-possible-to-encrypt-a-config-file-specified-as-a-configsource-from-web-con "Is it possible to encrypt a config file specified as a configSource from web.config?")

[Working with RsaProtectedConfigurationProvider](http://austrianalex.com/rsaprotectedconfigurationprovider-not-recommended-for-children-under-5.html "RsaProtectedConfigurationProvider: Not recommended for children under 5")

[RsaProtectedConfigurationProvider: Not recommended for children under 5](http://austrianalex.com/rsaprotectedconfigurationprovider-not-recommended-for-children-under-5.html "RsaProtectedConfigurationProvider: Not recommended for children under 5")
