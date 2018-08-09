# Sample
The following sample illustrates how to use Crypt.config.bat to encrypt and decrypt sensitive application settings in a .config file.

## Step 1: Create a key container

A key container here is a file on the operating system's hard drive that holds an encryption key. This encryption key will be used to encrypt and decrypt sensitive application settings. You do not need to know where the key container file is located or how exactly it is used (the operating system and .NET Framework will take care of it), but you must remember its name. You must also make sure that proper accounts (accounts under which your application will run) have access to this container on the systems where the application will be deployed (we'll talk about it later).

IMPORTANT: Keep in mind that you need administrative privileges on the machine where you execute these commands.

Give your key container a meaningful and unique name (in this example, we will call it *sampleRsaKey*).

To create a key container, run *Crypt.config.bat* with the *create* command:

```console
crypt.config create /container:sampleRsaKey
```

By default, Crypt.config.bat will create an exportable key, so that you can deploy it to multiple machines (on a server farm). If you are not planning to export the key (which is a more secure option), run the create command with the */noexport* switch:

```console
crypt.config create /container:sampleRsaKey /noexport
```

If you need to use the same key across multiple machines, export it to a file via the *export* command (you can use relative or absolute path):

```console
crypt.config export /container:sampleRsaKey /key:sampleRsaKey.xml
```

To import the key container from a file on a different machine, use the *import* command:

```console
crypt.config import /container:sampleRsaKey /key:sampleRsaKey.xml
```

## Step 2: Grant permissions

Access to the encryption key container is protected by [ACL](https://en.wikipedia.org/wiki/Access_control_list "Access Control List"), so you need to grant access to the account(s) under which your application will run. You can use built-in accounts, as well as local or domain users.

To grant access, use the *grant* command. By default, Crypt.config.bat will grant access to the *NT AUTHORITY\NETWORK SERVICE* account:

```console
crypt.config grant /container:sampleRsaKey
```

You can grant access to multiple accounts in a single step (separate accounts by the colon character). The following example grants access to the built-in network service account, default application pool account, and a domain account

```console
crypt.config grant /container:sampleRsaKey /account:"NT AUTHORITY\NETWORK SERVICE:IIS APPPOOL\DefaultAppPool:mydaomain\myaccount"
```

You can grant permissions to the same account repeatedly.

To revoke access to the key container from an account, execute the *revoke* command:

```console
crypt.config revoke /container:sampleRsaKey /account:mydaomain\myaccount
```
 
NOTE: You only need to perform this step on the deployment systems. You generally do not need to set permissions on a development box, unless you intend to run the application.

## Step 3: Define sensitive application settings

This is a developments step and you can perform it at any time during development, as long as you know the name of the key container.

You can define sensitive settings inside of your application's *app.config* (or *web.config*) file or in an external file (via external configuration section). This example will use an external configuration section (referenced from the *app.config* file), because using an external file makes deployment easier. 

Before adding the sensitive application section, create the section handler and define the encrypted data provider settings.

### Configuration section handler

In this section, you specify how your sensitive application section is handled. The only custom value in this element is the name of the section holding sensitive application setting (in our example, we'll call it *secureAppSettings*):

**app.config**
```xml
<?xml version="1.0" encoding="utf-8"?>
<configuration>
  <configSections>
    <section name="secureAppSettings" type="System.Configuration.AppSettingsSection, System.Configuration, Version=2.0.0.0, Culture=neutral, PublicKeyToken=b03f5f7f11d50a3a" />
    ...
  </configSections>
  ...
</configuration>
```

Notice that we are using the `System.Configuration.AppSettingsSection` type because this type will allow us to encrypt a section defined in an external file. If you are not using an external section, you can use the `System.Configuration.NameValueSectionHandler` type:

```xml
<section name="secureAppSettings" type="System.Configuration.NameValueSectionHandler, System, Version=4.0.0.0, Culture=neutral, PublicKeyToken=b77a5c561934e089" />
```

IMPORTANT: Do not use `System.Configuration.AppSettingsSection` type with the external configuration section, because it will not get encrypted.

### Encrypted data provider settings

This section defines how your sensitive data will be encrypted. Although there are other options, most applications should use the [RSA](https://en.wikipedia.org/wiki/RSA_(cryptosystem)) key.

There are two custom attributes that you need to specify here: name of the key container (in our example, *sampleRsaKey*) and name of the provider associated with this key. Again, you can give this provider a name meaningful to you, but we will call it *sampleRsaProvider*. 

When you encrypt the sensitive configuration section, you need to specify the name of the provider, or you can set a provider as a default, in which case, it will be used automatically:

**app.config**
 ```xml
<?xml version="1.0" encoding="utf-8"?>
<configuration>
  ...
  <configProtectedData defaultProvider="sampleRsaProvider">
    <providers>
      <add name="sampleRsaProvider" type="System.Configuration.RsaProtectedConfigurationProvider, System.Configuration, Version=2.0.0.0, Culture=neutral, PublicKeyToken=b03f5f7f11d50a3a" keyContainerName="sampleRsaKey" useMachineContainer="true" />
    </providers>
  </configProtectedData>
  ...
</configuration>
```
Notice that we set *sampleRsaProvider* as a default provider.

### Secure application settings section

You can define secure application settings directly in the .config file or use an external application section. In this example, we will use an external file.

First, create an external file with the sensitive application settings. You can call it whatever you want and place it pretty much anywhere. We will call the file *secureAppSettings.config* and place it in the same location as the application .config file. This is what our external configuration section looks like:

**secureAppSettings.config**
```xml
<secureAppSettings>
  <add key="username" value="usernamevalue" />
  <add key="password" value="passwordvalue" />
</secureAppSettings>
```

Now, in the app.config file, reference the external application section like this:

**app.config**
 ```xml
<?xml version="1.0" encoding="utf-8"?>
<configuration>
  ...
  <secureAppSettings configSource=".\secureAppSettings.config" />
  ...
</configuration>
```

Here are the required sections of the *app.config* file relevant to encryption:

**app.config**
```xml
<?xml version="1.0" encoding="utf-8"?>
<configuration>
  <configSections>
    <section name="secureAppSettings" type="System.Configuration.AppSettingsSection, System.Configuration, Version=2.0.0.0, Culture=neutral, PublicKeyToken=b03f5f7f11d50a3a" />
    ...
  </configSections>
  ...
  <configProtectedData defaultProvider="sampleRsaProvider">
    <providers>
      <add name="sampleRsaProvider" type="System.Configuration.RsaProtectedConfigurationProvider, System.Configuration, Version=2.0.0.0, Culture=neutral, PublicKeyToken=b03f5f7f11d50a3a" keyContainerName="sampleRsaKey" useMachineContainer="true" />
    </providers>
  </configProtectedData>
  ...
  <secureAppSettings configSource=".\secureAppSettings.config" />
  ...
</configuration>
```

## Step 4. Encrypt configuration section

To encrypt an application configuration section, use the *encrypt* command. You will need to specify the name of the provider defined above (here, *sampleRsaProvider*), the name of the configuration section to be encrypted (here, *secureAppSettings*), and the name of the file. If you want to encrypt multiple files, you can specify the file mask(s). By default, Crypt.config.bat will encrypt *web.config* and all *\*.exe.config* files in the script's directory. Here is an example of encrypting the *app.config* file:

```console
crypt.config encrypt /provider:sampleRsaProvider /section:secureAppSection /include:app.config
```

Given that our *app.config* file defines the default provider, we can omit the */provider*
command-line switch:

```console
crypt.config encrypt /provider:sampleRsaProvider /section:secureAppSection /include:app.config
```

There are other command-line switches allowing you to tweak the options that you may find useful. For example, you can back up the configuration files before encrypting them, suppress informational messages and exclude specific files. Run the script with the */help* switch to see additional usage information.

Notice that we do not mention the external configuration file (*secureAppSettings.config*) anywhere. The encryption procedure will know how to find it from the *app.config*'s reference.

You can perform the encryption operation repeatedly without breaking the data.

## Step 5. Dencrypt configuration section

At some point, you may want to decrypt sensitive configuration settings, in which case, use the *decrypt* command:

```console
crypt.config dencrypt /section:secureAppSection /include:app.config
```

You do not need to specify the name of the cryptographic provider during decryption.

You can perform the decryption operation repeatedly without breaking the data.

## Step 6. Add code to retrieve sensitive application settings

The following helper method can be used to retrieve a sensitive application settings from an application written in C#:

```csharp
private static string GetSecureAppSetting
(
    string sectionName,    // Name of the secure application section
    string keyName         // Name of the sensitive application key
)
{
    var section = System.Configuration.ConfigurationManager.GetSection(sectionName) as
       System.Collections.Specialized.NameValueCollection;

    if (section == null)
        throw new Exception(
            String.Format("Cannot read section '{0}' from the configuration file.",
                sectionName));

    string keyValue = null;
    
    try
    {
        keyValue = section[keyName] as string;
    }
    catch (Exception ex)
    {
        throw new Exception(
            String.Format("Cannot get value from the '{0}' property " +
                "of the '{1}' section in the configuration file.",
                keyName, sectionName), ex);        
    }
                    
    return keyValue;
}
```

You can call this method regardless of whether the sensitive settings are encrypted or not:

```csharp
string username = GetSecureAppSetting("secureAppSettings", "username");
string password = GetSecureAppSetting("secureAppSettings", "password");
```
